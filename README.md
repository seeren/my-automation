# Personal Automation

A personal automation layer designed to reduce cognitive load and execution friction for daily workflows.

---

## Stack (layers)

- **Interface**: iPhone Shortcuts
- **Transport**: SSH
- **Execution unit**: macOS
- **Logic**: shell scripts
- **Targets**: external APIs (ClickUp, Git, etc.)

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

Before using Discord meeting scripts:

- Node.js installed on the Mac execution unit
- Project dependencies installed (`npm install` at repo root)
- `vars/runtime/` directory present in the repo (tracked with `.gitkeep`)
- `vars/logs/` and `vars/pids/` directories present in the repo (tracked with `.gitkeep`)

---

## Configuration

Copy and configure environment variables:

```bash
cp config/env.example.sh config/env.sh
source config/env.sh
```

Required variables:

- `CLICKUP_TOKEN`
- `CLICKUP_BASE_URL`
- `CLICKUP_INBOX_ID`
- `CLICKUP_INBOX_PATH`
- `DISCORD_BOT_TOKEN`
- `DISCORD_MEETING_GUILD_ID`
- `DISCORD_MEETING_VOICE_CHANNEL_ID`

---

## Discord meeting workflows

Current Discord entry points:

- `discord/meeting_start.sh`:
  - Starts the Discord bot if needed
  - Sends a `start` command to the bot via `vars/runtime/discord-command.json`
- `discord/meeting_stop.sh`:
  - Sends a `stop` command to the bot
  - Stops all matching bot processes and clears the PID file

Runtime state is kept locally under `vars/`:

- logs: `vars/logs/discord.log`
- pid: `vars/pids/discord-bot.pid`
- command/status: `vars/runtime/discord-command.json`, `vars/runtime/discord-status.json`

---

## Design principles

- Minimal cognitive friction
- One action = one intent
- No UI navigation required for frequent tasks
- Secrets stay on the Mac
- iPhone acts only as a trigger layer

---

## Security

- No credentials stored in iCloud
- No secrets in Shortcuts
- Execution handled locally on trusted machine
- SSH used as secure transport layer

---

## Future extensions (checklist)

Prioritized by ROI: frequency, time saved, implementation effort, and risk.

- [x] Create a quick ClickUp inbox task
- [x] Open ClickUp inbox / today tasks
- [x] Open ClickUp roadmaps
- [x] Open a specific ClickUp backlog
- [x] Start/stop a Discord meeting bot session
- [ ] Notify teammates on Rocket.Chat when meeting starts
- [ ] Prepare a meeting workspace (Discord, ClickUp, browser, window layout)
- [ ] Create a simple ClickUp bug ticket
- [ ] Create a structured ClickUp ticket (list, type, taxonomy, description, assignment)
- [ ] Create a ClickUp bug from a support ticket
- [ ] Create multiple inbox tasks from a multi-line list
- [ ] Schedule a Discord meeting
- [ ] Send a reusable Rocket.Chat notification
- [ ] Generate a meeting report from a transcription
- [ ] Add generic macOS workspace actions (split windows, fullscreen, open context)

---

## Vision

This is a personal control layer for my digital workflows.

Not a product.  
Not a framework.  
Just a system to execute daily work faster, with less friction.