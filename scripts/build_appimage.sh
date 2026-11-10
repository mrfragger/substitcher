#!/bin/bash

set -e

APP_NAME="substitcher"
APP_VERSION="26.11.10"
BUILD_DIR="build/linux/x64/release/bundle"
APPDIR="AppDir"
APP_ID="io.github.mrfragger.substitcher"

echo "Creating AppDir structure..."
rm -rf $APPDIR
mkdir -p $APPDIR/usr/{bin,lib,share/applications,share/icons/hicolor/256x256/apps}

echo "Copying app files..."
cp -r $BUILD_DIR/* $APPDIR/usr/bin/

echo "Copying fonts directory..."
if [ -d "fonts" ]; then
    mkdir -p $APPDIR/usr/bin/data/flutter_assets
    cp -r fonts $APPDIR/usr/bin/data/flutter_assets/
    echo "Fonts copied to AppImage"
else
    echo "Warning: fonts directory not found"
fi

echo "Copying FFmpeg binaries..."
mkdir -p $APPDIR/usr/bin/bin

if [ -f "$BUILD_DIR/bin/ffmpeg" ] && [ -f "$BUILD_DIR/bin/ffprobe" ]; then
    echo "Using pre-built LGPL FFmpeg from artifact..."
    cp $BUILD_DIR/bin/ffmpeg $APPDIR/usr/bin/bin/
    cp $BUILD_DIR/bin/ffprobe $APPDIR/usr/bin/bin/
    chmod +x $APPDIR/usr/bin/bin/ffmpeg
    chmod +x $APPDIR/usr/bin/bin/ffprobe
else
    echo "ERROR: LGPL FFmpeg binaries not found at $BUILD_DIR/bin/ffmpeg and $BUILD_DIR/bin/ffprobe."
    echo "This build requires the LGPL FFmpeg artifact from build_ffmpeg.yml — check the 'Download Linux FFmpeg' step."
    exit 1
fi

echo "Copying Whisper binaries..."
mkdir -p $APPDIR/usr/bin/whisper

if [ -f "temp-whisper/whisper-cli" ]; then
    echo "Using Whisper from temp-whisper (artifact)..."
    cp temp-whisper/* $APPDIR/usr/bin/whisper/
    chmod +x $APPDIR/usr/bin/whisper/whisper-cli
elif [ -f "$BUILD_DIR/whisper/whisper-cli" ]; then
    echo "Using Whisper from Flutter bundle..."
    cp $BUILD_DIR/whisper/* $APPDIR/usr/bin/whisper/
    chmod +x $APPDIR/usr/bin/whisper/whisper-cli
else
    echo "Warning: Whisper binaries not found"
    echo "Checked: temp-whisper/ and $BUILD_DIR/whisper/"
fi

echo "Copying DeepFilter binaries..."
mkdir -p $APPDIR/usr/bin/deepfilter

if [ -f "temp-deepfilter/deep-filter" ]; then
    echo "Using DeepFilter from temp-deepfilter (artifact)..."
    cp temp-deepfilter/* $APPDIR/usr/bin/deepfilter/
    chmod +x $APPDIR/usr/bin/deepfilter/deep-filter
elif [ -f "$BUILD_DIR/deepfilter/deep-filter" ]; then
    echo "Using DeepFilter from Flutter bundle..."
    cp $BUILD_DIR/deepfilter/* $APPDIR/usr/bin/deepfilter/
    chmod +x $APPDIR/usr/bin/deepfilter/deep-filter
else
    echo "Warning: DeepFilter binaries not found"
    echo "Checked: temp-deepfilter/ and $BUILD_DIR/deepfilter/"
fi

echo "Creating desktop file..."
cat > $APPDIR/$APP_ID.desktop << EOF
[Desktop Entry]
Name=SubStitcher
Exec=substitcher
Icon=substitcher
Type=Application
Categories=AudioVideo;Audio;
Comment=Audiobook player with subtitle support
Terminal=false
EOF

cp $APPDIR/$APP_ID.desktop $APPDIR/usr/share/applications/

echo "Creating icon..."
ICON_SRC="assets/icon.png"
if [ ! -f "$ICON_SRC" ]; then
    echo "ERROR: $ICON_SRC not found"
    exit 1
fi

# Downscale 1024x1024 -> 256x256 (recommended size); fall back to the original if no ImageMagick
if command -v magick >/dev/null 2>&1; then
    magick "$ICON_SRC" -resize 256x256 $APPDIR/substitcher.png
elif command -v convert >/dev/null 2>&1; then
    convert "$ICON_SRC" -resize 256x256 $APPDIR/substitcher.png
else
    echo "ImageMagick not found, using original icon size"
    cp "$ICON_SRC" $APPDIR/substitcher.png
fi

cp $APPDIR/substitcher.png $APPDIR/usr/share/icons/hicolor/256x256/apps/

echo "Creating AppStream metadata..."
mkdir -p $APPDIR/usr/share/metainfo
cat > $APPDIR/usr/share/metainfo/$APP_ID.appdata.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>$APP_ID</id>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>MIT</project_license>
  <name>SubStitcher</name>
  <summary>Audiobook encoder and player with subtitle support</summary>
  <developer id="io.github.mrfragger">
    <name>mrfragger</name>
  </developer>
  <description>
    <p>SubStitcher is an audiobook encoder and player with subtitle support, bundling FFmpeg, Whisper transcription and DeepFilter noise reduction.</p>
  </description>
  <launchable type="desktop-id">$APP_ID.desktop</launchable>
  <url type="homepage">https://github.com/mrfragger/substitcher</url>
  <url type="bugtracker">https://github.com/mrfragger/substitcher/issues</url>
  <content_rating type="oars-1.1"/>
  <provides>
    <binary>substitcher</binary>
  </provides>
  <releases>
    <release version="$APP_VERSION" date="$(date +%F)"/>
  </releases>
</component>
EOF

echo "Creating AppRun script..."
cat > $APPDIR/AppRun << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin/bin"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
cd "${HERE}/usr/bin"
exec ./substitcher "$@"
EOF

chmod +x $APPDIR/AppRun

echo "Copying dependencies..."
mkdir -p $APPDIR/usr/lib

ldd $BUILD_DIR/substitcher | grep "=> /" | awk '{print $3}' | while read lib; do
    if [[ $lib == /lib/* ]] || [[ $lib == /usr/lib/* ]]; then
        continue
    fi
    cp "$lib" $APPDIR/usr/lib/ 2>/dev/null || true
done

echo "Downloading appimagetool..."
if [ ! -f appimagetool-x64.AppImage ]; then
    wget https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool-x64.AppImage
    chmod +x appimagetool-x64.AppImage
fi

echo "Creating AppImage..."
ARCH=x86_64 ./appimagetool-x64.AppImage --appimage-extract-and-run $APPDIR $APP_NAME-x64.AppImage

echo "AppImage created: $APP_NAME-x64.AppImage"
ls -lh $APP_NAME-x64.AppImage
