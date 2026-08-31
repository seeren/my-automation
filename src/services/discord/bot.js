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

const COMMAND_ID = process.argv[2];
const COMMAND_POLL_MS = 1000;
const SILENCE_END_MS = 1500;
const VOICE_READY_TIMEOUT_MS = 5_000;

const VARS_DIR = path.join(os.homedir(), "Workspace/shortcuts/vars");
const PATHS = {
  audios: path.join(VARS_DIR, "audios"),
  commands: path.join(VARS_DIR, "commands"),
  status: path.join(VARS_DIR, "status"),
  sessions: path.join(VARS_DIR, "sessions"),
};

const AUDIO = {
  sampleRate: 48000,
  channels: 2,
  bitsPerSample: 16,
};

const meetingState = {
  connection: null,
  speakingListener: null,
  sessionId: null,
  activeAudioStreams: new Map(),
  speakerAudioFiles: new Map(),
};

function readCommand() {
  const commandPath = path.join(PATHS.commands, COMMAND_ID);
  if (!fs.existsSync(commandPath)) return null;

  const action = fs.readFileSync(commandPath, "utf8").trim();
  return action || null;
}

function clearCommand() {
  fs.rmSync(path.join(PATHS.commands, COMMAND_ID), { force: true });
}

function writeStatus(status) {
  fs.writeFileSync(path.join(PATHS.status, COMMAND_ID), status);
}

function writeSession(sessionId) {
  fs.writeFileSync(path.join(PATHS.sessions, COMMAND_ID), sessionId);
}

function createSessionId() {
  return new Date().toISOString().replace(/[:.]/g, "-");
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

function buildWavHeader(dataSize) {
  const bytesPerSample = AUDIO.bitsPerSample / 8;
  const byteRate = AUDIO.sampleRate * AUDIO.channels * bytesPerSample;
  const blockAlign = AUDIO.channels * bytesPerSample;
  const header = Buffer.alloc(44);

  header.write("RIFF", 0);
  header.writeUInt32LE(36 + dataSize, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(AUDIO.channels, 22);
  header.writeUInt32LE(AUDIO.sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(AUDIO.bitsPerSample, 34);
  header.write("data", 36);
  header.writeUInt32LE(dataSize, 40);

  return header;
}

function getSpeakerAudioPath(sessionId, userId, speakerName) {
  const safeSession = sanitizeForFilename(sessionId);
  const safeUser = sanitizeForFilename(userId);
  const safeName = encodeBase64Url(speakerName);
  return path.join(PATHS.audios, `${safeSession}__speaker-${safeUser}__name-${safeName}.wav`);
}

function getOrCreateSpeakerAudioFile(sessionId, userId, speakerName) {
  const existing = meetingState.speakerAudioFiles.get(userId);
  if (existing) return existing;

  const fd = fs.openSync(getSpeakerAudioPath(sessionId, userId, speakerName), "w");
  fs.writeSync(fd, buildWavHeader(0), 0, 44, 0);

  const speakerAudioFile = { fd, pcmBytes: 0, closed: false };
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

function closeActiveAudioStreams() {
  for (const { opusStream, decoder } of meetingState.activeAudioStreams.values()) {
    try {
      opusStream.destroy();
    } catch {
      // Ignore teardown failures during stop.
    }

    try {
      decoder?.delete?.();
    } catch {
      // Ignore teardown failures during stop.
    }
  }

  meetingState.activeAudioStreams.clear();
}

function stopAudioCapture() {
  if (meetingState.connection && meetingState.speakingListener) {
    meetingState.connection.receiver.speaking.off("start", meetingState.speakingListener);
    meetingState.speakingListener = null;
  }

  closeActiveAudioStreams();
  finalizeSpeakerAudioFiles();
  meetingState.sessionId = null;
}

function stopCurrentConnection() {
  stopAudioCapture();

  if (meetingState.connection) {
    meetingState.connection.destroy();
    meetingState.connection = null;
  }
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
  if (meetingState.sessionId && !meetingState.activeAudioStreams.has(userId)) {
    const speakerAudioFile = getOrCreateSpeakerAudioFile(
      meetingState.sessionId,
      userId,
      resolveSpeakerName(client, userId),
    );
    const opusStream = receiver.subscribe(userId, {
      end: { behavior: EndBehaviorType.AfterSilence, duration: SILENCE_END_MS },
    });
    const decoder = new OpusScript(AUDIO.sampleRate, AUDIO.channels, OpusScript.Application.AUDIO);

    meetingState.activeAudioStreams.set(userId, { opusStream, decoder });

    const releaseStream = () => {
      if (!meetingState.activeAudioStreams.delete(userId)) return;
      decoder.delete?.();
    };

    opusStream.on("data", (chunk) => {
      try {
        const pcmBuffer = Buffer.from(decoder.decode(chunk));
        fs.writeSync(speakerAudioFile.fd, pcmBuffer, 0, pcmBuffer.length, 44 + speakerAudioFile.pcmBytes);
        speakerAudioFile.pcmBytes += pcmBuffer.length;
      } catch {
        // Ignore decode failures for this chunk.
      }
    });

    opusStream.on("error", releaseStream);
    opusStream.once("end", releaseStream);
    opusStream.once("close", releaseStream);
  }
}

function attachAudioCapture(connection, client) {
  const receiver = connection.receiver;
  const speakingListener = (userId) => startSpeakerCapture(receiver, client, userId);

  meetingState.speakingListener = speakingListener;
  receiver.speaking.on("start", speakingListener);
}

async function startMeeting(client) {
  const guild = await client.guilds.fetch(GUILD_ID);
  const channel = await guild.channels.fetch(VOICE_CHANNEL_ID);

  meetingState.connection = joinVoiceChannel({
    channelId: channel.id,
    guildId: guild.id,
    adapterCreator: guild.voiceAdapterCreator,
    selfDeaf: false,
    selfMute: false,
  });
}

async function startRecording(client) {
  if (meetingState.connection.state.status !== VoiceConnectionStatus.Ready) {
    await entersState(meetingState.connection, VoiceConnectionStatus.Ready, VOICE_READY_TIMEOUT_MS);
  }

  meetingState.sessionId = createSessionId();
  attachAudioCapture(meetingState.connection, client);
}

function stopMeeting() {
  stopCurrentConnection();

  const staleConnection = getVoiceConnection(GUILD_ID);
  if (staleConnection) staleConnection.destroy();
}

const commandHandlers = {
  record: async (client) => {
    await startMeeting(client);
    await startRecording(client);
    writeSession(meetingState.sessionId);
    writeStatus("success");
  },
  stop: async () => {
    stopMeeting();
    writeStatus("success");
  },
};

async function handleCommand(client, action) {
  try {
    if (commandHandlers[action]) {
      await commandHandlers[action](client);
    } else {
      writeStatus("error");
    }
  } catch {
    writeStatus("error");
  }
}

async function main() {
  await sodium.ready;

  const client = new Client({
    intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildVoiceStates],
  });

  let busy = false;

  setInterval(async () => {
    if (!busy) {
      const action = readCommand();
      if (action) {
        busy = true;
        try {
          await handleCommand(client, action);
        } finally {
          clearCommand();
          busy = false;
        }
      }
    }
  }, COMMAND_POLL_MS);

  await client.login(TOKEN);
}

main().catch(() => process.exit(1));
