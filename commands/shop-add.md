---
description: Add items to a shopping list — manually, from inventory, or bulk restock
argument-hint: --list <id> [--name <name> --qty <N> --unit <unit> [--category <cat>] | --from-inventory <inv-id> [--qty <N>] | --restock]
allowed-tools: Bash(*quartermaster*)
---

Add items to a shopping list.

**Step 1: Parse arguments and run**

```
<quartermaster-plugin-root>/scripts/quartermaster shop-add --list <id> <mode flags>
```

Three modes:
- **Manual:** `--name <name> --qty <N> --unit <unit>` — add any item
- **From inventory:** `--from-inventory <inv-id>` — links to inventory for purchase→update flow
- **Bulk restock:** `--restock` — adds all inventory items below restock threshold

**Step 2: Format output**

Confirm the added item(s). For `--restock`, show all items added with quantities.

**Step 3: Suggest next steps**

After adding items, suggest `/shop-list --sync` to push to Apple Reminders for mobile access.
