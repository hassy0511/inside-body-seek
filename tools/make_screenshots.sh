#!/usr/bin/env bash
# README 用のスクリーンショットを docs/screenshots/ にまとめて撮る（Xvfb + Mesa が必要）。
#   使い方: GODOT=/path/to/godot tools/make_screenshots.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots"
mkdir -p "$OUT"
for w in title select card result zukan; do
  "$ROOT/tools/screenshot.sh" "$w" "$OUT/$w.png" --frames=40
done
for s in mouth esophagus stomach intestine vessel heart lungs brain nose; do
  "$ROOT/tools/screenshot.sh" "$s" "$OUT/stage_$s.png" --frames=30 --play=1.5
done
ls -la "$OUT"
