#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "Compiling quartermaster..."
swiftc "$SCRIPT_DIR/quartermaster.swift" -o "$SCRIPT_DIR/quartermaster" -framework EventKit -O
echo "Done: $SCRIPT_DIR/quartermaster"
