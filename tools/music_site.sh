#!/usr/bin/env bash
# ダッシュボードの「おとを きく」用に、ゲームの 音楽を 1 つの フォルダへ 写す（CI が _site/music に 出す）。
#   使い方: tools/music_site.sh <出力フォルダ>
# OGG（ループ bgm_*・短い jingle_*）と clear.wav を そのまま 写し、ffmpeg が あれば MP3 も 作る
# （Vorbis を 鳴らせない ブラウザ用。ffmpeg が 無くても ページは OGG で 動く）。
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?出力フォルダ}"
mkdir -p "$OUT"
cp "$ROOT"/godot/assets/audio/bgm_*.ogg "$ROOT"/godot/assets/audio/jingle_*.ogg "$ROOT"/godot/assets/audio/clear.wav "$OUT"/
if command -v ffmpeg >/dev/null 2>&1; then
  for f in "$OUT"/*.ogg "$OUT"/clear.wav; do
    ffmpeg -loglevel error -y -i "$f" -codec:a libmp3lame -q:a 4 "${f%.*}.mp3" || echo "MP3 に できなかった：$f"
  done
  echo "MUSIC SITE: OK（OGG と MP3。$(du -sh "$OUT" | cut -f1)）"
else
  echo "MUSIC SITE: OK（ffmpeg が ないので OGG だけ）"
fi
