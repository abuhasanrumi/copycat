#!/bin/zsh
# Builds dist/Copycat-<version>.dmg containing the app and an Applications shortcut.
set -e
cd "$(dirname "$0")"
./build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
STAGE=$(mktemp -d)
mkdir -p dist
cp -R Copycat.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/READ ME FIRST.txt" <<TXT
Install: drag Copycat into Applications, then open it.

This build is not notarized by Apple, so the first time macOS may say it
"can't be opened". Fix: right-click Copycat in Applications → Open → Open.
If it still refuses, run this once in Terminal:

    xattr -dr com.apple.quarantine /Applications/Copycat.app

Then press Shift-Command-V anywhere to open your clipboard history.
TXT
DMG="dist/Copycat-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Copycat" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
echo "Created $PWD/$DMG"
