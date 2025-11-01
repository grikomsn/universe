#!/usr/bin/env bash

if [[ "$(uname -o)" != "Darwin" ]]; then
  echo "This script is intended for macOS only." >&2
  exit 1
fi

sudo -v
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

FONT_IMAGES=(
  "SF-Pro.dmg"
  "SF-Compact.dmg"
  "SF-Mono.dmg"
  # "NY.dmg"
)

cd ~/Downloads
for FONT_IMAGE in "${FONT_IMAGES[@]}"; do
  wget https://devimages-cdn.apple.com/design/resources/download/$FONT_IMAGE
done

for FONT_IMAGE in "${FONT_IMAGES[@]}"; do
  hdiutil attach $FONT_IMAGE
done

FONT_PKG_PATHS=(
  # '/Volumes/NYFonts/NY Fonts.pkg'
  '/Volumes/SFCompactFonts/SF Compact Fonts.pkg'
  '/Volumes/SFMonoFonts/SF Mono Fonts.pkg'
  '/Volumes/SFProFonts/SF Pro Fonts.pkg'
)
for FONT_PKG_PATH in "${FONT_PKG_PATHS[@]}"; do
  sudo installer -pkg "$FONT_PKG_PATH" -target /Library/Fonts
done
