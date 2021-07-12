#!/usr/bin/env bash

set -e

bin_dir="./dependencies/bgfx/.build/osx-x64/bin"
shaderc="$bin_dir/shadercRelease"
texturec="$bin_dir/texturecRelease"

$shaderc \
    -i dependencies/bgfx/src \
    -f shaders/vertex.sc \
    -o shaders/vertex.bin \
    --type vertex \
    --platform osx \
    --profile metal \
    --verbose

$shaderc \
    -i dependencies/bgfx/src \
    -f shaders/fragment.sc \
    -o shaders/fragment.bin \
    --type fragment \
    --platform osx \
    --profile metal \
    --verbose

for file in $(ls res/*.png); do
    ktx_file=$(echo $file | sed "s/png/ktx/")
    $texturec \
	-f "$file" \
	-o "$ktx_file"
done
