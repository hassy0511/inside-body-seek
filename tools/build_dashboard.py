#!/usr/bin/env python3
"""ブックマーク用のダッシュボード（GitHub Pages：https://hassy0511.github.io/inside-body-seek/）を 1 枚の HTML で作る。

元にするもの：docs/dashboard.md の 1〜4・7 章、godot/src/autoload/stage_db.gd、テストのログ（あれば）。
    python3 tools/build_dashboard.py --html _site/index.html --test-log /tmp/inside-body-seek-test.log
main に push されると GitHub Actions（.github/workflows/test.yml）がテストのあとに作りなおし、gh-pages ブランチへ出す。
"""
import argparse
import base64
import datetime
import html
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAGES_URL = "https://hassy0511.github.io/inside-body-seek/"
REPO_URL = "https://github.com/hassy0511/inside-body-seek"


# ---------------------------------------------------------------- 読み取り
def sections(md: str) -> dict:
    """「## 1. 題」ごとに本文を分ける。キーは番号。"""
    out = {}
    for m in re.finditer(r"^## (\d+)\. .*?$(.*?)(?=^## |\Z)", md, re.M | re.S):
        out[int(m.group(1))] = m.group(2)
    return out


def clean(cell: str) -> str:
    return cell.replace("**", "").replace("`", "").strip()


def first_table(text: str) -> list:
    """本文の最初の表を行の辞書の配列にする。"""
    rows = []
    for l in text.splitlines():
        if l.startswith("|"):
            rows.append(l)
        elif rows:
            break
    if len(rows) < 2:
        return []
    split = lambda l: [clean(c) for c in l.strip().strip("|").split("|")]
    head = split(rows[0])
    return [dict(zip(head, split(r))) for r in rows[2:]]


def prompts(text: str) -> list:
    return [{"題": m.group(1).strip(), "文": m.group(2).strip()}
            for m in re.finditer(r"^### (.+?)\n+```text\n(.*?)```", text, re.M | re.S)]


def stages(gd: str, test_log: str) -> list:
    cleared = {m.group(1): float(m.group(2))
               for m in re.finditer(r"cleared (\w+) in ([\d.]+)s \(sim\)", test_log)}
    kinds = {"arena": "ひろば", "tube": "くだ", "rooms": "へや"}
    out = []
    # 1 ステージ = 「"id": ...」から次の「"id":」まで
    for b in re.split(r'\n\t\t"id": ', gd)[1:]:
        g = lambda key: re.search(r'"%s": "?([^",]*)"?' % key, '"id": ' + b).group(1)
        missions = []
        for m in re.finditer(r'\{"type": "\w+"(.*?)"text": "([^"]*)"\}', b.split('"intro"')[0]):
            n = re.search(r'"count": (\d+)', m.group(1))
            missions.append(m.group(2) + ("（%s）" % n.group(1) if n else ""))
        sid = g("id")
        test = "—"
        if test_log:
            test = "OK（%.0f 秒）" % cleared[sid] if sid in cleared else "クリアできず"
        out.append({
            "順": int(g("order")), "ステージ": "%s（%s）" % (g("name"), g("kanji")), "題": g("title"),
            "形": kinds.get(g("kind"), g("kind")), "むずかしさ": "★" * int(g("difficulty")),
            "ミッション": " → ".join(missions), "自動テスト": test,
        })
    return sorted(out, key=lambda s: s["順"])


def git_rev() -> str:
    try:
        return subprocess.check_output(["git", "-C", str(ROOT), "log", "-1", "--format=%h"], text=True).strip()
    except Exception:
        return ""


# ---------------------------------------------------------------- 書き出し
STATUS_COLS = {"状態", "出した日", "確認", "自動テスト"}
NARROW_HIDE = {"内容", "題", "形", "ミッション", "納品", "組み込み"}


def tone(v: str) -> str:
    if re.match(r"^(済|OK)", v):
        return "ok"
    if re.search(r"クリアできず|失敗", v):
        return "bad"
    if "いま" in v:
        return "now"
    if re.match(r"^(未|仮|—|第\d弾|納品待ち)", v):
        return "muted"
    return "plain"


def table(rows: list, cols: list) -> str:
    e = html.escape
    head = "".join('<th%s>%s</th>' % (' class="wide"' if c in NARROW_HIDE else "", e(c)) for c in cols)
    body = []
    for r in rows:
        tds = []
        for c in cols:
            v = str(r.get(c, ""))
            cls = ' class="wide"' if c in NARROW_HIDE else (' class="num"' if c == "順" else "")
            if c in STATUS_COLS and v and v != "—":
                v_html = '<span class="chip %s%s">%s</span>' % (tone(v), " short" if len(v) <= 12 else "", e(v))
            else:
                v_html = e(v)
            tds.append("<td%s>%s</td>" % (cls, v_html))
        body.append("<tr>%s</tr>" % "".join(tds))
    return '<div class="scroll"><table><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>' % (head, "".join(body))


def render(data: dict, updated: str, rev: str, tested: bool, lineup: str) -> str:
    e = html.escape
    st = data["stages"]
    ok = sum(1 for s in st if s["自動テスト"].startswith("OK"))
    test_line = ("自動テスト：<b class=\"%s\">%d / %d</b> ステージがクリアまで通る" % ("ok" if ok == len(st) else "bad", ok, len(st))
                 if tested else "自動テスト：まだ結果がありません")
    todo = data["todo"]
    now = next((t for t in todo if "いま" in t.get("状態", "")), todo[0])
    cards = "".join(
        '<article class="card prompt"><div class="prompt-head"><h3>%s</h3>'
        '<button type="button" class="copy" data-i="%d">コピー</button></div><pre id="p%d">%s</pre></article>'
        % (e(p["題"]), i, i, e(p["文"])) for i, p in enumerate(data["prompts"]))
    rev_html = ' ／ <a href="%s/commit/%s">%s</a>' % (REPO_URL, e(rev), e(rev)) if rev else ""
    return TEMPLATE.format(
        updated=e(updated), rev=rev_html, test_line=test_line,
        now_what=e(now["やること"]), now_who=e(now["だれ"]),
        todo=table(todo, ["やること", "だれ", "状態"]),
        prompts=cards,
        phases=table(data["phases"], ["段階", "内容", "状態"]),
        lineup=lineup,
        art=table(data["art"], ["波", "発注書", "出した日", "納品", "確認", "組み込み"]),
        stages=table(st, ["順", "ステージ", "題", "形", "むずかしさ", "ミッション", "自動テスト"]),
        models=table(data["models"], ["種類", "ID（GLB 名）", "状態", "発注書"]),
        repo=REPO_URL,
    )


TEMPLATE = """<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>だいぼうけん 開発ダッシュボード</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=M+PLUS+Rounded+1c:wght@500;800&display=swap">
<style>
/* 1 列：いま やること → 依頼文 → 段階と画風 → 発注 → ステージ → モデル。色はゲームの A-model の色見本から */
:root {{
  --bg: #fff8f6; --panel: #ffffff; --line: #f0d9da; --fg: #3a3340; --muted: #7b6f7c;
  --floor: #f2a0a4; --wall: #d87983; --yellow: #f2c744; --pico: #83d4da;
  --ok: #217a68; --now: #8a5a00; --now-bg: #fdf0c4; --bad: #b3261e;
  --round: "M PLUS Rounded 1c", "Hiragino Maru Gothic ProN", "Hiragino Sans", "Noto Sans JP", sans-serif;
  --sans: "Hiragino Sans", "Noto Sans JP", "Yu Gothic UI", "Meiryo", system-ui, sans-serif;
  color-scheme: light;
}}
@media (prefers-color-scheme: dark) {{
  :root {{
    --bg: #1f1a22; --panel: #2a2430; --line: #43394a; --fg: #f3edf2; --muted: #b3a7b5;
    --floor: #b9636c; --wall: #8e4a57; --yellow: #f2c744; --pico: #83d4da;
    --ok: #7fd8c0; --now: #ffd977; --now-bg: #4a3b12; --bad: #ff8a80;
    color-scheme: dark;
  }}
}}
* {{ box-sizing: border-box; }}
body {{ margin: 0; background: var(--bg); color: var(--fg); font-family: var(--sans); font-size: 15px; line-height: 1.6; }}
.wrap {{ max-width: 72rem; margin: 0 auto; padding: 1.5rem max(16px, env(safe-area-inset-right)) 3rem max(16px, env(safe-area-inset-left)); display: grid; gap: 2rem; }}
header {{ display: grid; gap: .5rem; padding-bottom: 1.25rem; border-bottom: 3px solid var(--floor); }}
h1 {{ margin: 0; font-family: var(--round); font-weight: 800; font-size: clamp(1.6rem, 4vw, 2.3rem); line-height: 1.25; text-wrap: balance; }}
h1 small {{ display: block; font-size: .9rem; font-weight: 500; color: var(--muted); letter-spacing: .04em; }}
.now {{ margin: .25rem 0 0; padding: .75rem 1rem; background: var(--now-bg); color: var(--fg); border-radius: 12px; display: flex; gap: .75rem; align-items: baseline; flex-wrap: wrap; }}
.now b {{ font-family: var(--round); color: var(--now); white-space: nowrap; }}
.meta {{ margin: 0; color: var(--muted); font-size: .85rem; font-variant-numeric: tabular-nums; }}
.meta b.ok {{ color: var(--ok); }} .meta b.bad {{ color: var(--bad); }}
a {{ color: inherit; }}
section {{ display: grid; gap: .75rem; min-width: 0; }}
h2 {{ margin: 0; font-family: var(--round); font-weight: 800; font-size: 1.25rem; display: flex; align-items: center; gap: .5rem; }}
h2::before {{ content: ""; width: .7rem; height: .7rem; border-radius: 50%; background: var(--wall); flex: none; }}
.note {{ margin: 0; color: var(--muted); font-size: .85rem; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 20rem), 1fr)); gap: 1rem; }}
.card {{ background: var(--panel); border: 1px solid var(--line); border-radius: 14px; padding: 1rem 1.1rem; min-width: 0; display: grid; gap: .6rem; align-content: start; }}
.card h3 {{ margin: 0; font-size: 1rem; font-family: var(--round); font-weight: 800; }}
.scroll {{ overflow-x: auto; }}
table {{ width: 100%; border-collapse: collapse; }}
th {{ text-align: left; font-size: .78rem; color: var(--muted); font-weight: 600; padding: .35rem .6rem; border-bottom: 1px solid var(--line); white-space: nowrap; }}
td {{ padding: .55rem .6rem; border-bottom: 1px solid var(--line); vertical-align: top; }}
tr:last-child td {{ border-bottom: 0; }}
td.num {{ color: var(--muted); font-variant-numeric: tabular-nums; }}
.chip {{ display: inline-block; padding: 0 .6em; border-radius: .9em; border: 1px solid currentColor; font-size: .8rem; line-height: 1.75; }}
.chip.short {{ white-space: nowrap; }}
.chip.ok {{ color: var(--ok); }}
.chip.now {{ color: var(--now); background: var(--now-bg); border-color: transparent; font-weight: 700; }}
.chip.bad {{ color: var(--bad); }}
.chip.muted {{ color: var(--muted); border-style: dashed; }}
.chip.plain {{ color: var(--fg); border-color: var(--line); }}
.prompts {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 19rem), 1fr)); gap: 1rem; }}
.prompt-head {{ display: flex; justify-content: space-between; align-items: center; gap: .5rem; flex-wrap: wrap; }}
pre {{ margin: 0; white-space: pre-wrap; overflow-wrap: anywhere; max-height: 12em; overflow: auto; font-family: var(--sans); font-size: .8rem; line-height: 1.6; background: var(--bg); border: 1px solid var(--line); border-radius: 10px; padding: .6rem .7rem; }}
button.copy {{ font: inherit; font-family: var(--round); font-weight: 800; font-size: .85rem; color: #3a3340; background: var(--yellow); border: 0; border-radius: 999px; padding: .35rem 1rem; cursor: pointer; }}
button.copy:hover {{ filter: brightness(1.05); }}
button.copy:focus-visible {{ outline: 2px solid var(--fg); outline-offset: 2px; }}
button.copy.done {{ background: var(--pico); }}
figure {{ margin: 0; display: grid; gap: .4rem; }}
figure img {{ width: 100%; height: auto; border-radius: 10px; display: block; }}
figcaption {{ color: var(--muted); font-size: .8rem; }}
footer {{ color: var(--muted); font-size: .8rem; border-top: 1px solid var(--line); padding-top: 1rem; }}
@media (max-width: 40rem) {{ .wide {{ display: none; }} }}
</style>
</head>
<body>
<div class="wrap">
<header>
  <h1><small>開発ダッシュボード</small>からだのなか だいぼうけん</h1>
  <p class="now"><b>いま やること（{now_who}）</b><span>{now_what}</span></p>
  <p class="meta">{test_line} ／ 更新 {updated}{rev}</p>
</header>

<section id="todo">
  <h2>いま やること</h2>
  <div class="card">{todo}</div>
</section>

<section id="prompts">
  <h2>Codex に出す依頼文</h2>
  <p class="note">「コピー」を押して、そのまま Codex に貼ります。3 本は同時に出してかまいません。</p>
  <div class="prompts">{prompts}</div>
</section>

<section id="overview">
  <h2>全体の段階と画風</h2>
  <div class="grid">
    <div class="card"><h3>全体の段階</h3>{phases}</div>
    <div class="card"><h3>えらんだ画風：A-model</h3>
      <figure><img alt="A-model のキャラクターの並び図" src="{lineup}">
      <figcaption>A 案（やわらかい絵本、輪郭線なし）を、少ない丸い部品で 3D にしやすくした形。左から ミクロごう・パイロット・ピコ・はなちゃん・むしばきん・ウイルス・赤血球・白血球（W0 の見本。正確な形は第2弾で決まる）。</figcaption></figure>
    </div>
  </div>
</section>

<section id="art">
  <h2>絵の発注と納品</h2>
  <div class="card">{art}</div>
</section>

<section id="stages">
  <h2>ステージ（10）</h2>
  <p class="note">自動テストの秒数は、自動操縦がクリアまでにかかったゲームの中の時間。子どもが遊ぶと 1 ステージ 3〜6 分の想定。</p>
  <div class="card">{stages}</div>
</section>

<section id="models">
  <h2>3D モデル</h2>
  <p class="note">いまは全部 仮（スクリプトで作った形）。納品された絵から作りなおして、同じ名前の GLB で差しかえる。</p>
  <div class="card">{models}</div>
</section>

<footer>main に push されるたびに GitHub Actions がテストを回して、このページを作りなおします。元の文書：<a href="{repo}/blob/main/docs/dashboard.md">docs/dashboard.md</a></footer>
</div>
<script>
document.querySelectorAll("button.copy").forEach(function (btn) {{
  btn.addEventListener("click", function () {{
    var pre = document.getElementById("p" + btn.dataset.i);
    var done = function () {{
      btn.textContent = "コピーしました"; btn.classList.add("done");
      setTimeout(function () {{ btn.textContent = "コピー"; btn.classList.remove("done"); }}, 1800);
    }};
    var selectIt = function () {{
      var r = document.createRange(); r.selectNodeContents(pre);
      var s = window.getSelection(); s.removeAllRanges(); s.addRange(r);
      btn.textContent = "選びました。コピーしてください";
    }};
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(pre.textContent).then(done, selectIt);
    else selectIt();
  }});
}});
</script>
</body>
</html>
"""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--html", required=True, help="書き出す HTML のパス")
    ap.add_argument("--test-log", default="", help="tools/run_tests.sh の LOG（無ければ自動テストの列は —）")
    a = ap.parse_args()
    md = (ROOT / "docs/dashboard.md").read_text(encoding="utf-8")
    gd = (ROOT / "godot/src/autoload/stage_db.gd").read_text(encoding="utf-8")
    log_path = pathlib.Path(a.test_log) if a.test_log else None
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path and log_path.is_file() else ""
    sec = sections(md)
    data = {
        "phases": first_table(sec[1]),
        "todo": first_table(sec[2]),
        "art": first_table(sec[3]),
        "models": first_table(sec[4]),
        "stages": stages(gd, log),
        "prompts": prompts(sec[7]),
    }
    for name, rows in data.items():
        assert rows, "%s が空（dashboard.md の章の形を確かめる）" % name
    lineup = "data:image/jpeg;base64," + base64.b64encode((ROOT / "tools/dashboard_lineup.jpg").read_bytes()).decode()
    jst = datetime.timezone(datetime.timedelta(hours=9))
    updated = datetime.datetime.now(jst).strftime("%Y-%m-%d %H:%M")
    out = pathlib.Path(a.html)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render(data, updated, git_rev(), bool(log), lineup), encoding="utf-8")
    print("wrote %s（%s）" % (out, ", ".join("%s %d" % (k, len(v)) for k, v in data.items())))


if __name__ == "__main__":
    main()
