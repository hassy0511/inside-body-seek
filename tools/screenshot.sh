#!/usr/bin/env bash
# ソフトウェアレンダリング（Xvfb + Mesa llvmpipe）でスクリーンショットを撮る。
#   使い方: GODOT=/path/to/godot tools/screenshot.sh <なにを> <出力.png> [--play=秒] [--frames=N] [--touch]
#   <なにを> ＝ title / select_new / select / resume / opening / consult:ep03 / guess:ep03 / guess_wrong:ep01 / guess_go:ep01 /
#               after:ep03:0 / karte:ep03[:1〜3] / review:ep02[:1〜2] / zukan / zukan_karte:ep02 / ep03:1 / card / pause /
#               model:pod / 場所の id（mouth など）
#   「,」で ならべると 1 回の 起動で 何枚も 撮る（<出力> は フォルダ）：tools/screenshot.sh consult:ep01,consult:ep01+p1 /tmp/shots/
#   しるし（+p1、+hit、+wrong、+hurt、+touch）と くわしい 説明は godot/tests/shot.gd の 先頭。
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
what="$1"; out="$2"; shift 2
export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe
cd "$ROOT/godot"
timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --resolution 1280x720 --path . res://tests/shot.tscn -- "--stage=$what" "--out=$out" "$@" 2>&1 | grep -E "saved|SCRIPT ERROR|ERROR" | grep -v -E "Draco|MeshOptimizer" | head -80
