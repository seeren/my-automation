#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const { Client, GatewayIntentBits, ChannelType } = require("discord.js");
const { joinVoiceChannel, getVoiceConnection } = require("@discordjs/voice");

const TOKEN = process.env.DISCORD_BOT_TOKEN || "";
const GUILD_ID = process.env.DISCORD_MEETING_GUILD_ID || "";
const VOICE_CHANNEL_ID = process.env.DISCORD_MEETING_VOICE_CHANNEL_ID || "";
const HOME_DIR = os.homedir();

const RUNTIME_DIR = path.join(HOME_DIR, "Workspace/automation/vars/runtime");
const COMMAND_FILE = path.join(RUNTIME_DIR, "discord-command.json");
const STATUS_FILE = path.join(RUNTIME_DIR, "discord-status.json");
const LOG_FILE = path.join(HOME_DIR, "Workspace/automation/vars/logs/discord.log");

function logBot(level, code, input, details) {
  const ts = new Date().toISOString();
  fs.appendFileSync(LOG_FILE, `${ts}|${level}|discord_bot|${code}|${input}|${details}\n`);
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

function writeStatus(id, action, status, state, error) {
  const payload = {
    id,
    action,
    status,
    state,
    timestamp: new Date().toISOString(),
  };

  if (error) {
    payload.error = error;
  }

  fs.writeFileSync(STATUS_FILE, JSON.stringify(payload));
}

function requireConfig() {
  if (!TOKEN || !GUILD_ID || !VOICE_CHANNEL_ID) {
    logBot("ERROR", 2, "online", "error|missing_discord_env");
    process.exit(2);
  }
}

async function startMeeting(client) {
  const guild = await client.guilds.fetch(GUILD_ID);
  const channel = await guild.channels.fetch(VOICE_CHANNEL_ID);

  if (!channel || channel.type !== ChannelType.GuildVoice) {
    throw new Error("Configured voice channel is missing or not a voice channel");
  }

  joinVoiceChannel({
    channelId: channel.id,
    guildId: guild.id,
    adapterCreator: guild.voiceAdapterCreator,
    selfDeaf: false,
    selfMute: true,
  });
}

function stopMeeting() {
  const connection = getVoiceConnection(GUILD_ID);
  if (connection) {
    connection.destroy();
  }
}

async function main() {
  requireConfig();

  const client = new Client({
    intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildVoiceStates],
  });

  let busy = false;

  client.once("clientReady", () => {
    logBot("INFO", 0, "online", "success");
  });

  setInterval(async () => {
    if (busy) {
      return;
    }
    const cmd = readCommand();
    if (!cmd || !cmd.id || !cmd.action) {
      return;
    }

    busy = true;
    try {
      if (cmd.action === "start") {
        await startMeeting(client);
        writeStatus(cmd.id, cmd.action, "success", "meeting_started");
        logBot("INFO", 0, "command", `cmd_id=${cmd.id}|state=meeting_started`);
      } else if (cmd.action === "stop") {
        stopMeeting();
        writeStatus(cmd.id, cmd.action, "success", "meeting_stopped");
        logBot("INFO", 0, "command", `cmd_id=${cmd.id}|state=meeting_stopped`);
      } else {
        writeStatus(cmd.id, cmd.action, "error", "error", "unknown_action");
        logBot("ERROR", 50, "command", `cmd_id=${cmd.id}|state=error|unknown_action`);
      }
    } catch (err) {
      const message = err && err.message ? err.message : "unknown_bot_error";
      writeStatus(cmd.id, cmd.action, "error", "error", message);
      logBot("ERROR", 51, "command", `cmd_id=${cmd.id}|state=error|${message}`);
    } finally {
      clearCommand();
      busy = false;
    }
  }, 1000);

  await client.login(TOKEN);
}

main().catch((err) => {
  const message = err && err.message ? err.message : "fatal_startup_error";
  logBot("ERROR", 1, "online", `error|${message}`);
  process.exit(1);
});
