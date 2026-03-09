#!/bin/bash
set -e

APP_ID="com.substitcher.SubStitcher"
VERSION=$(git describe --tags --always)

flutter pub get
flutter build linux --release

mkdir -p build/linux/x64/release/bundle/bin
mkdir -p build/linux/x64/release/bundle/whisper
mkdir -p build/linux/x64/release/bundle/llama

if [ -d "temp-bin" ]; then
    cp temp-bin/* build/linux/x64/release/bundle/bin/
    chmod +x build/linux/x64/release/bundle/bin/*
fi

if [ -d "temp-whisper" ]; then
    cp temp-whisper/* build/linux/x64/release/bundle/whisper/
    chmod +x build/linux/x64/release/bundle/whisper/whisper-cli
fi

if [ -d "temp-llama" ]; then
    cp temp-llama/* build/linux/x64/release/bundle/llama/
    chmod +x build/linux/x64/release/bundle/llama/llama-server
fi

cat > $APP_ID.yml << EOF
app-id: $APP_ID
runtime: org.freedesktop.Platform
runtime-version: '24.08'
sdk: org.freedesktop.Sdk
command: substitcher
finish-args:
  - --share=ipc
  - --socket=x11
  - --socket=pulseaudio
  - --device=dri
  - --filesystem=home
  - --filesystem=/tmp

modules:
  - name: substitcher
    buildsystem: simple
    build-commands:
      - install -Dm755 substitcher /app/bin/substitcher
      - cp -r lib /app/bin/lib
      - cp -r data /app/bin/data
      - mkdir -p /app/bin/bin /app/bin/whisper /app/bin/llama
      - cp bin/* /app/bin/bin/ && chmod +x /app/bin/bin/*
      - cp whisper/* /app/bin/whisper/ && chmod +x /app/bin/whisper/whisper-cli
      - cp llama/* /app/bin/llama/ && chmod +x /app/bin/llama/llama-server
      - install -Dm644 $APP_ID.desktop /app/share/applications/$APP_ID.desktop
    sources:
      - type: dir
        path: build/linux/x64/release/bundle
EOF

cat > $APP_ID.desktop << EOF
[Desktop Entry]
Name=SubStitcher
Comment=Audiobook Player with Subtitles
Exec=substitcher
Icon=audio-player
Type=Application
Categories=AudioVideo;Audio;Player;
EOF

cp $APP_ID.desktop build/linux/x64/release/bundle/

flatpak-builder --force-clean build-dir $APP_ID.yml
flatpak build-export repo build-dir
flatpak build-bundle repo substitcher-x64.flatpak $APP_ID

echo "Flatpak built: substitcher-x64.flatpak"