#!/bin/bash
set -e

DATA_DIR="../assets/daily_quiz"
GITHUB_API="https://api.github.com/repos/sudosar/quraniq-source/contents/data/history"
RAW_BASE="https://raw.githubusercontent.com/sudosar/quraniq-source/main/data/history"

NEW_VERSION="$1"   # optional: e.g. ./daily_quiz_download.sh 26.09.22

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

        if grep -qE "$pattern" "$file"; then
            gsed -i -E "s/$pattern/$replacement/" "$file"
            echo "Updated $label -> $NEW_VERSION"
        else
            echo "Warning: version pattern not found in $file, skipping."
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

echo "All done."
