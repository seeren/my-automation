# ADR-0001: iPhone Shortcuts + SSH as control layer (vs Stream Deck)

- Status: Accepted
- Date: 2026-05-10

---

## Context

The goal of this repo is to reduce cognitive load and execution friction by converting recurring workflows into **one-tap actions**.

An initial idea was to buy/build a Stream Deck setup, but the target system has specific constraints:

- The “control surface” should be **always available** (phone is already on hand).
- The system should trigger **arbitrary scripts / apps**, including non-standard or non-referenced actions.
- The execution should happen on a **trusted Mac** where secrets can remain local.
- The trigger device is **personal** (iPhone), but workflows may act on **professional systems**.

---

## Decision

Use **iPhone Shortcuts** as the interface and **SSH** to trigger execution on a Mac, where **shell scripts** implement the workflows.

This repo is therefore structured as:

iPhone (Shortcuts) → SSH → Mac → shell scripts → external APIs

---

## Why not Stream Deck

- Hardware is a **single-purpose UI** with limited portability compared to a phone.
- Desired usage includes triggers beyond “predefined app integrations”:
  - arbitrary scripts
  - custom APIs
  - system-level operations
- The iPhone already provides:
  - a distributed UI (shortcuts, widgets, voice)
  - iCloud sync of the interface layer
  - low friction access anywhere

---

## Consequences

### Positive

- **Lowest friction**: one-tap actions from a device always present.
- **Maximum flexibility**: any script can be executed via SSH.
- **Security boundary**: secrets stay on the Mac (not in iCloud, not in Shortcuts).
- **Extensible**: new workflows are “just scripts”.

### Negative / trade-offs

- Requires careful handling of:
  - stdout output format (must be machine-parseable by Shortcuts)
  - logging (for post-mortem debugging)
  - secret redaction
- SSH availability and key management becomes critical.

---

## Required conventions (enforced by design)

- Each SSH trigger maps to **one intent** (one workflow).
- Scripts return a **standard one-line JSON** response for iPhone parsing.
  - See `docs/conventions-shell.md`
- File logs provide deeper trace without polluting stdout.
  - See `docs/logging.md`

---

## Notes

This system is personal infrastructure: not a product and not a framework.
The design optimizes for speed of execution, low cognitive load, and safe local secret handling.

