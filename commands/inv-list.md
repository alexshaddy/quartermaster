---
description: View inventory items — filter by category, check restock status
argument-hint: [--category <name>] [--low-only] [--summary] [--save-brief]
allowed-tools: Bash(*quartermaster*)
---

View inventory items with optional filtering.

**Step 1: Run the command**

```
<quartermaster-plugin-root>/scripts/quartermaster inv-list [--category <name>] [--low-only] [--summary] [--save-brief]
```

**Step 2: Format output**

Present inventory as a detailed table:
| Item | Qty | Unit | Category | Threshold | Usage | Days Left | Status |
|------|-----|------|----------|-----------|-------|-----------|--------|

Use ⚠ for low stock items. Show days-until-restock for items with usage tracking.

For `--summary`, present a condensed view with just restock alerts.

**Step 3: Suggest actions**

If low stock items exist, suggest `/shop-add --list <id> --restock` to add them to a shopping list.
