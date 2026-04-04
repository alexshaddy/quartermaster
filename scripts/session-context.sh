#!/bin/bash
set -euo pipefail

SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/scripts"
QM="$SCRIPT_DIR/quartermaster"
CONFIG_FILE="$HOME/.config/quartermaster/config.json"

if [ ! -x "$QM" ]; then
    bash "$SCRIPT_DIR/build.sh" >/dev/null 2>&1 || {
        error_msg='{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Quartermaster plugin root: '"$CLAUDE_PLUGIN_ROOT"'\n\n**Quartermaster:** Build failed. Run `bash '"$SCRIPT_DIR"'/build.sh` manually."}}'
        printf '%s' "$error_msg"
        exit 0
    }
fi

INV_JSON=$("$QM" inv-list --low-only --summary 2>/dev/null || echo '{"low_stock_count":0,"low_stock_items":[],"total_items":0}')

# Read config values — one python3 call for both dirs and sync flag
read -r BRIEFS_DIR LISTS_DIR SYNC_ENABLED < <(QM_CONFIG_FILE="$CONFIG_FILE" python3 -c "
import json, os
try:
    config = json.load(open(os.environ['QM_CONFIG_FILE']))
    briefs = config.get('briefs_dir', '').strip()
    lists = config.get('lists_dir', '').strip()
    sync = 'true' if config.get('sync_on_session_start', False) else 'false'
    print(briefs, lists, sync)
except:
    print('', '', 'false')
" 2>/dev/null)

if [ "$SYNC_ENABLED" = "true" ]; then
    SHOP_JSON=$("$QM" shop-list --sync --summary 2>/dev/null || echo '{"count":0,"lists":[]}')
else
    SHOP_JSON=$("$QM" shop-list --summary 2>/dev/null || echo '{"count":0,"lists":[]}')
fi

# Format output and optionally save archives — pass JSON via env var to prevent shell injection
QM_INV="$INV_JSON" QM_SHOP="$SHOP_JSON" QM_BRIEFS_DIR="$BRIEFS_DIR" QM_LISTS_DIR="$LISTS_DIR" \
  python3 -c "
import json, os
from datetime import date

root = os.environ.get('CLAUDE_PLUGIN_ROOT', '')
briefs_dir = os.path.expanduser(os.environ.get('QM_BRIEFS_DIR', ''))
lists_dir = os.path.expanduser(os.environ.get('QM_LISTS_DIR', ''))
today = date.today().isoformat()

try:
    inv = json.loads(os.environ.get('QM_INV', '{}'))
except:
    inv = {'low_stock_count': 0, 'low_stock_items': [], 'total_items': 0}

try:
    shop = json.loads(os.environ.get('QM_SHOP', '{}'))
except:
    shop = {'count': 0, 'lists': []}

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

# Support both 'active_lists' (summary flag) and 'lists' (full output)
active_lists = shop.get('active_lists', shop.get('lists', []))
if active_lists:
    has_content = True
    if lines: lines.append('')
    lines.append('  Active shopping lists:')
    lines.append('  | List | Items | Synced |')
    lines.append('  |------|-------|--------|')
    for lst in active_lists:
        name = lst.get('name', '?')
        count = lst.get('item_count', lst.get('count', 0))
        synced = 'Yes' if lst.get('synced', False) else 'No'
        lines.append(f'  | {name} | {count} | {synced} |')

    # Save each list as its own file in lists_dir (current state, overwrites)
    if lists_dir:
        os.makedirs(lists_dir, exist_ok=True)
        for lst in active_lists:
            name = lst.get('name', 'unnamed').replace(' ', '-').lower()
            items = lst.get('items', [])
            list_lines = [f'# {lst.get(\"name\", name)}', f'*Updated: {today}*', '']
            for it in items:
                checkbox = '[x]' if it.get('purchased', False) else '[ ]'
                label = it.get('name', '?')
                qty = it.get('quantity')
                label = f'{label} x{qty}' if qty and qty != 1 else label
                list_lines.append(f'- {checkbox} {label}')
            if not items:
                list_lines.append('*(empty)*')
            list_file = os.path.join(lists_dir, f'{name}.md')
            with open(list_file, 'w') as f:
                f.write('\n'.join(list_lines) + '\n')

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

# Save dated brief
if briefs_dir:
    os.makedirs(briefs_dir, exist_ok=True)
    brief_file = os.path.join(briefs_dir, f'{today}.md')
    with open(brief_file, 'w') as f:
        f.write(f'# Quartermaster Brief — {today}\n\n{content.replace(\"Quartermaster:\", \"\").strip()}\n')

print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': 'Quartermaster plugin root: ' + root + '\n\n' + content
    }
}))
"
