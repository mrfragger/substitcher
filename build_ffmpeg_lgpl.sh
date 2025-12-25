#!/bin/bash

set -e

echo "Building minimal LGPL FFmpeg 8.0.1 for audiobooks..."

SCRIPT_DIR="$PWD"
CACHE_DIR="$HOME/.cache/ffmpeg-build"
SOURCE_DIR="$CACHE_DIR/ffmpeg-8.0.1"
BUILD_DIR="$CACHE_DIR/build"

mkdir -p "$CACHE_DIR"

if [ ! -f "$CACHE_DIR/ffmpeg-8.0.1.tar.xz" ]; then
  echo "Downloading FFmpeg 8.0.1 source..."
  curl -L https://ffmpeg.org/releases/ffmpeg-8.0.1.tar.xz -o "$CACHE_DIR/ffmpeg-8.0.1.tar.xz"
else
  echo "Using cached FFmpeg source"
fi

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Extracting FFmpeg source..."
  cd "$CACHE_DIR"
  tar xf ffmpeg-8.0.1.tar.xz
fi

cd "$SOURCE_DIR"

echo "Cleaning previous build artifacts..."
make distclean 2>/dev/null || true

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

./configure \
  --prefix="$BUILD_DIR" \
  --disable-shared \
  --enable-static \
  --disable-gpl \
  --disable-nonfree \
  --disable-doc \
  --disable-debug \
  --disable-everything \
  --disable-xlib \
  --disable-libxcb \
  --disable-libxcb-shm \
  --disable-libxcb-xfixes \
  --disable-libxcb-shape \
  --enable-ffmpeg \
  --enable-ffprobe \
  --enable-videotoolbox \
  --enable-audiotoolbox \
  --enable-decoder=opus,aac,aac_fixed,aac_latm,mp3,mp3float,pcm_s16le,pcm_s24le,pcm_f32le,flac,vorbis,alac \
  --enable-encoder=opus,aac,pcm_s16le \
  --enable-demuxer=opus,ogg,matroska,wav,mp3,aac,m4a,mov,flac \
  --enable-muxer=opus,ogg,matroska,wav,ipod,mp4 \
  --enable-parser=opus,aac,aac_latm,mp3,flac,vorbis \
  --enable-protocol=file \
  --enable-filter=volume,equalizer,highpass,lowpass,aformat,aresample,atempo

echo "Building FFmpeg (this may take a few minutes)..."
make -j$(sysctl -n hw.ncpu)
make install

echo "Stripping binaries to reduce size..."
strip "$BUILD_DIR/bin/ffmpeg"
strip "$BUILD_DIR/bin/ffprobe"

echo "Copying binaries to project..."
mkdir -p "$SCRIPT_DIR/macos/Runner/Resources/bin"
cp "$BUILD_DIR/bin/ffmpeg" "$SCRIPT_DIR/macos/Runner/Resources/bin/"
cp "$BUILD_DIR/bin/ffprobe" "$SCRIPT_DIR/macos/Runner/Resources/bin/"
chmod +x "$SCRIPT_DIR/macos/Runner/Resources/bin/ffmpeg"
chmod +x "$SCRIPT_DIR/macos/Runner/Resources/bin/ffprobe"

cd "$SCRIPT_DIR"

echo ""
echo "✓ Done! LGPL FFmpeg 8.0.1 with AAC support built successfully!"
echo "Location: macos/Runner/Resources/bin/"
echo ""
echo "Binary sizes:"
ls -lh "$SCRIPT_DIR/macos/Runner/Resources/bin/" | grep -E "ffmpeg|ffprobe"
echo ""
echo "FFmpeg version:"
./macos/Runner/Resources/bin/ffmpeg -version | head -n 1
echo ""
echo "Configuration (should NOT show --enable-gpl):"
./macos/Runner/Resources/bin/ffmpeg -version | grep configuration
echo ""
echo "Dynamic dependencies (should only be system libraries):"
otool -L ./macos/Runner/Resources/bin/ffmpeg
echo ""
echo "Build cache location: $CACHE_DIR"
echo "To force a rebuild, run: rm -rf $CACHE_DIR"