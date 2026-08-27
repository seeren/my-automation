#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const sodium = require("libsodium-wrappers");
const OpusScript = require("opusscript");
const { Client, GatewayIntentBits } = require("discord.js");
const {
  joinVoiceChannel,
  getVoiceConnection,
  EndBehaviorType,
  VoiceConnectionStatus,
  entersState,
} = require("@discordjs/voice");

const TOKEN = process.env.BOT_DISCORD_TOKEN;
const GUILD_ID = process.env.BOT_DISCORD_GUILD_ID;
const VOICE_CHANNEL_ID = process.env.BOT_DISCORD_VOICE_CHANNEL_ID;
const HOME_DIR = os.homedir();

const COMMAND_ID = process.argv[2];
if (!COMMAND_ID) process.exit(2);

const VARS_DIR = path.join(HOME_DIR, "Workspace/shortcuts/vars");
const AUDIO_DIR = path.join(VARS_DIR, "audios");
const COMMAND_DIR = path.join(VARS_DIR, "commands");
const STATUS_DIR = path.join(VARS_DIR, "status");
const SESSION_DIR = path.join(VARS_DIR, "sessions");
const AUDIO_SAMPLE_RATE = 48000;
const AUDIO_CHANNELS = 2;
const AUDIO_BITS_PER_SAMPLE = 16;

const meetingState = {
  connection: null,
  speakingListener: null,
  sessionId: null,
  isRecording: false,
  activeAudioStreams: new Map(),
  speakerAudioFiles: new Map(),
};

function readCommand() {
  const commandPath = path.join(COMMAND_DIR, COMMAND_ID);
  if (!fs.existsSync(commandPath)) return null;

  const action = fs.readFileSync(commandPath, "utf8").trim();
  if (!action) return null;

  return { id: COMMAND_ID, action };
}

function clearCommand() {
  const commandPath = path.join(COMMAND_DIR, COMMAND_ID);
  if (fs.existsSync(commandPath)) fs.unlinkSync(commandPath);
}

function writeStatus(status) {
  fs.writeFileSync(path.join(STATUS_DIR, COMMAND_ID), status);
}

function writeSession(sessionId) {
  fs.writeFileSync(path.join(SESSION_DIR, COMMAND_ID), sessionId);
}

function clearStatus() {
  const statusPath = path.join(STATUS_DIR, COMMAND_ID);
  if (fs.existsSync(statusPath)) fs.unlinkSync(statusPath);
}

function sanitizeForFilename(input) {
  return String(input || "unknown").replace(/[^a-zA-Z0-9._-]/g, "_");
}

function encodeBase64Url(input) {
  return Buffer.from(String(input || "unknown"), "utf8")
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function createSessionId() {
  return new Date().toISOString().replace(/[:.]/g, "-");
}

function closeActiveAudioStreams() {
  for (const { opusStream, decoder } of meetingState.activeAudioStreams.values()) {
    try {
      opusStream.destroy();
    } catch {
      // Ignore teardown failures during stop.
    }

    try {
      if (typeof decoder?.delete === "function") decoder.delete();
    } catch {
      // Ignore teardown failures during stop.
    }
  }

  meetingState.activeAudioStreams.clear();
}

function stopCurrentConnection() {
  stopAudioCapture();
  if (!meetingState.connection) return;

  meetingState.connection.destroy();
  meetingState.connection = null;
}

function stopAudioCapture() {
  if (meetingState.connection && meetingState.speakingListener) {
    meetingState.connection.receiver.speaking.off("start", meetingState.speakingListener);
    meetingState.speakingListener = null;
  }

  closeActiveAudioStreams();
  finalizeSpeakerAudioFiles();
  meetingState.sessionId = null;
  meetingState.isRecording = false;
}

function getSpeakerAudioPath(sessionId, userId, speakerName) {
  const safeSession = sanitizeForFilename(sessionId);
  const safeUser = sanitizeForFilename(userId);
  const safeName = encodeBase64Url(speakerName);
  return path.join(AUDIO_DIR, `${safeSession}__speaker-${safeUser}__name-${safeName}.wav`);
}

function buildWavHeader(dataSize) {
  const bytesPerSample = AUDIO_BITS_PER_SAMPLE / 8;
  const byteRate = AUDIO_SAMPLE_RATE * AUDIO_CHANNELS * bytesPerSample;
  const blockAlign = AUDIO_CHANNELS * bytesPerSample;
  const header = Buffer.alloc(44);

  header.write("RIFF", 0);
  header.writeUInt32LE(36 + dataSize, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(AUDIO_CHANNELS, 22);
  header.writeUInt32LE(AUDIO_SAMPLE_RATE, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(AUDIO_BITS_PER_SAMPLE, 34);
  header.write("data", 36);
  header.writeUInt32LE(dataSize, 40);

  return header;
}

function getOrCreateSpeakerAudioFile(sessionId, userId, speakerName) {
  if (meetingState.speakerAudioFiles.has(userId)) {
    return meetingState.speakerAudioFiles.get(userId);
  }

  const filePath = getSpeakerAudioPath(sessionId, userId, speakerName);
  const fd = fs.openSync(filePath, "w");
  fs.writeSync(fd, buildWavHeader(0), 0, 44, 0);

  const speakerAudioFile = {
    userId,
    filePath,
    fd,
    pcmBytes: 0,
    closed: false,
  };

  meetingState.speakerAudioFiles.set(userId, speakerAudioFile);
  return speakerAudioFile;
}

function finalizeSpeakerAudioFile(speakerAudioFile) {
  if (speakerAudioFile.closed) return;

  fs.writeSync(speakerAudioFile.fd, buildWavHeader(speakerAudioFile.pcmBytes), 0, 44, 0);
  fs.closeSync(speakerAudioFile.fd);
  speakerAudioFile.closed = true;
}

function finalizeSpeakerAudioFiles() {
  for (const speakerAudioFile of meetingState.speakerAudioFiles.values()) {
    finalizeSpeakerAudioFile(speakerAudioFile);
  }

  meetingState.speakerAudioFiles.clear();
}

function resolveSpeakerName(client, userId) {
  const guild = client.guilds.cache.get(GUILD_ID);
  const guildMember = guild?.members.cache.get(userId);

  if (guildMember) {
    return guildMember.displayName || guildMember.user?.username || userId;
  }

  return client.users.cache.get(userId)?.username || userId;
}

function startSpeakerCapture(receiver, client, userId) {
  if (!meetingState.sessionId) return;
  if (client.user && userId === client.user.id) return;
  if (meetingState.activeAudioStreams.has(userId)) return;

  const speakerName = resolveSpeakerName(client, userId);
  const speakerAudioFile = getOrCreateSpeakerAudioFile(meetingState.sessionId, userId, speakerName);
  const opusStream = receiver.subscribe(userId, {
    end: {
      behavior: EndBehaviorType.AfterSilence,
      duration: 1500,
    },
  });
  const decoder = new OpusScript(AUDIO_SAMPLE_RATE, AUDIO_CHANNELS, OpusScript.Application.AUDIO);

  meetingState.activeAudioStreams.set(userId, { opusStream, decoder });

  opusStream.on("data", (chunk) => {
    try {
      const pcmChunk = decoder.decode(chunk);
      const pcmBuffer = Buffer.isBuffer(pcmChunk) ? pcmChunk : Buffer.from(pcmChunk);

      fs.writeSync(
        speakerAudioFile.fd,
        pcmBuffer,
        0,
        pcmBuffer.length,
        44 + speakerAudioFile.pcmBytes,
      );
      speakerAudioFile.pcmBytes += pcmBuffer.length;
    } catch {
      // Ignore decode failures for this chunk.
    }
  });

  opusStream.on("error", () => undefined);

  let released = false;
  const releaseStream = () => {
    if (released) return;

    released = true;
    meetingState.activeAudioStreams.delete(userId);
    if (typeof decoder.delete === "function") decoder.delete();
  };

  opusStream.once("end", releaseStream);
  opusStream.once("close", releaseStream);
}

function attachAudioCapture(connection, client) {
  const receiver = connection.receiver;
  const speakingListener = (userId) => startSpeakerCapture(receiver, client, userId);

  meetingState.speakingListener = speakingListener;
  receiver.speaking.on("start", speakingListener);
}

async function startMeeting(client) {
  const existingConnection = meetingState.connection || getVoiceConnection(GUILD_ID);
  if (existingConnection && existingConnection.state.status !== VoiceConnectionStatus.Destroyed) {
    throw new Error("meeting_already_active");
  }

  const guild = await client.guilds.fetch(GUILD_ID);
  const channel = await guild.channels.fetch(VOICE_CHANNEL_ID);

  meetingState.connection = joinVoiceChannel({
    channelId: channel.id,
    guildId: guild.id,
    adapterCreator: guild.voiceAdapterCreator,
    selfDeaf: false,
    selfMute: false,
  });

  return "meeting_started";
}

async function startRecording(client) {
  if (meetingState.isRecording) throw new Error("recording_already_active");

  if (meetingState.connection.state.status !== VoiceConnectionStatus.Ready) {
    await entersState(meetingState.connection, VoiceConnectionStatus.Ready, 5_000);
  }

  meetingState.sessionId = createSessionId();
  meetingState.isRecording = true;
  attachAudioCapture(meetingState.connection, client);

  return {
    state: "recording_started",
    sessionId: meetingState.sessionId,
  };
}

function stopMeeting() {
  const sessionId = meetingState.sessionId;
  const recordingWasActive = meetingState.isRecording;

  stopCurrentConnection();

  const staleConnection = getVoiceConnection(GUILD_ID);
  if (staleConnection) staleConnection.destroy();

  return { sessionId, recordingWasActive };
}

async function handleCommand(client, cmd) {
  try {
    if (cmd.action === "record") {
      await startMeeting(client);
      const recordingResult = await startRecording(client);
      writeSession(recordingResult.sessionId);
      writeStatus("success");
      return;
    }

    if (cmd.action === "stop") {
      stopMeeting();
      writeStatus("success");
      return;
    }

    writeStatus("error");
  } catch {
    writeStatus("error");
  }
}

async function main() {
  clearStatus();
  await sodium.ready;

  const client = new Client({
    intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildVoiceStates],
  });

  let busy = false;

  setInterval(async () => {
    if (busy) return;

    const cmd = readCommand();
    if (!cmd?.id || !cmd.action) return;

    busy = true;
    try {
      await handleCommand(client, cmd);
    } finally {
      clearCommand();
      busy = false;
    }
  }, 1000);

  await client.login(TOKEN);
}

main().catch(() => process.exit(1));
