#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const sodium = require("libsodium-wrappers");
const OpusScript = require("opusscript");
const { Client, GatewayIntentBits, ChannelType } = require("discord.js");
const {
  joinVoiceChannel,
  getVoiceConnection,
  EndBehaviorType,
  VoiceConnectionStatus,
  entersState,
} = require("@discordjs/voice");

const TOKEN = process.env.BOT_DISCORD_TOKEN || "";
const GUILD_ID = process.env.BOT_DISCORD_GUILD_ID || "";
const VOICE_CHANNEL_ID = process.env.BOT_DISCORD_VOICE_CHANNEL_ID || "";
const HOME_DIR = os.homedir();

const RUNTIME_DIR = path.join(HOME_DIR, "Workspace/shortcuts/vars/runtime");
const AUDIO_DIR = path.join(RUNTIME_DIR, "audios");
const COMMAND_FILE = path.join(RUNTIME_DIR, "discord-command.json");
const STATUS_FILE = path.join(RUNTIME_DIR, "discord-status.json");
const LOG_FILE = path.join(HOME_DIR, "Workspace/shortcuts/vars/logs/discord.log");
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

function logBotError(code, input, details) {
  const ts = new Date().toISOString();
  fs.appendFileSync(LOG_FILE, `${ts}|ERROR|discord_bot|${code}|${input}|${details}\n`);
}

function readCommand() {
  if (!fs.existsSync(COMMAND_FILE)) {
    return null;
  }
  try {
    return JSON.parse(fs.readFileSync(COMMAND_FILE, "utf8"));
  } catch (_err) {
    return null;
  }
}

function clearCommand() {
  if (fs.existsSync(COMMAND_FILE)) {
    fs.unlinkSync(COMMAND_FILE);
  }
}

function writeStatus(id, action, status, state, error, metadata) {
  const payload = {
    id,
    action,
    status,
    state,
    timestamp: new Date().toISOString(),
  };

  if (metadata && typeof metadata === "object") {
    Object.assign(payload, metadata);
  }

  if (error) {
    payload.error = error;
  }

  fs.writeFileSync(STATUS_FILE, JSON.stringify(payload));
}

function requireConfig() {
  if (!TOKEN || !GUILD_ID || !VOICE_CHANNEL_ID) {
    logBotError(2, "online", "error|missing_discord_env");
    process.exit(2);
  }
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
  for (const speakerStreams of meetingState.activeAudioStreams.values()) {
    const { opusStream, decoder } = speakerStreams;
    try {
      opusStream.destroy();
    } catch (_err) {
      // Ignore teardown failures during stop.
    }
    try {
      if (decoder && typeof decoder.delete === "function") {
        decoder.delete();
      }
    } catch (_err) {
      // Ignore teardown failures during stop.
    }
  }
  meetingState.activeAudioStreams.clear();
}

function stopCurrentConnection() {
  stopAudioCapture();
  if (!meetingState.connection) {
    return;
  }
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
  if (speakerAudioFile.closed) {
    return;
  }
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

function startSpeakerCapture(receiver, client, userId) {
  if (!meetingState.sessionId) {
    return;
  }

  if (client.user && userId === client.user.id) {
    return;
  }

  if (meetingState.activeAudioStreams.has(userId)) {
    return;
  }

  let speakerName = userId;
  const guild = client.guilds.cache.get(GUILD_ID);
  const guildMember = guild ? guild.members.cache.get(userId) : null;
  if (guildMember) {
    speakerName = guildMember.displayName || (guildMember.user && guildMember.user.username) || userId;
  } else {
    const cachedUser = client.users.cache.get(userId);
    if (cachedUser && cachedUser.username) {
      speakerName = cachedUser.username;
    }
  }

  const speakerAudioFile = getOrCreateSpeakerAudioFile(meetingState.sessionId, userId, speakerName);
  const opusStream = receiver.subscribe(userId, {
    end: {
      behavior: EndBehaviorType.AfterSilence,
      duration: 1500,
    },
  });
  const decoder = new OpusScript(AUDIO_SAMPLE_RATE, AUDIO_CHANNELS, OpusScript.Application.AUDIO);
  meetingState.activeAudioStreams.set(userId, {
    opusStream,
    decoder,
  });

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
    } catch (err) {
      const message = err && err.message ? err.message : "opus_decode_error";
      logBotError(72, "audio_capture", `session=${meetingState.sessionId}|speaker=${userId}|${message}`);
    }
  });

  opusStream.on("error", (err) => {
    const message = err && err.message ? err.message : "speaker_stream_error";
    logBotError(70, "audio_capture", `session=${meetingState.sessionId}|speaker=${userId}|${message}`);
  });

  let released = false;
  const releaseStream = () => {
    if (released) {
      return;
    }
    released = true;
    meetingState.activeAudioStreams.delete(userId);
    if (typeof decoder.delete === "function") {
      decoder.delete();
    }
  };
  opusStream.once("end", releaseStream);
  opusStream.once("close", releaseStream);
}

function attachAudioCapture(connection, client) {
  const receiver = connection.receiver;

  const speakingListener = (userId) => {
    startSpeakerCapture(receiver, client, userId);
  };

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

  if (!channel || channel.type !== ChannelType.GuildVoice) {
    throw new Error("Configured voice channel is missing or not a voice channel");
  }

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
  if (meetingState.isRecording) {
    throw new Error("recording_already_active");
  }

  if (meetingState.connection.state.status !== VoiceConnectionStatus.Ready) {
    await entersState(meetingState.connection, VoiceConnectionStatus.Ready, 20_000);
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
  if (staleConnection) {
    staleConnection.destroy();
  }

  return {
    sessionId,
    recordingWasActive,
  };
}

async function main() {
  requireConfig();

  await sodium.ready;

  const client = new Client({
    intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildVoiceStates],
  });

  let busy = false;

  setInterval(async () => {
    if (busy) {
      return;
    }
    const cmd = readCommand();
    if (!cmd || !cmd.id || !cmd.action) {
      return;
    }

    busy = true;
    let commandPhase;
    try {
      if (cmd.action === "record") {
        commandPhase = "meeting";
        const meetingResult = await startMeeting(client);
        commandPhase = "recording";
        const recordingResult = await startRecording(client);
        writeStatus(cmd.id, cmd.action, "success", recordingResult.state, undefined, {
          meeting_state: meetingResult,
          session_id: recordingResult.sessionId,
        });
      } else if (cmd.action === "stop") {
        const stopContext = stopMeeting();
        writeStatus(cmd.id, cmd.action, "success", "meeting_stopped", undefined, {
          session_id: stopContext.sessionId,
          recording_was_active: stopContext.recordingWasActive,
        });
      } else {
        writeStatus(cmd.id, cmd.action, "error", "error", "unknown_action");
        logBotError(50, "command", `cmd_id=${cmd.id}|state=error|unknown_action`);
      }
    } catch (err) {
      const message = err && err.message ? err.message : "unknown_bot_error";
      const state = commandPhase ? `${commandPhase}_error` : "error";
      writeStatus(cmd.id, cmd.action, "error", state, message);
      logBotError(51, "command", `cmd_id=${cmd.id}|state=${state}|${message}`);
    } finally {
      clearCommand();
      busy = false;
    }
  }, 1000);

  await client.login(TOKEN);
}

main().catch((err) => {
  const message = err && err.message ? err.message : "fatal_startup_error";
  logBotError(1, "online", `error|${message}`);
  process.exit(1);
});
