#!/usr/bin/env bash
# 同じ 指示文で 別々に 作られた 2 つの 実装（A・B）を、ブラウザで 遊べる 形に 書き出す。
# 作り手の 分担を 決める ための、一時的な くらべもの（決まったら この フォルダ・test.yml の 手順・ダッシュボードの リンクを 消す）。
#   使い方: GODOT=/path/to/godot tools/compare/build.sh <出力フォルダ>   →  <出力>/a/ と <出力>/b/
#   合格: 「COMPARE BUILD: OK」が 出る こと。
# A ＝ 出発点の コミット（BASE）に impl_a.patch を あてた もの。B ＝ コミット B_REF の まま。
# どちらも「カルテ形式の 土台と 1〜3 話（第 1 段階）」の 結果で、出発点と 指示文は 同じ。
# 書き出した index.html には しるし（A・B の ふだ、題）を 足し、セーブを ほかの 版と 分ける
# （同じ サイトに 置いた Godot の Web 版は、どれも 同じ 入れ物 /userfs に セーブを 書く ため）。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
BASE=5003b74cdb5f854d722a7693b044c4b23e1a6a97
B_REF=fae53c8f86ae2606cad3c912c970f7f15e61bab1
OUT="${1:?出力フォルダを 書く}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "COMPARE BUILD: FAILED（$1）"; exit 1; }

mkdir -p "$WORK/a" "$WORK/b"
git -C "$ROOT" archive "$BASE" | tar -x -C "$WORK/a" || fail "出発点の コミットが 取れない（履歴を 全部 取って いるか）"
(cd "$WORK/a" && git apply "$ROOT/tools/compare/impl_a.patch") || fail "impl_a.patch が あたらない"
git -C "$ROOT" archive "$B_REF" | tar -x -C "$WORK/b" || fail "B の コミットが 取れない"

for s in a b; do
  mkdir -p "$OUT/$s"
  (
    cd "$WORK/$s/godot" || exit 1
    # ヘッドレスの Godot は まれに 終わらない ことが ある（CI で 40 分 止まった）。時間を 切る
    timeout 300 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
    timeout 300 "$GODOT" --headless --path . --export-release "Web" "$OUT/$s/index.html" 2>&1 \
      | grep -E "ERROR|WARNING" | grep -v -E "Draco|MeshOptimizer" | head -10
  )
  for f in index.html index.js index.wasm index.pck; do
    [ -s "$OUT/$s/$f" ] || fail "$s の $f が できて いない"
  done
  python3 - "$OUT/$s/index.html" "$s" <<'PY' || fail "$s の index.html に しるしを 足せない"
import sys
path, side = sys.argv[1], sys.argv[2]
name = side.upper()
html = open(path, encoding="utf-8").read()
head = """<script>
/* くらべる ための 版：セーブを ほかの 版と 分ける */
(function () {
  var tag = "compare-%s:";
  var open = IDBFactory.prototype.open;
  IDBFactory.prototype.open = function (name, version) {
    return version === undefined ? open.call(this, tag + name) : open.call(this, tag + name, version);
  };
  /* タブの 題に A・B を 出す（ゲームが 題を 書きかえても 付けなおす） */
  var mark = "%s ｜ ";
  var fix = function () { if (document.title.indexOf(mark) !== 0) document.title = mark + document.title; };
  document.addEventListener("DOMContentLoaded", function () {
    fix();
    new MutationObserver(fix).observe(document.querySelector("title"), { childList: true, characterData: true, subtree: true });
  });
})();
</script>
<style>
#compare-badge { position: fixed; left: 50%%; bottom: 6px; transform: translateX(-50%%); z-index: 10; pointer-events: none;
  font: 800 15px/1 sans-serif; color: #3a3340; background: rgba(255, 255, 255, .82); border: 2px solid #3a3340; border-radius: 999px; padding: 5px 14px; }
</style>
""" % (side, name)
badge = '<div id="compare-badge">くらべる 版 %s</div>\n' % name
assert "</head>" in html and "<body>" in html
html = html.replace("</head>", head + "</head>", 1).replace("<body>", "<body>\n" + badge, 1)
open(path, "w", encoding="utf-8").write(html)
PY
done
echo "COMPARE BUILD: OK（$(du -sh "$OUT" | cut -f1)。$OUT/a と $OUT/b）"
