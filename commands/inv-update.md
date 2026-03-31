---
description: Add, adjust, or remove inventory items and usage tracking
argument-hint: [--add --name <name> --qty <N> --unit <unit> --category <cat> [...] | --set <id> [--qty <N>] [...] | --remove <id>]
allowed-tools: Bash(*quartermaster*)
---

Manage inventory items.

**Step 1: Parse arguments and run**

```
<quartermaster-plugin-root>/scripts/quartermaster inv-update <flags>
```

**Step 2: Format output**

For `--add`, confirm the new item with all fields.
For `--set`, show the updated item with changed fields highlighted.
For `--remove`, confirm removal.

**Step 3: Suggest next steps**

After adding or updating items with restock thresholds, suggest running `/inv-list --low-only` to check restock status.
