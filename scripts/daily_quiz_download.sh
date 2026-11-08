#!/bin/bash
set -e

DATA_DIR="../assets/daily_quiz"
DEDUCTION_DIR="../assets/deduction_all"
GITHUB_API="https://api.github.com/repos/sudosar/quraniq-source/contents/data/history"
RAW_BASE="https://raw.githubusercontent.com/sudosar/quraniq-source/main/data/history"

NEW_VERSION="$1"   # optional: e.g. ./daily_quiz_download.sh 26.09.22

mkdir -p "$DATA_DIR"
mkdir -p "$DEDUCTION_DIR"

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

TOTAL=$(ls -1 "$DATA_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
echo "Done! Downloaded $DOWNLOADED new files."
echo "Total JSON files in $DATA_DIR: $TOTAL"

if [[ "$DOWNLOADED" -gt 0 ]]; then
    echo "modified lib/widgets/side_panel.dart reflecting new count"
    echo "_buildTabButton(context, '⌘Quiz', PanelMode.quiz, $TOTAL),"
    echo "_buildTabButton(context, '⌘Related', PanelMode.related, $TOTAL),"

    gsed -i "s/_buildTabButton(context, '⌘Quiz', PanelMode.quiz, [0-9]*)/_buildTabButton(context, '⌘Quiz', PanelMode.quiz, $TOTAL)/" ../lib/widgets/side_panel.dart
    gsed -i "s/_buildTabButton(context, '⌘Related', PanelMode.related, [0-9]*)/_buildTabButton(context, '⌘Related', PanelMode.related, $TOTAL)/" ../lib/widgets/side_panel.dart
else
    echo "No new files downloaded, side_panel.dart left unchanged."
fi

# --- Extract "deduction" section into assets/deduction_all/DATE.json ---
# Runs over ALL files in daily_quiz (not just newly downloaded ones), and only
# creates output for dates that don't already have a deduction file. After a
# successful extract, the "deduction" section is deleted from the daily_quiz
# original (also cleans up files extracted on earlier runs).
echo "Extracting deduction sections into $DEDUCTION_DIR..."
EXTRACTED=0
SKIPPED_EXISTING=0
SKIPPED_NONE=0
STRIPPED=0
shopt -s nullglob
for SRC in "$DATA_DIR"/*.json; do
    BASE=$(basename "$SRC" .json)

    # Date comes from the filename (YYYY-MM-DD); fall back to a "date" field in the JSON
    if [[ "$BASE" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        DATE="${BASH_REMATCH[1]}"
    else
        DATE=$(jq -r '.date // empty' "$SRC" 2>/dev/null || true)
        if [[ ! "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            echo "Skipping $BASE: could not determine date."
            continue
        fi
    fi

    OUT="$DEDUCTION_DIR/$DATE.json"

    if [[ ! -f "$OUT" ]]; then
        # Write to a temp file first so a failure never leaves a partial output file
        TMP=$(mktemp)
        if jq -e '(.deduction // .data.deduction) | select(. != null)' "$SRC" > "$TMP" 2>/dev/null; then
            mv "$TMP" "$OUT"
            echo "Wrote: $OUT"
            EXTRACTED=$((EXTRACTED + 1))
        else
            rm -f "$TMP"
            echo "No deduction section in $BASE, skipping."
            SKIPPED_NONE=$((SKIPPED_NONE + 1))
            continue
        fi
    else
        SKIPPED_EXISTING=$((SKIPPED_EXISTING + 1))
    fi

    # Remove the deduction section from the original, but only if it's still there
    # AND the extracted file is valid, non-empty JSON (so data is never lost).
    if jq -e 'has("deduction") or ((.data // {}) | type == "object" and has("deduction"))' "$SRC" >/dev/null 2>&1; then
        if jq -e 'type == "object" and length > 0' "$OUT" >/dev/null 2>&1; then
            TMP=$(mktemp)
            if jq 'del(.deduction) | if (.data | type) == "object" then .data |= del(.deduction) else . end' "$SRC" > "$TMP" 2>/dev/null \
               && jq empty "$TMP" 2>/dev/null; then
                mv "$TMP" "$SRC"
                echo "Removed deduction from: $(basename "$SRC")"
                STRIPPED=$((STRIPPED + 1))
            else
                rm -f "$TMP"
                echo "Could not strip deduction from $(basename "$SRC"), left unchanged."
            fi
        else
            echo "Extracted file for $DATE looks invalid, original left unchanged."
        fi
    fi
done
shopt -u nullglob
echo "Deduction extraction: $EXTRACTED new, $SKIPPED_EXISTING already existed, $SKIPPED_NONE without a deduction section, $STRIPPED originals stripped."

# --- Optional version bump ---
if [[ -n "$NEW_VERSION" ]]; then
    if [[ ! "$NEW_VERSION" =~ ^[0-9]{2}\.[0-9]{2}\.[0-9]{2}$ ]]; then
        echo "Warning: '$NEW_VERSION' doesn't match expected YY.MM.DD format. Continuing anyway."
    fi

    PKGBUILD_FILE="./PKGBUILD"
    APPIMAGE_FILE="./build_appimage.sh"
    PUBSPEC_FILE="../pubspec.yaml"

    update_file() {
        local file="$1"
        local pattern="$2"
        local replacement="$3"
        local label="$4"

        if [[ ! -f "$file" ]]; then
            echo "Skipping $label: $file not found."
            return
        fi

        local current
        current=$(grep -m1 -oE "$pattern" "$file" || true)

        if [[ -z "$current" ]]; then
            echo "Warning: version pattern not found in $file, skipping."
        elif [[ "$current" == "$replacement" ]]; then
            echo "$label already at $NEW_VERSION, unchanged."
        else
            gsed -i -E "s/$pattern/$replacement/" "$file"
            echo "Updated $label: $current -> $replacement"
        fi
    }

    update_file "$PKGBUILD_FILE" \
        "^pkgver=[0-9.]+" \
        "pkgver=$NEW_VERSION" \
        "PKGBUILD"

    update_file "$APPIMAGE_FILE" \
        'APP_VERSION="[0-9.]+"' \
        "APP_VERSION=\"$NEW_VERSION\"" \
        "build_appimage.sh"

    update_file "$PUBSPEC_FILE" \
        "^version: [0-9.]+" \
        "version: $NEW_VERSION" \
        "pubspec.yaml"
else
    echo "No version argument given, skipping version bump (PKGBUILD / build_appimage.sh / pubspec.yaml)."
fi

echo "All done. Last run: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Best to run at after 03:06 UTC or 03:36 UTC"
