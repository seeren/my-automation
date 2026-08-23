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
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin?download=true" -o ~/Workspace/shortcuts/vars/runtime/ggml-large-v3.bin
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

- Enable Developer Mode in Discord (`User Settings -> Advanced`).
- In [Discord Developer Portal](https://discord.com/developers/applications), create an application and a bot.
- Copy bot token into host secrets as `BOT_DISCORD_TOKEN`.
- Invite the bot with scope `bot` and permissions `View Channels`, `Connect` (optional `Speak`).
- Set server and voice channel IDs in `config.sh`:
  - `BOT_DISCORD_GUILD_ID`
  - `BOT_DISCORD_VOICE_CHANNEL_ID`

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
