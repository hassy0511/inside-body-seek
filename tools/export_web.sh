#!/usr/bin/env bash
# ブラウザで 遊べる 版（Web）を 書き出す。CI が GitHub Pages の play/ に 出す（ダッシュボードの「あそんで たしかめる」）。
#   使い方: GODOT=/path/to/godot tools/export_web.sh [出力フォルダ（既定 godot/export/web）]
#   合格: 「WEB EXPORT: OK」が 出る こと。
# 要る もの: 書き出し用の テンプレート web_nothreads_release.zip が
#   ~/.local/share/godot/export_templates/4.7.stable/ に ある こと（入れかたは .github/workflows/test.yml の 手順と 同じ）。
# 手元で 見る: cd <出力フォルダ> && python3 -m http.server 8000 → ブラウザで http://localhost:8000/
#   （file:// で 開いても 動かない。かならず http で 出す）
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="${1:-$ROOT/godot/export/web}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
cd "$ROOT/godot"
# まだ インポートして いない とき用（run_tests.sh の あとなら すぐ 終わる）
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html" 2>&1 \
  | grep -E "ERROR|WARNING" | grep -v -E "Draco|MeshOptimizer" | head -20
for f in index.html index.js index.wasm index.pck; do
  if [ ! -s "$OUT/$f" ]; then
    echo "WEB EXPORT: FAILED（$f が できて いない。テンプレートが 入って いるか 確かめる）"
    exit 1
  fi
done
echo "WEB EXPORT: OK（$(du -sh "$OUT" | cut -f1)。$OUT）"
