#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
RAYCAST_CONFIG_DIR="${DOTFILES_DIR}/configs/raycast"

PASSWORD="${RAYCAST_SETTINGS_PASSWORD:-12345678}"

INPUT_FILE="${1:-${RAYCAST_CONFIG_DIR}/raycast.json}"
HEADER_FILE="${RAYCAST_CONFIG_DIR}/header.bin"
OUTPUT_FILE="${2:-$HOME/Desktop/Raycast-import.rayconfig}"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: $INPUT_FILE not found"
  exit 1
fi

if [[ ! -f "$HEADER_FILE" ]]; then
  echo "Error: $HEADER_FILE not found (run raycast-export.sh first)"
  exit 1
fi

echo "Creating .rayconfig from $INPUT_FILE..."

TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

gzip -c "$INPUT_FILE" > "$TEMP_FILE"
cat "$HEADER_FILE" "$TEMP_FILE" | openssl enc -e -aes-256-cbc -nosalt -k "$PASSWORD" -out "$OUTPUT_FILE"

echo "Created: $OUTPUT_FILE"
echo ""
echo "Import into Raycast:"
echo "  1. Open Raycast"
echo "  2. Run 'Import Settings & Data' command"
echo "  3. Select: $OUTPUT_FILE"
echo "  4. Enter password: $PASSWORD"
echo ""
echo "Or run: open raycast://extensions/raycast/raycast/import-settings-data"
