---
description: Mark items as purchased and trigger inventory update prompts
argument-hint: --list <id> [--item <name> | --all]
allowed-tools: Bash(*quartermaster*)
---

Mark shopping list items as purchased.

**Step 1: Run the command**

```
<quartermaster-plugin-root>/scripts/quartermaster shop-done --list <id> [--item <name> | --all]
```

**Step 2: Present results**

Show how many items were marked purchased.

**Step 3: Handle inventory updates**

If the response includes `inventory_updates`, present them:
| Item | Purchased Qty | Unit | Inventory ID |
|------|--------------|------|--------------|

Ask the user: "Update inventory for these items?"

If approved, run `/inv-update --set <id> --qty <new_qty>` for each item, adding the purchased quantity to the current inventory quantity.

**Step 4: Suggest next steps**

If all items in the list are purchased, suggest `/shop-list --archive <id>` to archive the completed list.
