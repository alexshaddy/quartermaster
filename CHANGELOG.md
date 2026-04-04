# Changelog

## [0.1.2] — 2026-04-04

### Fixed
- `resolvePath` and `isPathSafe` now handle bare `~` (no trailing slash) as home directory
- `isPathSafe` delegates tilde expansion to `resolvePath` — eliminates duplicate logic
- `saveBrief` returns `Bool`; `brief_saved` in output reflects actual write outcome
- `--export` uses throwing write with `exitWithError("export_write_failed")` on failure
- `--set-sync-on-session-start` guard uses `"invalid_value"` error code with structured extras
- `exitWithError` in `findOrCreateReminderList` uses machine-readable codes (`reminders_access_denied`, `create_list_failed`) instead of human strings
- `qm-config.md --show` display list now includes `sync_on_session_start`

## [0.1.0] - 2026-03-30

### Added
- Initial release
- `inv-list` — view inventory with category filtering and restock alerts
- `inv-update` — add, adjust, configure usage tracking, remove inventory items
- `shop-list` — view, create, archive shopping lists with Apple Reminders sync
- `shop-add` — add items manually, from inventory, or bulk restock
- `shop-done` — mark items purchased with inventory update prompts
- `qm-config` — configure categories, save directories, sync reminder list
- Usage rate tracking with days-until-restock calculations
- Two-way Apple Reminders sync via EventKit
- SessionStart hook with restock alerts and shopping list summary
- Morning briefing integration
- Briefs and markdown list export system
