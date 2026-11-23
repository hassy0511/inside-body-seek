#!/usr/bin/env bash
# モデル 1 体を 決まった 向きから 撮る（Xvfb + Mesa。絵と ならべて 見る ため）。
#   使い方: GODOT=/path/to/godot tools/pod_views.sh <出力フォルダ> [id（既定 pod）] [--light=studio|game|dark|flat|shadow] [--only=front,game] [--hide=Window]
#           GODOT=/path/to/godot tools/pod_views.sh <出力フォルダ> pod --stage=mouth [--play=秒]     本物の 場所で、HUD を かくして 撮る
#   向きの 一覧と くわしい 説明は godot/tests/pod_views.gd の 先頭。絵と ならべた 1 枚は tools/pod_compare.py で 作る。
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
mkdir -p "$1"
out="$(cd "$1" && pwd)/"; id="${2:-pod}"; shift; [ $# -gt 0 ] && shift
export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe
cd "$ROOT/godot"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --resolution 1280x720 --path . res://tests/pod_views.tscn -- "--model=$id" "--out=$out" "$@" 2>&1 | grep -E "saved|SCRIPT ERROR|ERROR" | grep -v -E "Draco|MeshOptimizer" | head -40
