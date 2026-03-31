#!/bin/bash
set -euo pipefail

SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/scripts"
QM="$SCRIPT_DIR/quartermaster"

if [ ! -x "$QM" ]; then
    bash "$SCRIPT_DIR/build.sh" >&2 2>&1 || {
        error_msg='{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Quartermaster plugin root: '"$CLAUDE_PLUGIN_ROOT"'\n\n**Quartermaster:** Build failed. Run `bash '"$SCRIPT_DIR"'/build.sh` manually."}}'
        printf '%s' "$error_msg"
        exit 0
    }
fi

INV_JSON=$("$QM" inv-list --low-only --summary 2>/dev/null || echo '{"low_stock_count":0,"low_stock_items":[],"total_items":0}')

SHOP_JSON=$("$QM" shop-list --sync --summary 2>/dev/null || echo '{"active_lists":[],"purchased_since_last_sync":[],"pushed":0}')

python3 -c "
import json, sys, os

root = os.environ.get('CLAUDE_PLUGIN_ROOT', '')

try:
    inv = json.loads('''$INV_JSON''')
except:
    inv = {'low_stock_count': 0, 'low_stock_items': [], 'total_items': 0}

try:
    shop = json.loads('''$SHOP_JSON''')
except:
    shop = {'active_lists': [], 'purchased_since_last_sync': [], 'pushed': 0}

lines = []
has_content = False

low_items = inv.get('low_stock_items', [])
if low_items:
    has_content = True
    lines.append('  Restock alerts:')
    lines.append('  | Item | Qty | Threshold | Usage | Days Left |')
    lines.append('  |------|-----|-----------|-------|-----------|')
    for item in low_items:
        name = item.get('name', '?')
        qty = item.get('quantity', 0)
        unit = item.get('unit', '')
        thresh = item.get('restock_threshold', '—')
        usage = item.get('usage', '—')
        days = item.get('days_until_restock')
        days_str = f'~{days}' if days is not None else '—'
        lines.append(f'  | {name} | {qty} {unit} | {thresh} | {usage} | {days_str} |')

active_lists = shop.get('active_lists', [])
if active_lists:
    has_content = True
    if lines: lines.append('')
    lines.append('  Active shopping lists:')
    lines.append('  | List | Items | Synced |')
    lines.append('  |------|-------|--------|')
    for lst in active_lists:
        name = lst.get('name', '?')
        count = lst.get('item_count', 0)
        synced = 'Yes' if lst.get('synced', False) else 'No'
        lines.append(f'  | {name} | {count} | {synced} |')

purchased = shop.get('purchased_since_last_sync', [])
if purchased:
    has_content = True
    if lines: lines.append('')
    lines.append('  Purchased since last session:')
    lines.append('  | Item | List | Linked Inventory |')
    lines.append('  |------|------|------------------|')
    for p in purchased:
        name = p.get('name', '?')
        lst = p.get('list', '?')
        inv_id = p.get('from_inventory')
        inv_str = inv_id if inv_id is not None else '—'
        lines.append(f'  | {name} | {lst} | {inv_str} |')

if has_content:
    content = 'Quartermaster:\n' + '\n'.join(lines)
else:
    content = 'Quartermaster: Supplies nominal'

print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': 'Quartermaster plugin root: ' + root + '\n\n' + content
    }
}))
"
