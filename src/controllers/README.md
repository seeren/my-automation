# Controllers

A controller represents one CLI action. It orchestrates that action and may
delegate business capabilities to one or more services.

To add a command:

1. Create a `<command>.sh` file exposing `<command>_controller`.
2. Source that file from `bin/shortcuts`.
3. Declare the command and its arguments with `argc` annotations.
4. Dispatch the command handler to `<command>_controller`.

Controllers report success or failure through their exit status and do not
format responses. The dispatcher owns technical logging and renders the
standard JSON response.
