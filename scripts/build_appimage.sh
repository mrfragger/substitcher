#!/bin/bash

set -e

APP_NAME="substitcher"
APP_VERSION="26.08.03"
BUILD_DIR="build/linux/x64/release/bundle"
APPDIR="AppDir"

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

echo "Copying llama-server binary..."
mkdir -p $APPDIR/usr/bin/llama

if [ -f "temp-llama/llama-server" ]; then
    echo "Using llama-server from temp-llama (artifact)..."
    cp temp-llama/* $APPDIR/usr/bin/llama/
    chmod +x $APPDIR/usr/bin/llama/llama-server
elif [ -f "$BUILD_DIR/llama/llama-server" ]; then
    echo "Using llama-server from Flutter bundle..."
    cp $BUILD_DIR/llama/* $APPDIR/usr/bin/llama/
    chmod +x $APPDIR/usr/bin/llama/llama-server
else
    echo "Warning: llama-server binary not found"
    echo "Checked: temp-llama/ and $BUILD_DIR/llama/"
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
cat > $APPDIR/$APP_NAME.desktop << EOF
[Desktop Entry]
Name=SubStitcher
Exec=substitcher
Icon=substitcher
Type=Application
Categories=AudioVideo;Audio;
Comment=Audiobook player with subtitle support
Terminal=false
EOF

cp $APPDIR/$APP_NAME.desktop $APPDIR/usr/share/applications/

echo "Creating icon..."
cat > $APPDIR/substitcher.png << 'ICONEOF'
iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAYAAABccqhmAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAALEwAACxMBAJqcGAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAIoSURBVHic7doxAQAgDMCwgX/P4UBCCL1WZg4g67oHAN8YAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJj9Y+kCJ/bqQiEAAAAASUVORK5CYII=
ICONEOF

cp $APPDIR/substitcher.png $APPDIR/usr/share/icons/hicolor/256x256/apps/

echo "Creating AppRun script..."
cat > $APPDIR/AppRun << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin/bin:${HERE}/usr/bin/llama:${PATH}"
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
