#!/usr/bin/env bash
# Raycast Config Export Script
# Decrypts .rayconfig and extracts JSON for version control
#
# Usage: raycast-export.sh [input.rayconfig] [output.json]
#
# If no input specified, looks for most recent .rayconfig on Desktop
# If no output specified, outputs to dotfiles/configs/raycast/raycast.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
RAYCAST_CONFIG_DIR="${DOTFILES_DIR}/configs/raycast"

# Default password (Raycast's default)
PASSWORD="${RAYCAST_SETTINGS_PASSWORD:-12345678}"

# Find input file
if [[ -n "${1:-}" ]]; then
  INPUT_FILE="$1"
else
  # Look for most recent .rayconfig on Desktop
  INPUT_FILE=$(ls -t ~/Desktop/*.rayconfig 2>/dev/null | head -1 || true)
  if [[ -z "$INPUT_FILE" ]]; then
    echo "Error: No .rayconfig file found on Desktop"
    echo "Export from Raycast first: raycast://extensions/raycast/raycast/export-settings-data"
    exit 1
  fi
  echo "Found: $INPUT_FILE"
fi

# Output file
OUTPUT_FILE="${2:-${RAYCAST_CONFIG_DIR}/raycast.json}"
HEADER_FILE="${RAYCAST_CONFIG_DIR}/header.bin"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"
mkdir -p "$(dirname "$HEADER_FILE")"

# Create temp file for decrypted data
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

echo "Decrypting $INPUT_FILE..."

# Decrypt the file
if ! openssl enc -d -aes-256-cbc -nosalt -in "$INPUT_FILE" -k "$PASSWORD" -out "$TEMP_FILE" 2>/dev/null; then
  echo "Error: Failed to decrypt. Wrong password?"
  echo "Set RAYCAST_SETTINGS_PASSWORD env var if using non-default password"
  exit 1
fi

# Extract and save the 16-byte header (needed for re-encryption)
head -c 16 "$TEMP_FILE" > "$HEADER_FILE"
echo "Saved header to: $HEADER_FILE"

# Extract and decompress the JSON (skip first 16 bytes)
tail -c +17 "$TEMP_FILE" | gunzip > "$OUTPUT_FILE"
echo "Exported to: $OUTPUT_FILE"

# Show what's included
echo ""
echo "Exported settings include:"
jq -r 'keys[]' "$OUTPUT_FILE" 2>/dev/null | head -20 | sed 's/^/  - /'
echo ""
echo "Done! You can now commit $OUTPUT_FILE to git."
