#!/usr/bin/env bash
# ものしりカードの 3D の 絵を キャラクターの GLB ぜんぶ について ならべた 1 枚（Xvfb + Mesa）。
#   使い方: GODOT=/path/to/godot tools/card_sheet.sh <出力.png> [--angles=-50,0,50] [--still] [--size=260x300]
#   くわしい 説明は godot/tests/card_sheet.gd の 先頭。
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
out="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; shift
export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe
cd "$ROOT/godot"
timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --resolution 1280x720 --path . res://tests/card_sheet.tscn -- "--out=$out" "$@" 2>&1 | grep -E "saved|SCRIPT ERROR|ERROR" | grep -v -E "Draco|MeshOptimizer" | head -40
