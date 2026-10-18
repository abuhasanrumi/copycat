#!/bin/zsh
# Builds Copycat.app (universal: Apple silicon + Intel). Usage: ./build.sh [run]
set -e
cd "$(dirname "$0")"
swift build -c release --arch arm64 --arch x86_64
APP=Copycat.app
rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp .build/apple/Products/Release/Copycat $APP/Contents/MacOS/
cp Info.plist $APP/Contents/Info.plist
cp Resources/AppIcon.icns $APP/Contents/Resources/
codesign --force --deep --sign - $APP
echo "Built $PWD/$APP"
if [[ "$1" == "run" ]]; then
  pkill -x Copycat 2>/dev/null || true
  open $APP
fi
