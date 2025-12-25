#!/bin/bash

set -e

APP_NAME="substitcher"
APP_VERSION="1.0.0"
BUILD_DIR="build/linux/x64/release/bundle"
APPDIR="AppDir"

echo "Building Flutter app..."
flutter build linux --release

echo "Creating AppDir structure..."
rm -rf $APPDIR
mkdir -p $APPDIR/usr/{bin,lib,share/applications,share/icons/hicolor/256x256/apps}

echo "Copying app files..."
cp -r $BUILD_DIR/* $APPDIR/usr/bin/

echo "Downloading FFmpeg static binaries..."
mkdir -p $APPDIR/usr/bin/bin
cd $APPDIR/usr/bin/bin

# Download static ffmpeg and ffprobe for Linux
wget -q https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar -xf ffmpeg-release-amd64-static.tar.xz --strip-components=1
rm ffmpeg-release-amd64-static.tar.xz
chmod +x ffmpeg ffprobe
# Keep only what we need - remove everything except ffmpeg and ffprobe
find . -type f ! -name 'ffmpeg' ! -name 'ffprobe' -delete
find . -type d -empty -delete
rm -rf model GPLv3.txt readme.txt manpages 2>/dev/null || true

cd ../../../..

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

# Also put it in the standard location
cp $APPDIR/$APP_NAME.desktop $APPDIR/usr/share/applications/

echo "Creating icon..."
# Create a simple 256x256 PNG icon (placeholder - purple square)
cat > $APPDIR/substitcher.png << 'ICONEOF'
iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAYAAABccqhmAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAALEwAACxMBAJqcGAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAIoSURBVHic7doxAQAgDMCwgX/P4UBCCL1WZg4g67oHAN8YAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJgZAJj9Y+kCJ/bqQiEAAAAASUVORK5CYII=
ICONEOF

cp $APPDIR/substitcher.png $APPDIR/usr/share/icons/hicolor/256x256/apps/

echo "Creating AppRun script..."
cat > $APPDIR/AppRun << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
cd "${HERE}/usr/bin"
exec ./substitcher "$@"
EOF

chmod +x $APPDIR/AppRun

echo "Copying dependencies..."
# Copy necessary libraries
mkdir -p $APPDIR/usr/lib

# Copy Flutter engine and other deps
ldd $BUILD_DIR/substitcher | grep "=> /" | awk '{print $3}' | while read lib; do
    if [[ $lib == /lib/* ]] || [[ $lib == /usr/lib/* ]]; then
        continue  # Skip system libraries
    fi
    cp "$lib" $APPDIR/usr/lib/ 2>/dev/null || true
done

echo "Downloading appimagetool..."
if [ ! -f appimagetool-x86_64.AppImage ]; then
    wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

echo "Creating AppImage..."
# Extract and run appimagetool since FUSE isn't available in GitHub Actions
ARCH=x86_64 ./appimagetool-x86_64.AppImage --appimage-extract-and-run $APPDIR $APP_NAME-$APP_VERSION-x86_64.AppImage

echo "AppImage created: $APP_NAME-$APP_VERSION-x86_64.AppImage"
ls -lh $APP_NAME-$APP_VERSION-x86_64.AppImage