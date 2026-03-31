# Quartermaster

**Estate Role:** The Supplier — tracks provisions, manages procurement, ensures nothing runs short.

Inventory and shopping list management plugin for [Claude Code](https://claude.ai/code). Part of [The Grounds](https://github.com/alexshaddy/the-grounds) estate.

## Features

- **Inventory tracking** — track household items with quantities, categories, and units
- **Usage rate monitoring** — configure consumption rates for proactive restock alerts
- **Shopping lists** — create and manage multiple named shopping lists
- **Apple Reminders sync** — two-way sync with Apple Reminders for mobile shopping access
- **Inventory cross-talk** — items flow from inventory restock alerts to shopping lists to purchase confirmations
- **Morning briefing integration** — restock alerts and shopping status in daily briefings

## Installation

Install via [The Grounds](https://github.com/alexshaddy/the-grounds) marketplace.

## Commands

| Command | Description |
|---------|-------------|
| `/inv-list` | View inventory items, filter by category, check restock status |
| `/inv-update` | Add, adjust, or remove inventory items and usage tracking |
| `/shop-list` | View, create, archive shopping lists; sync with Apple Reminders |
| `/shop-add` | Add items to a shopping list manually or from inventory |
| `/shop-done` | Mark items purchased, trigger inventory updates |
| `/qm-config` | Configure categories, directories, sync settings |

## License

MIT
