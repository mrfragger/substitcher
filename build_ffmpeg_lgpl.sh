#!/bin/bash

set -e

echo "Building minimal LGPL FFmpeg 8.0.1 for macOS (Universal Binary)..."

SCRIPT_DIR="$PWD"
CACHE_DIR="$HOME/.cache/ffmpeg-build"
SOURCE_DIR="$CACHE_DIR/ffmpeg-8.0.1"

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

build_arch() {
  local ARCH=$1
  
  echo "Building for $ARCH..."
  
  cd "$SOURCE_DIR"
  make distclean 2>/dev/null || true
  
  local BUILD_DIR="$CACHE_DIR/build-$ARCH"
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
    --enable-filter=volume,equalizer,highpass,lowpass,aformat,aresample,atempo \
    --arch=$ARCH \
    --cc="clang -arch $ARCH"
  
  make -j$(sysctl -n hw.ncpu)
  make install
  
  strip "$BUILD_DIR/bin/ffmpeg"
  strip "$BUILD_DIR/bin/ffprobe"
}

build_arch "x86_64"
build_arch "arm64"

echo "Creating universal binaries..."
mkdir -p "$SCRIPT_DIR/macos/Runner/Resources/bin"

lipo -create \
  "$CACHE_DIR/build-x86_64/bin/ffmpeg" \
  "$CACHE_DIR/build-arm64/bin/ffmpeg" \
  -output "$SCRIPT_DIR/macos/Runner/Resources/bin/ffmpeg"

lipo -create \
  "$CACHE_DIR/build-x86_64/bin/ffprobe" \
  "$CACHE_DIR/build-arm64/bin/ffprobe" \
  -output "$SCRIPT_DIR/macos/Runner/Resources/bin/ffprobe"

chmod +x "$SCRIPT_DIR/macos/Runner/Resources/bin/ffmpeg"
chmod +x "$SCRIPT_DIR/macos/Runner/Resources/bin/ffprobe"

echo ""
echo "✓ Done! Universal LGPL FFmpeg 8.0.1 built successfully!"
echo "Location: macos/Runner/Resources/bin/"
echo ""
echo "Binary sizes:"
ls -lh "$SCRIPT_DIR/macos/Runner/Resources/bin/"
echo ""
echo "Architectures:"
lipo -info "$SCRIPT_DIR/macos/Runner/Resources/bin/ffmpeg"
lipo -info "$SCRIPT_DIR/macos/Runner/Resources/bin/ffprobe"