---
description: Mark items as purchased and trigger inventory update prompts
argument-hint: --list <id> [--item <name> | --all]
allowed-tools: Bash(*quartermaster*)
---

Mark shopping list items as purchased.

**Before running shop-done, you must fetch current inventory quantities first.** This is required to compute the correct post-purchase totals — shop-done does not read or write inventory directly.

**Step 1: Fetch current inventory**

```
<quartermaster-plugin-root>/scripts/quartermaster inv-list
```

Note the current `quantity` for any items that will be updated after purchase.

**Step 2: Mark items purchased**

```
<quartermaster-plugin-root>/scripts/quartermaster shop-done --list <id> [--item <name> | --all]
```

**Step 3: Present results**

Show how many items were marked purchased.

**Step 4: Handle inventory updates**

If the response includes `inventory_updates`, present them:
| Item | Purchased Qty | Unit | Inventory ID |
|------|--------------|------|--------------|

Ask the user: "Update inventory for these items?"

If approved, for each item:
1. Look up the current quantity you fetched in Step 1 (e.g. Coffee: 1 bag)
2. Add the purchased quantity (e.g. purchased_qty: 2)
3. Run: `inv-update --set <inventory_id> --qty <current + purchased>`

**Worked example:**

```
# Step 1: fetch inventory
inv-list
# → Coffee: id=coffee, quantity=1, unit=bag

# Step 2: mark purchased
shop-done --list weekly --item Coffee
# → inventory_updates: [{inventory_id: "coffee", purchased_qty: 2, unit: "bag"}]

# Step 4: compute new qty = 1 (current) + 2 (purchased) = 3
inv-update --set coffee --qty 3
```

**Step 5: Suggest next steps**

If all items in the list are purchased, suggest `/shop-list --archive <id>` to archive the completed list.
