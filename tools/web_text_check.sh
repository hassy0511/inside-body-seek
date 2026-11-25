#!/usr/bin/env bash
# ブラウザ版と テスト（エディタの Godot）で、画面の 文が 同じ 行で 折れるかを くらべる。
#   使い方: GODOT=/path/to/godot tools/web_text_check.sh [--setting=off] [--keep=<フォルダ>]
#   合格: さいごの 行が「WEB TEXT: OK（N 画面、M 文）」。ちがいは「ちがい: …」に 画面・文・両方の 行を 書く。
# なぜ：テストは 文が 箱に 入るかを エディタの Godot で はかる。ブラウザ版は 書き出しの 設定
#   （project.godot の internationalization/locale/include_text_server_data）が 無いと 行の 折りかたの データを 持たず、
#   空白でしか 折れない。はかった 行と 画面の 行が ずれて、文が はみ出す。
# やる こと：
#   1. エディタの Godot（ヘッドレス）で godot/tests/web_text.tscn を 動かす（1〜3 話の 画面と HUD の 文を めぐり、行を 出す）
#   2. godot/ の 写しを 作り、写しだけ 変えて ブラウザ版に 書き出す：はじめの 画面を web_text.tscn に、
#      Web の 書き出しで tests/ を 入れる。ふつうの 書き出し（tools/export_web.sh）と 本物の 設定は さわらない
#   3. 写しを http で 出し、Chromium（tools/web_text_browser.js）で 同じ めぐりを 動かす
#   4. tools/web_text_compare.py が 2 つを くらべる
# --setting=off：写しで その 設定を 切って 書き出す（道具が ちがいを 見つけられるかの たしかめ。FAILED に なるのが 正しい）
# --keep=<フォルダ>：2 つの ログ（native.log・web.log）と くらべた 結果（result.txt）を のこす
# 要る もの：Godot 4.7 と Web の テンプレート（tools/export_web.sh と 同じ）、python3、node と playwright の Chromium。
# 書き出しは XDG_DATA_HOME を 外して 動かす（テンプレートを その 下で さがす ため）。1 の めぐりは 外から 来た XDG_DATA_HOME の まま。
# 時間：エディタ 1〜2 分、書き出し 1〜2 分、ブラウザ 数分（ソフトウェア描画）。
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
SETTING=on
KEEP=""
for a in "$@"; do
  case "$a" in
    --setting=off) SETTING=off ;;
    --keep=*) KEEP="${a#--keep=}" ;;
    *) echo "使い方: tools/web_text_check.sh [--setting=off] [--keep=<フォルダ>]"; exit 2 ;;
  esac
done
WORK="$(mktemp -d)"
SERVER_PID=""
cleanup() {
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT
fail() { echo "WEB TEXT: FAILED（$1）"; exit 1; }
start=$(date +%s)

echo "== エディタの Godot =="
(
  cd "$ROOT/godot" || exit 1
  timeout 600 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
  timeout 900 "$GODOT" --headless --path . res://tests/web_text.tscn >"$WORK/native.log" 2>&1
) || true
grep -q '^WEBTEXT {"end"' "$WORK/native.log" || { grep -E "SCRIPT ERROR|ERROR" "$WORK/native.log" | head -10; fail "エディタの めぐりが さいごまで 行かない"; }
echo "  $(grep -c '^WEBTEXT' "$WORK/native.log") 行（$(( $(date +%s) - start )) 秒）"

echo "== ブラウザ版に 書き出す（写しで。設定 $SETTING）=="
mkdir -p "$WORK/proj" "$WORK/web"
# export/ は 前の 書き出し（大きい）。.godot/ は インポートずみの もの（写すと 速い）
tar -C "$ROOT/godot" --exclude=./export -cf - . | tar -C "$WORK/proj" -xf - || fail "godot/ を 写せない"
python3 - "$WORK/proj" "$SETTING" <<'PY' || fail "写しの 設定を 書きかえられない"
import re, sys
proj, setting = sys.argv[1], sys.argv[2]
p = proj + "/project.godot"
s = open(p, encoding="utf-8").read()
s, n = re.subn(r'^run/main_scene=.*$', 'run/main_scene="res://tests/web_text.tscn"', s, flags=re.M)
assert n == 1, "main_scene が 無い"
key = "locale/include_text_server_data="
if key in s:
    s = re.sub(r'^locale/include_text_server_data=.*$', key + ("true" if setting == "on" else "false"), s, flags=re.M)
elif setting == "on":
    s += "\n[internationalization]\n\n" + key + "true\n"
open(p, "w", encoding="utf-8").write(s)
e = proj + "/export_presets.cfg"
s = open(e, encoding="utf-8").read()
# Web の 書き出しで tests/ を 入れる（ふつうは 入れない）
m = re.search(r'(\[preset\.\d+\]\s*\n\s*name="Web".*?)exclude_filter="[^"]*"', s, flags=re.S)
assert m, "Web の 書き出しの 設定が 無い"
s = s[:m.start()] + m.group(1) + 'exclude_filter=""' + s[m.end():]
open(e, "w", encoding="utf-8").write(s)
PY
(
  unset XDG_DATA_HOME
  cd "$WORK/proj" || exit 1
  timeout 600 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
  timeout 600 "$GODOT" --headless --path . --export-release "Web" "$WORK/web/index.html" 2>&1 \
    | grep -E "ERROR|WARNING" | grep -v -E "Draco|MeshOptimizer" | head -10
)
for f in index.html index.js index.wasm index.pck; do
  [ -s "$WORK/web/$f" ] || fail "書き出しで $f が できない（テンプレートが 入って いるか）"
done
echo "  pck $(du -h "$WORK/web/index.pck" | cut -f1)（$(( $(date +%s) - start )) 秒）"

echo "== ブラウザ =="
PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$WORK/web" >/dev/null 2>&1 &
SERVER_PID=$!
for i in $(seq 1 50); do
  python3 -c "import urllib.request,sys; urllib.request.urlopen('http://127.0.0.1:$PORT/index.html')" 2>/dev/null && break
  sleep 0.2
done
node "$ROOT/tools/web_text_browser.js" "http://127.0.0.1:$PORT/index.html" "$WORK/web.log" 1800 \
  || echo "  ブラウザの めぐりが さいごまで 行かない（くらべる ところまでは 見る）"
echo "  $(grep -c '^WEBTEXT' "$WORK/web.log") 行（$(( $(date +%s) - start )) 秒）"

echo "== くらべる =="
python3 "$ROOT/tools/web_text_compare.py" "$WORK/native.log" "$WORK/web.log" >"$WORK/result.txt"
code=$?
grep -v "^WEB TEXT:" "$WORK/result.txt"
if [ -n "$KEEP" ]; then
  mkdir -p "$KEEP"
  cp "$WORK/native.log" "$WORK/web.log" "$WORK/result.txt" "$KEEP/"
fi
echo "  かかった 時間 $(( $(date +%s) - start )) 秒"
grep "^WEB TEXT:" "$WORK/result.txt" || echo "WEB TEXT: FAILED（くらべる 道具が 結果を 出さない）"
exit $code
