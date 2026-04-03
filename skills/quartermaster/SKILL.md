---
name: quartermaster
description: Inventory and shopping list management — usage tracking, restock alerts, Apple Reminders sync. Use when inventory/shopping data appears in session context, when the user mentions shopping, groceries, supplies, or when integrating with morning briefings.
---

Quartermaster tracks household inventory and manages shopping lists with Apple Reminders sync.

## Available Commands

- `/inv-list` — view inventory items, filter by category, check restock status
- `/inv-update` — add, adjust, or remove inventory items and usage tracking
- `/shop-list` — view, create, archive shopping lists; sync with Apple Reminders
- `/shop-add` — add items to a shopping list manually, from inventory, or bulk restock
- `/shop-done` — mark items purchased, trigger inventory update prompts
- `/qm-config` — configure categories, directories, sync settings

## Behavior Modes

### Mode 1: Morning Briefing Integration

When this is a morning session:

1. Run `quartermaster inv-list --low-only --summary` → restock alerts; Run `quartermaster shop-list --sync --summary` → active shopping lists
2. Include a "Quartermaster" section in the morning briefing
3. Surface restock alerts with item names, quantities, and days-until-empty
4. Show active shopping lists with item counts and sync status
5. Show newly purchased items and offer inventory updates
6. Format as item-specific summaries, not full tables:
   - "Restock soon: Coffee (1 bag, ~7 days), Paper towels (2 rolls, ~5 days)"
   - "Shopping: Weekly Groceries (8 items, synced), Hardware (3 items, not synced)"
   - "Purchased: Milk, Eggs, Bread — run /shop-done to update inventory"
7. If everything is stocked and no active lists: "Supplies nominal"

### Mode 2: Session Context Check

Every session start (not just mornings):

1. Read the Quartermaster data from SessionStart context
2. **Restock alerts:** Mention proactively — these need attention
3. **Purchased items:** Prompt to update inventory
4. **Active lists with unsynced items:** Suggest `/shop-list --sync`
5. **All stocked, no active lists:** Stay silent

### Mode 3: On-Demand Management

When the user asks about inventory or shopping:

| User says | Use |
|-----------|-----|
| "What do I need?" / "shopping list" | `/shop-list` |
| "Add X to the list" | `/shop-add` |
| "I bought X" / "got the groceries" | `/shop-done` |
| "What do I have?" / "inventory" / "how much X" | `/inv-list` |
| "I bought 3 bags of coffee" / "update stock" | `/inv-update` |
| "Configure quartermaster" / "qm settings" | `/qm-config` |

### Mode 4: Proactive Suggestions

During sessions, if the user mentions:
- Running low on something → check inventory, suggest adding to a list
- Going shopping / heading to the store → suggest `/shop-list --sync` to push to Reminders
- Receiving a delivery → suggest `/inv-update` to update quantities

**Never add items, sync, or update inventory without user direction.**

## Cross-Talk Workflow

Inventory and shopping lists work together:

1. `/inv-list --low-only` → items below restock threshold
2. `/shop-add --list <id> --restock` → add all low items to a list
3. `/shop-list --sync` → push to Apple Reminders for mobile access
4. User shops on mobile, checks off items in Reminders
5. Next session → sync pulls completions automatically
6. `/shop-done` → mark purchased, prompt for inventory update
7. `/inv-update --set <id> --qty <N>` → update inventory

## Safety Rules

- **Never modify inventory or lists without user direction.**
- **Never run `--sync` without informing the user.** (Session hook sync is silent and lightweight.)
- **EventKit permission optional.** If denied, all local commands work. Only sync is affected.
- **Archived lists are not deleted.** They're preserved for history.
