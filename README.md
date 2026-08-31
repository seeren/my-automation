# Shortcuts

A personal automation layer designed to reduce cognitive load and execution friction for daily workflows.

---

## Stack (layers)

- **Interface**: iPhone Shortcuts (trigger + UI)
- **Transport**: SSH
- **Execution**: macOS + shell scripts
- **Targets**: external APIs (ClickUp, Git, Discord, etc.)

---

## Architecture

iPhone (Shortcuts)  
↓  
SSH (secure trigger)  
↓  
Mac (execution unit)  
↓  
Shell scripts  
↓  
External APIs (ClickUp, Git, etc.)

---

## Philosophy

The goal is simple:

> Reduce effort and cognitive load for repetitive workflows by turning them into one-tap actions.

Instead of:
- opening tools
- navigating UIs
- repeating manual steps

I trigger workflows directly from my iPhone.

---

## Why this exists

I initially thought about building a Stream Deck setup.

Instead, I realized:

- iOS Shortcuts already provide a distributed control surface
- iCloud sync makes shortcuts available across devices
- SSH enables full remote execution on a central machine

So I combined:

- Shortcuts = UI layer
- Mac = orchestration layer
- Shell scripts = logic layer

---

## Prerequisites

### macOS (all workflows)

- iPhone Shortcuts + SSH to the Mac execution unit
- Host secrets for tokens/keys (see Configuration)
- Non-secret app config in `config.sh`

### Shared CLI runtime

The shared CLI expects the existing Homebrew installations of Bash 5 and
`argc` to be available on `PATH`. Verify the runtime with:

```bash
bash --version
argc --argc-version
```

The CLI uses `#!/usr/bin/env bash`, so non-interactive SSH must put Homebrew
before the system Bash 3.2. Use the existing login-shell convention with an
explicit executable search path:

```bash
zsh -lc './bin/shortcuts --help'
```

### Discord meeting

Install whisper.cpp CLI on the Mac:

```bash
brew install whisper-cpp
```

Download IA model locally

```bash
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin?download=true" -o ~/Workspace/shortcuts/vars/ggml-large-v3.bin
```

#### Meeting summary (Cursor API)

Required for the summary step when a meeting was started with **record**.

Install the Cursor CLI on the Mac:

```bash
brew install jq
```

#### Node.js

- **Node.js LTS** on the Mac (currently **v24.x** Active LTS)

Install or upgrade with Homebrew:

#### npm dependencies (repo root)

Install once after cloning or pulling dependency changes:

```bash
cd ~/Workspace/shortcuts
npm install
```

---

## iPhone <-> Mac setup (Shortcuts + SSH)

- Enable iCloud sync for Shortcuts (iPhone settings).
- On Mac, enable `System Settings -> General -> Sharing -> Remote Sessions`.

---

## Configuration

Entry points `source config.sh`.

**Host secrets** (required in the environment — see [dotfiles](https://github.com/cyrilichti/dotfiles)):

- `API_CLICKUP_TOKEN`
- `BOT_DISCORD_TOKEN`
- `API_CURSOR_TOKEN`

**Constants** (set in `config.sh`):

- `API_CLICKUP_BASE_URL`
- `CLICKUP_INBOX_ID`
- `BOT_DISCORD_GUILD_ID`
- `BOT_DISCORD_VOICE_CHANNEL_ID`

Non-interactive SSH: `zsh -lc '…'` or `launchctl setenv` so secrets are inherited.

---

## Discord bot setup

1. [Create a Discord server](https://support.discord.com/hc/en-us/articles/204849977-How-do-I-create-a-server), then create or select the voice channel to record.
2. Open the [Discord Developer Portal](https://discord.com/developers/applications), create an application, and open its **Bot** page. Generate or reset the bot token and store it only in the host secrets as `BOT_DISCORD_TOKEN`; never add it to `config.sh` or commit it.
3. On the application's **Installation** page, enable **Guild Install**. Add the `bot` scope with the **View Channels** and **Connect** permissions (`Speak` is optional), save, then open the generated install link. Choose **Add to server**, select the server, and authorize the bot. The bot must appear in the server member list; installing the application only for the user is not sufficient. See Discord's [bot setup and installation guide](https://docs.discord.com/developers/quick-start/getting-started).
4. In Discord, enable **User Settings -> Advanced -> Developer Mode**. Right-click the server icon and select **Copy Server ID**, then right-click the voice channel and select **Copy Channel ID**. Discord documents both operations in [Where can I find my User/Server/Message ID?](https://support.discord.com/hc/en-us/articles/206346498-Where-can-I-find-my-User-Server-Message-ID).
5. Set the two non-secret IDs in `config.sh`:

```bash
export BOT_DISCORD_GUILD_ID="<server-id>"
export BOT_DISCORD_VOICE_CHANNEL_ID="<voice-channel-id>"
```

Run the recording action from the repository runtime:

```bash
~/Workspace/shortcuts/bin/shortcuts meeting_record
```

---

## Design principles

- Minimal cognitive friction
- One SSH trigger = one intent
- No UI navigation required for frequent tasks
- iPhone is trigger + UI only; Mac executes
- Secrets stay on the Mac (host env), never in Shortcuts / iCloud

---

## Security

- No secrets on the iPhone or in the repo
- Execution on a trusted local Mac
- SSH as the secure transport layer

---

## Future extensions (checklist)

Prioritized by ROI: frequency, time saved, implementation effort, and risk.

- [x] Create a quick ClickUp inbox task
- [x] Record a Discord meeting (join + record as sole entry)
- [x] Stop a Discord meeting session
- [x] Transcribe a recorded meeting
- [x] Summarize a meeting transcript
- [ ] Notify teammates on Rocket.Chat when meeting starts
- [ ] Prepare a meeting workspace (Discord, ClickUp, browser, window layout)
- [ ] Convert Os ticket task into clickup task
- [ ] Create multiple inbox tasks from a multi-line list
- [ ] Schedule a Discord meeting
- [ ] Send a reusable Rocket.Chat notification
- [ ] Add generic macOS workspace actions (split windows, fullscreen, open context)

---

## Vision

This is a personal control layer for my digital workflows.

Not a product.  
Not a framework.  
Just a system to execute daily work faster, with less friction.
