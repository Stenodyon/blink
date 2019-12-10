#!/bin/bash

TMP_DIR=/tmp/blink
SCRIPT_DIR=$PWD

set -e

mkdir -p $TMP_DIR

if [ ! -f "$TMP_DIR/SDL2.zip" ]; then
    wget "https://www.libsdl.org/release/SDL2-2.0.10-win32-x64.zip" -O $TMP_DIR/SDL2.zip
fi
if [ ! -f "$TMP_DIR/SDL2_ttf.zip" ]; then
    wget "https://www.libsdl.org/projects/SDL_ttf/release/SDL2_ttf-2.0.15-win32-x64.zip" -O $TMP_DIR/SDL2_ttf.zip
fi
if [ ! -f "$TMP_DIR/libepoxy.zip" ]; then
    wget "https://github.com/anholt/libepoxy/releases/download/1.5.3/libepoxy-shared-x64.zip" -O $TMP_DIR/libepoxy.zip
fi

unzip -o $TMP_DIR/SDL2.zip -d $TMP_DIR
unzip -o $TMP_DIR/SDL2_ttf.zip -d $TMP_DIR
unzip -oj $TMP_DIR/libepoxy libepoxy-shared-x64/bin/epoxy-0.dll -d $TMP_DIR

mkdir -p $TMP_DIR/Blink_Windows_x64
mkdir -p $TMP_DIR/Blink_Linux_x64

cp blink README.md $TMP_DIR/Blink_Linux_x64/
cp -r data $TMP_DIR/Blink_Linux_x64/

cp blink.exe README.md $TMP_DIR/Blink_Windows_x64/
cp $(find zig-cache/ -name '*.pdb') $TMP_DIR/Blink_Windows_x64/
cp -r data $TMP_DIR/Blink_Windows_x64/
cp $TMP_DIR/*.dll $TMP_DIR/Blink_Windows_x64/

rm -f Blink_Linux_x64.zip $TMP_DIR/Blink_Linux_x64.zip
rm -f Blink_Windows_x64.zip $TMP_DIR/Blink_Windows_x64.zip

cd $TMP_DIR
zip -r Blink_Linux_x64.zip Blink_Linux_x64
zip -r Blink_Windows_x64.zip Blink_Windows_x64

cd $SCRIPT_DIR
cp $TMP_DIR/Blink_Linux_x64.zip .
cp $TMP_DIR/Blink_Windows_x64.zip .
