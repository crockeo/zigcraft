#!/usr/bin/env bash

set -e

shaderc="./dependencies/bgfx/.build/osx-x64/bin/shadercRelease"

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
