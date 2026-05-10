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

## Configuration

Copy and configure environment variables:

```bash
cp config/env.example.sh config/env.sh
source config/env.sh
```

Required variables:

- `CLICKUP_TOKEN`
- `CLICKUP_LIST_ID`

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

- [x] ClickUp tasks
- [ ] Git workflows
- [ ] Meeting creation
- [ ] Task management helpers
- [ ] Messaging automation
- [ ] Calendar / reminders
- [ ] Notes capture / inbox processing
- [ ] “Daily review” routine (one-tap)

---

## Vision

This is a personal control layer for my digital workflows.

Not a product.  
Not a framework.  
Just a system to execute daily work faster, with less friction.