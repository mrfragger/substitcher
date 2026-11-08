#!/bin/bash
set -e

# Moves translated deduction files out of per-date folders and into per-language folders.
#
#   assets/deduction_all/2026-02-08.translations/2026-02-08.Acehnese.json
#     -> assets/deduction_Acehnese/2026-02-08.Acehnese.json
#
# Once a *.translations folder is empty, it is deleted.

ASSETS_DIR="../assets"
SOURCE_DIR="$ASSETS_DIR/deduction_all"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Source directory not found: $SOURCE_DIR"
    exit 1
fi

MOVED=0
SKIPPED=0
REMOVED_DIRS=0

shopt -s nullglob
for TDIR in "$SOURCE_DIR"/*.translations; do
    [[ -d "$TDIR" ]] || continue
    echo "Processing $(basename "$TDIR")"

    for SRC in "$TDIR"/*.json; do
        NAME=$(basename "$SRC")

        # Expected name: YYYY-MM-DD.Language.json  (language may contain underscores)
        if [[ ! "$NAME" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})\.(.+)\.json$ ]]; then
            echo "  Skipping $NAME: doesn't match DATE.Language.json"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi
        LANG_NAME="${BASH_REMATCH[2]}"

        # English lives in deduction_all/DATE.json, so there is no English folder
        if [[ "$LANG_NAME" == "English" ]]; then
            echo "  Skipping $NAME: English is served from deduction_all"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        DEST_DIR="$ASSETS_DIR/deduction_$LANG_NAME"
        DEST="$DEST_DIR/$NAME"
        mkdir -p "$DEST_DIR"

        if [[ -f "$DEST" ]]; then
            echo "  Already exists, leaving in place: $DEST"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        mv "$SRC" "$DEST"
        echo "  Moved: $NAME -> deduction_$LANG_NAME/"
        MOVED=$((MOVED + 1))
    done

    # Delete the translations folder only if it's now empty
    if rmdir "$TDIR" 2>/dev/null; then
        echo "  Removed empty folder: $(basename "$TDIR")"
        REMOVED_DIRS=$((REMOVED_DIRS + 1))
    else
        echo "  Folder not empty, kept: $(basename "$TDIR")"
    fi
done
shopt -u nullglob

echo "Done! Moved $MOVED files, skipped $SKIPPED, removed $REMOVED_DIRS empty folders."
