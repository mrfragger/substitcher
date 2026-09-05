#!/bin/bash
set -e

DATA_DIR="../assets/daily_quiz"
GITHUB_API="https://api.github.com/repos/sudosar/quraniq-source/contents/data/history"
RAW_BASE="https://raw.githubusercontent.com/sudosar/quraniq-source/main/data/history"

mkdir -p "$DATA_DIR"

echo "Fetching remote file list..."
REMOTE_FILES=$(curl -s "$GITHUB_API" | jq -r '.[] | select(.name | endswith(".json")) | .name')

LOCAL_FILES=$(ls -1 "$DATA_DIR"/*.json 2>/dev/null | xargs -n1 basename || echo "")

DOWNLOADED=0
for FILE in $REMOTE_FILES; do
    if [[ ! -f "$DATA_DIR/$FILE" ]]; then
        echo "Downloading: $FILE"
        if curl -s -f -o "$DATA_DIR/$FILE" "$RAW_BASE/$FILE"; then
            if jq empty "$DATA_DIR/$FILE" 2>/dev/null; then
                echo "Downloaded: $FILE"
                DOWNLOADED=$((DOWNLOADED + 1))
            else
                echo "Invalid JSON: $FILE, removing"
                rm "$DATA_DIR/$FILE"
            fi
        else
            echo "Failed to download: $FILE"
        fi
    fi
done

echo "Done! Downloaded $DOWNLOADED new files."
