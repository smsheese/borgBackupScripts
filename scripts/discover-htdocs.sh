#!/bin/bash

# ============================================================================
# CLOUDPANEL HTDOCS DISCOVERY SCRIPT
# ============================================================================
# This script dynamically discovers all CloudPanel user htdocs directories
# and generates a list file for borgmatic to backup

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
# Source .env file if it exists
if [ -f "$(dirname "$0")/../.env" ]; then
    source "$(dirname "$0")/../.env"
fi

CLOUDPANEL_HOME_BASE="${CLOUDPANEL_HOME_BASE:-/home}"
CLOUDPANEL_HTDOCS_SUBDIR="${CLOUDPANEL_HTDOCS_SUBDIR:-htdocs}"
OUTPUT_FILE="${OUTPUT_FILE:-/etc/borgmatic/htdocs-dirs.txt}"

# Ensure output directory exists
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Creating output directory: $OUTPUT_DIR"
    sudo mkdir -p "$OUTPUT_DIR"
fi

# Create/clear the output file
sudo truncate -s 0 "$OUTPUT_FILE"

# Track statistics
TOTAL_USERS=0
TOTAL_HTDOCS=0

echo "=== CloudPanel Htdocs Discovery ==="
echo "Base path: $CLOUDPANEL_HOME_BASE"
echo "Subdirectory: $CLOUDPANEL_HTDOCS_SUBDIR"
echo "Output file: $OUTPUT_FILE"
echo ""

# Discover all htdocs directories
for user_dir in "$CLOUDPANEL_HOME_BASE"/*; do
    # Skip if not a directory
    [ -d "$user_dir" ] || continue
    
    # Skip if no htdocs subdirectory exists
    htdocs_path="$user_dir/$CLOUDPANEL_HTDOCS_SUBDIR"
    if [ ! -d "$htdocs_path" ]; then
        echo "⏭  Skipping $(basename "$user_dir") - no $CLOUDPANEL_HTDOCS_SUBDIR directory"
        continue
    fi
    
    # Add to output file
    echo "$htdocs_path" | sudo tee -a "$OUTPUT_FILE" > /dev/null
    
    TOTAL_USERS=$((TOTAL_USERS + 1))
    TOTAL_HTDOCS=$((TOTAL_HTDOCS + 1))
    
    echo "✓ Found: $htdocs_path"
done

echo ""
echo "=== Discovery Summary ==="
echo "Total users with htdocs: $TOTAL_USERS"
echo "Total htdocs directories: $TOTAL_HTDOCS"
echo "Output file: $OUTPUT_FILE"

# Exit with error if no directories found
if [ "$TOTAL_HTDOCS" -eq 0 ]; then
    echo ""
    echo "❌ ERROR: No htdocs directories found!"
    echo "   This may indicate:"
    echo "   - CloudPanel is not installed"
    echo "   - No users/sites have been created"
    echo "   - Incorrect base path or subdirectory configuration"
    exit 1
fi

# Show file contents
echo ""
echo "=== Discovered Directories ==="
sudo cat "$OUTPUT_FILE"

echo ""
echo "✓ Discovery completed successfully"
exit 0