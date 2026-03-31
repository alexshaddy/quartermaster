---
description: View, create, archive shopping lists; sync with Apple Reminders
argument-hint: [--all] [--create <name>] [--view <id>] [--archive <id>] [--sync [--summary]] [--export <id>] [--save-brief]
allowed-tools: Bash(*quartermaster*)
---

Manage shopping lists.

**Step 1: Parse arguments and run**

```
<quartermaster-plugin-root>/scripts/quartermaster shop-list <flags>
```

**Step 2: Format output**

For default view, present as a table:
| List | Items | Purchased | Archived | Created |
|------|-------|-----------|----------|---------|

For `--view <id>`, show items as a detailed table:
| Item | Qty | Unit | Category | Synced | Purchased | From Inventory |
|------|-----|------|----------|--------|-----------|----------------|

For `--sync`, present:
- Items pushed to Reminders
- Items purchased since last sync (with inventory links)

**Step 3: Suggest next steps**

After sync, if purchased items have inventory links, suggest `/shop-done` to update inventory.
After creating a list, suggest `/shop-add` to add items.

**Note:** Background sync is available — run the command in the background when the user requests it. The binary itself is synchronous.
