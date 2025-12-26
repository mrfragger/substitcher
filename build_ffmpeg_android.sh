#!/bin/bash

set -e

echo "Building LGPL FFmpeg for Android..."

ANDROID_NDK="$HOME/Library/Android/sdk/ndk/27.0.12077973"
if [ ! -d "$ANDROID_NDK" ]; then
  echo "Android NDK not found at $ANDROID_NDK"
  exit 1
fi

SCRIPT_DIR="$PWD"
CACHE_DIR="$HOME/.cache/ffmpeg-build-android"
SOURCE_DIR="$CACHE_DIR/ffmpeg-8.0.1"
API_LEVEL=21

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
  local ANDROID_ARCH=$2
  local CPU=$3
  
  echo ""
  echo "Building for $ARCH..."
  
  cd "$SOURCE_DIR"
  make distclean 2>/dev/null || true
  
  local BUILD_DIR="$CACHE_DIR/build-$ARCH"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  
  local TOOLCHAIN="$ANDROID_NDK/toolchains/llvm/prebuilt/darwin-x86_64"
  
  export PATH="$TOOLCHAIN/bin:$PATH"
  export CC="$TOOLCHAIN/bin/${ANDROID_ARCH}${API_LEVEL}-clang"
  export CXX="$TOOLCHAIN/bin/${ANDROID_ARCH}${API_LEVEL}-clang++"
  export AR="$TOOLCHAIN/bin/llvm-ar"
  export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
  export STRIP="$TOOLCHAIN/bin/llvm-strip"
  export NM="$TOOLCHAIN/bin/llvm-nm"
  
  ./configure \
    --prefix="$BUILD_DIR" \
    --enable-static \
    --disable-shared \
    --disable-gpl \
    --disable-nonfree \
    --disable-doc \
    --disable-debug \
    --disable-everything \
    --disable-autodetect \
    --disable-asm \
    --disable-inline-asm \
    --disable-x86asm \
    --disable-armv5te \
    --disable-armv6 \
    --disable-armv6t2 \
    --disable-neon \
    --enable-cross-compile \
    --target-os=android \
    --arch=$ARCH \
    --cpu=$CPU \
    --cc="$CC" \
    --cxx="$CXX" \
    --ar="$AR" \
    --ranlib="$RANLIB" \
    --strip="$STRIP" \
    --nm="$NM" \
    --enable-ffmpeg \
    --enable-ffprobe \
    --enable-decoder=opus,aac,aac_fixed,aac_latm,mp3,mp3float,pcm_s16le,pcm_s24le,pcm_f32le,flac,vorbis,alac \
    --enable-encoder=opus,aac,pcm_s16le \
    --enable-demuxer=opus,ogg,matroska,wav,mp3,aac,m4a,mov,flac \
    --enable-muxer=opus,ogg,matroska,wav,ipod,mp4 \
    --enable-parser=opus,aac,aac_latm,mp3,flac,vorbis \
    --enable-protocol=file \
    --enable-filter=volume,equalizer,highpass,lowpass,aformat,aresample,atempo
  
  make -j$(sysctl -n hw.ncpu)
  make install
  
  local DEST_DIR="$SCRIPT_DIR/android/app/src/main/jniLibs/$ARCH"
  mkdir -p "$DEST_DIR"
  cp "$BUILD_DIR/bin/ffmpeg" "$DEST_DIR/"
  cp "$BUILD_DIR/bin/ffprobe" "$DEST_DIR/"
  chmod +x "$DEST_DIR/ffmpeg"
  chmod +x "$DEST_DIR/ffprobe"
  
  $STRIP "$DEST_DIR/ffmpeg"
  $STRIP "$DEST_DIR/ffprobe"
  
  echo "Built for $ARCH - binaries at $DEST_DIR"
  ls -lh "$DEST_DIR"
}

build_arch "arm64-v8a" "aarch64-linux-android" "armv8-a"
build_arch "armeabi-v7a" "armv7a-linux-androideabi" "armv7-a"

echo ""
echo "✓ Done! FFmpeg binaries built for Android"
echo "Binaries location: android/app/src/main/jniLibs/"