# Contributing

Quartermaster is a Claude Code plugin in The Grounds estate.

## Development

1. Clone the repo
2. Run `bash scripts/build.sh` to compile
3. Test commands: `scripts/quartermaster <subcommand> [args]`

## Architecture

Single Swift source file (`scripts/quartermaster.swift`), compiled with `swiftc`. No SPM, no external dependencies. Uses EventKit for Apple Reminders integration.

## Code Standards

- JSON stdout for output, JSON stderr for errors
- No `Process()` or shell-out calls
- Foundation APIs for data management, EventKit for Reminders sync
- All mutations return updated state
