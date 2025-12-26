#!/bin/bash

set -e

echo "Building FFmpeg 8.0.1 with libopus for macOS (Universal Binary)..."

SCRIPT_DIR="$PWD"
CACHE_DIR="$HOME/.cache/ffmpeg-build"
SOURCE_DIR="$CACHE_DIR/ffmpeg-8.0.1"
OPUS_SOURCE_DIR="$CACHE_DIR/opus-1.5.2"

mkdir -p "$CACHE_DIR"

if [ ! -f "$CACHE_DIR/ffmpeg-8.0.1.tar.xz" ]; then
  echo "Downloading FFmpeg 8.0.1 source..."
  curl -L https://ffmpeg.org/releases/ffmpeg-8.0.1.tar.xz -o "$CACHE_DIR/ffmpeg-8.0.1.tar.xz"
else
  echo "Using cached FFmpeg source"
fi

if [ ! -f "$CACHE_DIR/opus-1.5.2.tar.gz" ]; then
  echo "Downloading libopus 1.5.2 source..."
  curl -L https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz -o "$CACHE_DIR/opus-1.5.2.tar.gz"
else
  echo "Using cached libopus source"
fi

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Extracting FFmpeg source..."
  cd "$CACHE_DIR"
  tar xf ffmpeg-8.0.1.tar.xz
fi

if [ ! -d "$OPUS_SOURCE_DIR" ]; then
  echo "Extracting libopus source..."
  cd "$CACHE_DIR"
  tar xf opus-1.5.2.tar.gz
fi

build_arch() {
  local ARCH=$1
  
  echo "Building libopus for $ARCH..."
  
  cd "$OPUS_SOURCE_DIR"
  make distclean 2>/dev/null || true
  
  local OPUS_BUILD_DIR="$CACHE_DIR/opus-build-$ARCH"
  rm -rf "$OPUS_BUILD_DIR"
  mkdir -p "$OPUS_BUILD_DIR"
  
  export CFLAGS="-arch $ARCH -O3"
  export LDFLAGS="-arch $ARCH"
  
  ./configure \
    --prefix="$OPUS_BUILD_DIR" \
    --disable-shared \
    --enable-static \
    --disable-doc \
    --disable-extra-programs
  
  make -j$(sysctl -n hw.ncpu)
  make install
  
  echo "Building FFmpeg for $ARCH..."
  
  cd "$SOURCE_DIR"
  make distclean 2>/dev/null || true
  
  local BUILD_DIR="$CACHE_DIR/build-$ARCH"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  
  export PKG_CONFIG_PATH="$OPUS_BUILD_DIR/lib/pkgconfig"
  
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
    --enable-libopus \
    --enable-decoder=opus,libopus,aac,aac_fixed,aac_latm,mp3,mp3float,pcm_s16le,pcm_s24le,pcm_f32le,flac,vorbis,alac \
    --enable-encoder=libopus,aac,pcm_s16le \
    --enable-demuxer=ffmetadata,concat,opus,ogg,matroska,wav,mp3,aac,m4a,mov,flac \
    --enable-muxer=ffmetadata,opus,ogg,matroska,wav,ipod,mp4 \
    --enable-parser=opus,aac,aac_latm,mp3,flac,vorbis \
    --enable-protocol=file \
    --enable-filter=volume,equalizer,highpass,lowpass,aformat,aresample,atempo,silenceremove,afftdn,dynaudnorm \
    --extra-cflags="-I$OPUS_BUILD_DIR/include" \
    --extra-ldflags="-L$OPUS_BUILD_DIR/lib" \
    --arch=$ARCH \
    --cc="clang -arch $ARCH"
  
  make -j$(sysctl -n hw.ncpu)
  make install
  
  strip "$BUILD_DIR/bin/ffmpeg"
  strip "$BUILD_DIR/bin/ffprobe"
  
  unset PKG_CONFIG_PATH CFLAGS LDFLAGS
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
echo "✓ Done! FFmpeg 8.0.1 with libopus built successfully!"
echo "Location: macos/Runner/Resources/bin/"
echo ""
echo "Binary sizes:"
ls -lh "$SCRIPT_DIR/macos/Runner/Resources/bin/"
echo ""
echo "Architectures:"
lipo -info "$SCRIPT_DIR/macos/Runner/Resources/bin/ffmpeg"
lipo -info "$SCRIPT_DIR/macos/Runner/Resources/bin/ffprobe"