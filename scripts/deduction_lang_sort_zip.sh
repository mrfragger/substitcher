#!/bin/bash
set -e

# 1. Moves translated deduction files out of per-date folders and into per-language folders.
#
#   assets/deduction_all/2026-02-08.translations/2026-02-08.Acehnese.json
#     -> assets/deduction_Acehnese/2026-02-08.Acehnese.json
#
#    Once a *.translations folder is empty, it is deleted.
#
# 2. Then zips each assets/deduction_<Language>/ folder (except deduction_all) into
#      assets/deduction_zips/<Language>.zip
#    Entries are flat (2026-02-08.French.json, no folder prefix), no macOS junk files.

ASSETS_DIR="../assets"
SOURCE_DIR="$ASSETS_DIR/deduction_all"
ZIP_DIR="$ASSETS_DIR/deduction_zips"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Source directory not found: $SOURCE_DIR"
    exit 1
fi

MOVED=0
SKIPPED=0
REMOVED_DIRS=0
TOUCHED=" "   # languages that received files this run (forces a re-zip)

# ---------------------------------------------------------------- sort
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
        TOUCHED="$TOUCHED$LANG_NAME "
    done

    # Delete the translations folder only if it's now empty
    if rmdir "$TDIR" 2>/dev/null; then
        echo "  Removed empty folder: $(basename "$TDIR")"
        REMOVED_DIRS=$((REMOVED_DIRS + 1))
    else
        echo "  Folder not empty, kept: $(basename "$TDIR")"
    fi
done

echo "Sort done: moved $MOVED files, skipped $SKIPPED, removed $REMOVED_DIRS empty folders."

# ---------------------------------------------------------------- zip
echo
echo "Zipping language folders..."
mkdir -p "$ZIP_DIR"
ZIP_ABS="$(cd "$ZIP_DIR" && pwd)"

BUILT=0
UPTODATE=0

for DIR in "$ASSETS_DIR"/deduction_*/; do
    NAME=$(basename "$DIR")
    [[ "$NAME" == "deduction_all" || "$NAME" == "deduction_zips" ]] && continue
    LANG_NAME="${NAME#deduction_}"
    ZIP="$ZIP_ABS/$LANG_NAME.zip"

    # Skip if the zip exists, nothing was moved in this run, and no file is newer than the zip
    if [[ -f "$ZIP" && "$TOUCHED" != *" $LANG_NAME "* ]] \
       && [[ -z "$(find "$DIR" -type f -newer "$ZIP" -print -quit)" ]]; then
        UPTODATE=$((UPTODATE + 1))
        continue
    fi

    rm -f "$ZIP"
    (
        cd "$DIR"
        zip -r -q -X -9 "$ZIP" . \
            -x "*.DS_Store" \
            -x "*/.DS_Store" \
            -x "*/__MACOSX/*" \
            -x "__MACOSX/*" \
            -x "*/._*" \
            -x "._*" \
            -x "*/.AppleDouble/*" \
            -x "*/.Spotlight-V100/*" \
            -x "*/.Trashes/*" \
            -x "*/.fseventsd/*" \
            -x "*/.TemporaryItems/*" \
            -x "*/.localized" \
            -x "*/.VolumeIcon.icns" \
            -x "*/Icon?"
    )
    echo "  Zipped $LANG_NAME"
    BUILT=$((BUILT + 1))
done

# Remove zips whose source folder no longer exists
for ZIP in "$ZIP_ABS"/*.zip; do
    L=$(basename "$ZIP" .zip)
    if [[ ! -d "$ASSETS_DIR/deduction_$L" ]]; then
        rm -f "$ZIP"
        echo "  Removed stale $L.zip"
    fi
done
shopt -u nullglob

echo "Done! Zipped $BUILT, already up to date $UPTODATE."
