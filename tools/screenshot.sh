#!/usr/bin/env bash
# ソフトウェアレンダリング（Xvfb + Mesa llvmpipe）でスクリーンショットを撮る。
#   使い方: GODOT=/path/to/godot tools/screenshot.sh <title|select|zukan|stage_id> <出力.png> [--play=秒] [--frames=N]
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
what="$1"; out="$2"; shift 2
export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe
cd "$ROOT/godot"
timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --resolution 1280x720 --path . res://tests/shot.tscn -- "--stage=$what" "--out=$out" "$@" 2>&1 | grep -E "saved|SCRIPT ERROR|ERROR" | grep -v -E "Draco|MeshOptimizer" | head -20
