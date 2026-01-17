#!/bin/bash
set -e

APP_ID="com.substitcher.SubStitcher"
VERSION=$(git describe --tags --always)

flutter pub get
flutter build linux --release

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