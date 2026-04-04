---
description: Configure Quartermaster — categories, save directories, sync settings
argument-hint: [--show | --reset | --set-lists-dir <path> | --set-briefs-dir <path> | --set-sync-list <name> | --set-sync-on-session-start <true|false> | --add-category <name> | --remove-category <name> | --list-reminder-lists]
allowed-tools: Bash(*quartermaster*)
---

Set up or reconfigure Quartermaster preferences.

**Step 1: Check for flags**

If `--show`, run:
```
<quartermaster-plugin-root>/scripts/quartermaster qm-config --show
```
Display current config as a formatted summary and stop.

If `--reset`, run:
```
<quartermaster-plugin-root>/scripts/quartermaster qm-config --reset
```
Confirm reset was applied and stop.

**Step 2: Show current config**

Run `--show` first to display the current state. Present as:
- Categories list
- Save directories (lists, briefs)
- Sync reminder list name
- Sync on session start (enabled/disabled)
- Last sync timestamp

**Step 3: Ask what to configure**

Ask the user what they'd like to change:
- Add or remove categories
- Change save directories for lists or briefs
- Change which Apple Reminders list to sync with (use `--list-reminder-lists` to show available options)
- Enable or disable session-start sync (use `--set-sync-on-session-start true` or `false`)

**Step 4: Apply changes**

Run the appropriate `qm-config` subcommand for each change.

**Step 5: Confirm**

Run `--show` again and present the updated configuration summary.
