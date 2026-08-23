# Source structure

The shared CLI is split by responsibility:

- `../bin/shortcuts` defines the `argc` command handlers. Each handler receives
  parsed arguments and delegates to a controller through `dispatch`.
- `dispatcher.sh` is the technical execution boundary. It runs a controller,
  isolates intermediate output, logs the outcome, and renders the standard
  JSON response from the exit status.
- `controllers/` contains action orchestration. Controllers may depend on one
  or more services as business capabilities are implemented.

Business-specific decisions belong in controllers or their services, not in
the command handlers or dispatcher.
