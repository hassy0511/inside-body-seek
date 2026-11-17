#!/usr/bin/env python3
"""ブックマーク用のダッシュボード（GitHub Pages：https://hassy0511.github.io/inside-body-seek/）を 1 枚の HTML で作る。

元にするもの：docs/dashboard.md の 1〜4・6・7 章、docs/story.md（5 章の 表は 予定の 話数にも 使う）、godot/src/autoload/episode_db.gd（カルテ）と stage_db.gd（場所）、テストのログ（あれば）。
    python3 tools/build_dashboard.py --html _site/index.html --test-log /tmp/inside-body-seek-test.log
main に push されると GitHub Actions（.github/workflows/test.yml）がテストのあとに作りなおし、gh-pages ブランチへ出す。
"""
import argparse
import base64
import datetime
import html
import os
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


def planned_episodes(story: str) -> list:
    """docs/story.md の「## 5. カルテ一覧」の 表から、予定の 話（番号と 題）を 読む。"""
    m = re.search(r"^## 5\. .*?$(.*?)(?=^## |\Z)", story, re.M | re.S)
    out = []
    for l in (m.group(1) if m else "").splitlines():
        c = [clean(x) for x in l.strip().strip("|").split("|")]
        no = re.match(r"\d+", c[0]) if l.startswith("|") and len(c) > 1 else None   # 「1（実装ずみ）」の ような 書きかたも ある
        if no:
            out.append({"話": int(no.group()), "だいめい": c[1]})
    return out


def records(text: str, n: int = 4) -> list:
    """6 章（記録）の 新しい ほうから n 件。"""
    return [clean(l[2:]) for l in text.splitlines() if re.match(r"- \d{4}-", l)][:n]


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


def episodes(ep_gd: str, gd: str, test_log: str) -> list:
    """godot/src/autoload/episode_db.gd から カルテの 表を 作る（書きかたの きまりは その ファイルの 先頭）。"""
    cleared = {m.group(1): float(m.group(2))
               for m in re.finditer(r"cleared (\w+) in ([\d.]+)s \(sim\)", test_log)}
    patients = dict(re.findall(r'"(\w+)": \{"name": "([^"]+)"', ep_gd))
    pattern_names = dict(re.findall(r'"([A-Z])": \{"name": "([^"]+)"', ep_gd))   # PATTERNS（げんいんの タイプ）
    place_names = {m.group(1): "%s（%s）" % (m.group(2), m.group(3))
                   for m in re.finditer(r'"id": "(\w+)", "order": \d+, "name": "([^"]+)", "kanji": "([^"]+)"', gd)}
    body = ep_gd.split("const EPISODES", 1)[1].split("\n]\n", 1)[0]
    out = []
    # 1 話 = 2 タブの「"id": …」から 次の「"id":」まで。場面の 場所は 4 タブの「"place": "…",」
    for b in re.split(r'\n\t\t"id": ', body)[1:]:
        b = '"id": ' + b
        g = lambda key: re.search(r'"%s": "?([^",]*)"?' % key, b).group(1)
        places = re.findall(r'\n\t\t\t\t"place": "(\w+)"', b)
        eid = g("id")
        test = "—"
        if test_log:
            test = "OK（%.0f 秒）" % cleared[eid] if eid in cleared else "クリアできず"
        out.append({
            "話": int(g("no")), "だいめい": g("title"), "患者": patients.get(g("patient"), g("patient")),
            "場所": " → ".join(place_names.get(p, p) for p in places),
            "パターン": " ＋ ".join(("%s %s" % (k, pattern_names.get(k, ""))).strip() for k in g("pattern").split("・")),
            "むずかしさ": "★" * int(g("difficulty")), "自動テスト": test,
        })
    return sorted(out, key=lambda e: e["話"])


def inline(t: str) -> str:
    t = html.escape(t)
    t = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", t)
    return re.sub(r"`(.+?)`", r"<code>\1</code>", t)


def md_html(md: str) -> str:
    """docs/story.md 用の小さな Markdown（## 見出し・段落・箇条書き・引用・表・太字・コード）。"""
    out, lines, i = [], md.splitlines(), 0
    is_list = lambda l: re.match(r"(\d+\.|-) ", l)
    while i < len(lines):
        l = lines[i]
        if not l.strip() or l.startswith("# "):
            i += 1
            continue
        if l.startswith("## "):
            out.append("<h3>%s</h3>" % inline(l[3:]))
            i += 1
            continue
        block = []
        if l.startswith("|"):
            while i < len(lines) and lines[i].startswith("|"):
                block.append([inline(c.strip()) for c in lines[i].strip().strip("|").split("|")])
                i += 1
            head = "".join("<th>%s</th>" % c for c in block[0])
            body = "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % c for c in r) for r in block[2:])
            out.append('<div class="scroll"><table><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>' % (head, body))
        elif l.startswith(">"):
            while i < len(lines) and lines[i].startswith(">"):
                block.append(lines[i][1:].strip())
                i += 1
            cls = "status" if block[0].startswith("状態") else "game"
            out.append('<blockquote class="%s">%s</blockquote>' % (cls, "<br>".join(inline(b) for b in block)))
        elif is_list(l):
            tag = "ol" if l[0].isdigit() else "ul"
            while i < len(lines) and is_list(lines[i]):
                block.append(re.sub(r"^(\d+\.|-) ", "", lines[i]))
                i += 1
            out.append("<%s>%s</%s>" % (tag, "".join("<li>%s</li>" % inline(b) for b in block), tag))
        else:
            while i < len(lines) and lines[i].strip() and not re.match(r"(#|>|\|)", lines[i]) and not is_list(lines[i]):
                block.append(lines[i])
                i += 1
            out.append("<p>%s</p>" % inline(" ".join(block)))
    return "\n".join(out)


def git_rev() -> str:
    try:
        return subprocess.check_output(["git", "-C", str(ROOT), "log", "-1", "--format=%h"], text=True).strip()
    except Exception:
        return ""


# ---------------------------------------------------------------- 書き出し
STATUS_COLS = {"状態", "出した日", "確認", "自動テスト"}
NARROW_HIDE = {"内容", "題", "形", "ミッション", "納品", "組み込み", "パターン", "場所"}


def tone(v: str) -> str:
    if re.match(r"^(済|OK)", v):
        return "ok"
    if re.search(r"クリアできず|失敗", v):
        return "bad"
    if "いま" in v:
        return "now"
    if re.match(r"^(未|仮|—|第\d弾|納品待ち|確認待ち)", v):
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
            cls = ' class="wide"' if c in NARROW_HIDE else (' class="num"' if c in ("順", "話") else "")
            if c in STATUS_COLS and v and v != "—":
                v_html = '<span class="chip %s%s">%s</span>' % (tone(v), " short" if len(v) <= 12 else "", e(v))
            else:
                v_html = e(v)
            tds.append("<td%s>%s</td>" % (cls, v_html))
        body.append("<tr>%s</tr>" % "".join(tds))
    return '<div class="scroll"><table><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>' % (head, "".join(body))


def art_state(r: dict) -> str:
    """3 章の 1 行（発注書）を 5 つの 状態に 分ける。"""
    if r.get("納品", "—") != "—":
        return "確認ずみ" if r.get("確認", "").startswith("済") else "納品ずみ"
    sent = r.get("出した日", "")
    if sent.startswith("済"):
        return "納品待ち"
    return "いま 出せる" if "いま" in sent else "あとで"


def model_state(r: dict) -> str:
    """4 章の 1 行（モデルの 種類）を 5 つの 状態に 分ける。"""
    v = r.get("状態", "")
    if v.startswith("本番"):
        return "本番"
    if "本番" in v:
        return "一部 本番"
    if v.startswith("まだ"):
        return "まだ 無い"
    return "絵が 届いた" if "届いた" in v else "仮"


ART_MARK = {"確認ずみ": ("済", "done"), "納品ずみ": ("届", "now"), "納品待ち": ("待", "now"), "いま 出せる": ("今", "now"), "あとで": ("後", "")}


def progress(data: dict, tested: bool) -> str:
    """ページの 先頭の「進みぐあい」。数は 元の 表と データから 数える（手で 書かない）。
    状態は 色だけで なく、ます目の 中の 字（済・今 など）でも 分かる ように する。"""
    e = html.escape
    eps = {x["話"]: x for x in data["episodes"]}
    plan = data["planned"] or [{"話": n, "だいめい": x["だいめい"]} for n, x in sorted(eps.items())]
    segs = []
    for pl in plan:
        ep = eps.get(pl["話"])
        failed = bool(ep) and tested and not ep["自動テスト"].startswith("OK")
        cls, mark, word = ("bad", "×", "テストで 止まる") if failed else (("done", "済", "できた") if ep else ("", "・", "これから"))
        segs.append('<li class="seg %s" title="%d 話 %s：%s"><b>%d</b><span>%s</span></li>'
                    % (cls, pl["話"], e((ep or pl)["だいめい"]), word, pl["話"], mark))
    ep_card = ('<div class="card prog"><h3>カルテ（話）</h3><p class="big"><b>%d</b> / %d 話が 遊べる</p><ol class="segs">%s</ol>'
               '<p class="note">済 ＝ 作って あり、最後まで 遊べる。・ ＝ これから。</p></div>' % (len(eps), len(plan), "".join(segs)))

    arts = [(r, art_state(r)) for r in data["art"]]
    count = lambda rows, key: sum(1 for _, st in rows if st == key)
    asegs = "".join('<li class="seg %s" title="%s：%s"><b>%s</b><span>%s</span></li>'
                    % (ART_MARK[st][1], e(r.get("発注書", "")), st, e(r.get("波", "")), ART_MARK[st][0]) for r, st in arts)
    rest = "、".join("%s %d" % (k, count(arts, k)) for k in ["納品ずみ", "納品待ち", "いま 出せる", "あとで"] if count(arts, k))
    art_card = ('<div class="card prog"><h3>絵の 発注（Codex）</h3><p class="big"><b>%d</b> / %d 本が 納品・確認ずみ</p><ol class="segs">%s</ol>'
                '<p class="note">%s。済 ＝ 確認ずみ、今 ＝ いま 出せる、後 ＝ あとで 出す。</p></div>'
                % (count(arts, "確認ずみ"), len(arts), asegs, e(rest) if rest else "のこりは ありません"))

    models = [(r, model_state(r)) for r in data["models"]]
    mlist = "".join("<li><span>%s</span><b>%d</b></li>" % (k, count(models, k))
                    for k in ["本番", "一部 本番", "絵が 届いた", "仮", "まだ 無い"] if count(models, k))
    model_card = ('<div class="card prog"><h3>3D モデルと 絵</h3><p class="big"><b>%d</b> / %d 種類が 本番</p><ul class="tally">%s</ul>'
                  '<p class="note">いまは ほとんどが 仮の 見た目。届いた 絵から 作りなおして 差しかえる。</p></div>'
                  % (count(models, "本番"), len(models), mlist))

    st = data["stages"]
    ok_ep = sum(1 for x in data["episodes"] if x["自動テスト"].startswith("OK"))
    ok_st = sum(1 for x in st if x["自動テスト"].startswith("OK"))
    if tested:
        all_ok = ok_ep == len(eps) and ok_st == len(st)
        test_big = '<p class="big"><b class="%s">%s</b></p>' % ("ok" if all_ok else "bad", "ぜんぶ 通る" if all_ok else "止まる ものが ある")
        test_list = '<ul class="tally"><li><span>カルテ</span><b>%d / %d</b></li><li><span>場所</span><b>%d / %d</b></li></ul>' % (ok_ep, len(eps), ok_st, len(st))
    else:
        test_big, test_list = '<p class="big"><b>—</b></p>', '<p class="note">まだ 結果が ありません。</p>'
    test_card = ('<div class="card prog"><h3>自動テスト</h3>%s%s<p class="note">自動操縦が、そうだんから カルテまで 遊びとおせるかを 毎回 確かめる。場所は %d か所。</p></div>'
                 % (test_big, test_list, len(st)))

    phases = "".join('<li><b>%s</b><span class="chip %s">%s</span></li>'
                     % (e(r.get("段階", "")), tone(r.get("状態", "")), e(re.split(r"[（。]", r.get("状態", ""))[0]))
                     for r in data["phases"])
    recs = "".join("<li>%s</li>" % e(x) for x in data["records"])
    return ('<section id="progress"><h2>進みぐあい</h2><div class="progs">%s%s%s%s</div>'
            '<div class="grid"><div class="card"><h3>段階ごと</h3><ul class="phases">%s</ul></div>'
            '<div class="card"><h3>さいきんの 記録</h3><ul class="recs">%s</ul></div></div></section>'
            % (ep_card, art_card, model_card, test_card, phases, recs))


def render(data: dict, story: str, updated: str, rev: str, tested: bool, lineup: str, play: str = "",
           compare: str = "", compare_page: str = "") -> str:
    e = html.escape
    st = data["stages"]
    eps = data["episodes"]
    ok = sum(1 for s in st if s["自動テスト"].startswith("OK"))
    ep_ok = sum(1 for x in eps if x["自動テスト"].startswith("OK"))
    test_line = ("自動テスト：カルテ <b class=\"%s\">%d / %d</b>、場所 <b class=\"%s\">%d / %d</b> がクリアまで通る"
                 % ("ok" if ep_ok == len(eps) else "bad", ep_ok, len(eps), "ok" if ok == len(st) else "bad", ok, len(st))
                 if tested else "自動テスト：まだ結果がありません")
    todo = data["todo"]
    nows = [t for t in todo if "いま" in t.get("状態", "")] or todo[:1]
    now_html = "".join('<p class="now"><b>いま やること（%s）</b><span>%s</span></p>' % (e(t["だれ"]), e(t["やること"])) for t in nows)
    m = re.search(r"状態：\*\*(.+?)\*\*", story)
    story_state = m.group(1) if m else "案"
    cards = "".join(
        '<article class="card prompt"><div class="prompt-head"><h3>%s</h3>'
        '<button type="button" class="copy" data-i="%d">コピー</button></div><pre id="p%d">%s</pre></article>'
        % (e(p["題"]), i, i, e(p["文"])) for i, p in enumerate(data["prompts"]))
    rev_html = ' ／ <a href="%s/commit/%s">%s</a>' % (REPO_URL, e(rev), e(rev)) if rev else ""
    # ブラウザで 遊べる 版（play は このページから 見た 相対パス。書き出して いない ときは 出さない）
    play_html = ('<p class="play"><a class="playbtn" href="%s">▶ ブラウザで あそんで たしかめる</a>'
                 '<span>いまの main の ゲームが そのまま 動きます（絵と 3D モデルは 仮）。キーボード：やじるしキーで うごく・スペースで 決定と アクション。'
                 'スマホ・タブレットは よこむきで、画面の ボタンで 操作。さいしょの 読みこみは 50 MB ほど。</span></p>' % e(play)) if play else ""
    # くらべもの（一時的）：同じ 指示文で 別々に 作られた 2 つの 実装。compare は このページから 見た 相対パス
    compare_html = ""
    if compare:
        page = (' <a class="cmpbtn" href="%s" target="_blank" rel="noopener">ならべて 見る ページ</a>' % e(compare_page)) if compare_page else ""
        compare_html = ('<p class="play cmp"><b>A と B を くらべる</b>'
                        '<a class="cmpbtn" href="%sa/" target="_blank" rel="noopener">A を あそぶ</a>'
                        '<a class="cmpbtn" href="%sb/" target="_blank" rel="noopener">B を あそぶ</a>%s'
                        '<span>同じ 指示文で 別々に 作られた 2 つの 実装（カルテ形式の 土台と 1〜3 話、第 1 段階の 結果）。'
                        '画面の 下に「くらべる 版 A／B」の ふだが 出ます。セーブは A・B・いまの 版で 別々。'
                        '上の「あそんで たしかめる」は いまの ゲームで、くらべる 対象では ありません。</span></p>'
                        % (e(compare), e(compare), page))
    return TEMPLATE.format(
        updated=e(updated), rev=rev_html, test_line=test_line,
        now=now_html, play=play_html + compare_html, progress=progress(data, tested),
        story=md_html(story), story_state=e(story_state), story_tone="now" if "待ち" in story_state else "ok",
        todo=table(todo, ["やること", "だれ", "状態"]),
        prompts=cards,
        phases=table(data["phases"], ["段階", "内容", "状態"]),
        lineup=lineup,
        art=table(data["art"], ["波", "発注書", "出した日", "納品", "確認", "組み込み"]),
        episodes=table(eps, ["話", "だいめい", "患者", "場所", "パターン", "むずかしさ", "自動テスト"]),
        episode_count=len(eps), stage_count=len(st),
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
.play {{ margin: .25rem 0 0; display: flex; gap: .6rem 1rem; align-items: center; flex-wrap: wrap; }}
.play span {{ flex: 1 1 18rem; color: var(--muted); font-size: .85rem; }}
a.playbtn {{ flex: none; font-family: var(--round); font-weight: 800; font-size: 1.1rem; color: #3a3340; background: var(--yellow); text-decoration: none; border-radius: 999px; padding: .6rem 1.4rem; }}
a.playbtn:hover {{ filter: brightness(1.05); }}
.play.cmp b {{ font-family: var(--round); }}
a.cmpbtn {{ flex: none; font-family: var(--round); font-weight: 800; color: var(--fg); background: var(--panel); border: 2px solid var(--wall); text-decoration: none; border-radius: 999px; padding: .35rem 1rem; }}
a.cmpbtn:hover {{ border-color: var(--fg); }}
a.cmpbtn:focus-visible {{ outline: 2px solid var(--fg); outline-offset: 2px; }}
a.playbtn:focus-visible {{ outline: 2px solid var(--fg); outline-offset: 2px; }}
.progs {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 16rem), 1fr)); gap: 1rem; }}
.prog .big {{ margin: 0; font-family: var(--round); font-weight: 500; }}
.prog .big b {{ font-size: 1.9rem; font-weight: 800; line-height: 1.2; font-variant-numeric: tabular-nums; }}
.prog .big b.ok {{ color: var(--ok); font-size: 1.4rem; }} .prog .big b.bad {{ color: var(--bad); font-size: 1.4rem; }}
.segs {{ list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(auto-fill, minmax(1.9rem, 1fr)); gap: 3px; }}
.seg {{ display: grid; justify-items: center; padding: .2rem 0; border-radius: 6px; border: 1.5px dashed var(--line); color: var(--muted); font-size: .72rem; line-height: 1.35; }}
.seg b {{ font-size: .82rem; color: var(--fg); font-variant-numeric: tabular-nums; }}
.seg.done {{ border: 1.5px solid var(--ok); background: color-mix(in srgb, var(--ok) 14%, var(--panel)); color: var(--fg); }}
.seg.now {{ border: 1.5px solid transparent; background: var(--now-bg); color: var(--fg); }}
.seg.bad {{ border: 1.5px solid var(--bad); color: var(--fg); }}
ul.tally, ul.phases, ul.recs {{ list-style: none; margin: 0; padding: 0; display: grid; gap: .3rem; }}
ul.tally li, ul.phases li {{ display: flex; justify-content: space-between; align-items: baseline; gap: .75rem; border-bottom: 1px solid var(--line); padding-bottom: .25rem; }}
ul.tally li:last-child, ul.phases li:last-child {{ border-bottom: 0; }}
ul.tally b {{ font-variant-numeric: tabular-nums; }}
ul.phases b {{ font-family: var(--round); white-space: nowrap; }}
ul.recs {{ gap: .6rem; font-size: .92rem; }}
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
nav {{ display: flex; flex-wrap: wrap; gap: .4rem; margin-top: .25rem; }}
nav a {{ text-decoration: none; font-size: .8rem; padding: .15rem .7rem; border: 1px solid var(--line); border-radius: 999px; background: var(--panel); }}
nav a:hover {{ border-color: var(--wall); }}
.now + .now {{ margin-top: 0; }}
.story {{ gap: .8rem; }}
.story h3 {{ margin: .6rem 0 0; font-size: 1.05rem; }}
.story h3:first-of-type {{ margin-top: 0; }}
.story p, .story ul, .story ol {{ margin: 0; max-width: 48rem; }}
.story ul, .story ol {{ padding-left: 1.4rem; display: grid; gap: .3rem; }}
.story code {{ font-size: .85em; background: var(--bg); border: 1px solid var(--line); border-radius: 4px; padding: 0 .3em; }}
.story td {{ font-size: .9rem; }}
blockquote {{ margin: 0; max-width: 48rem; }}
blockquote.game {{ font-family: var(--round); font-weight: 500; font-size: 1.02rem; line-height: 1.9; padding: .8rem 1.1rem; background: var(--bg); border: 2px solid var(--floor); border-radius: 16px; }}
blockquote.status {{ color: var(--muted); font-size: .85rem; }}
footer {{ color: var(--muted); font-size: .8rem; border-top: 1px solid var(--line); padding-top: 1rem; }}
@media (max-width: 40rem) {{ .wide {{ display: none; }} }}
</style>
</head>
<body>
<div class="wrap">
<header>
  <h1><small>開発ダッシュボード</small>からだのなか だいぼうけん</h1>
  {play}
  {now}
  <p class="meta">{test_line} ／ 更新 {updated}{rev}</p>
  <nav><a href="#progress">進みぐあい</a><a href="#todo">いま やること</a><a href="#story">ストーリー案</a><a href="#prompts">依頼文</a><a href="#overview">段階と画風</a><a href="#art">絵の発注</a><a href="#episodes">カルテ</a><a href="#stages">場所</a><a href="#models">3D モデル</a></nav>
</header>

{progress}

<section id="todo">
  <h2>いま やること</h2>
  <div class="card">{todo}</div>
</section>

<section id="story">
  <h2>ストーリー案 <span class="chip {story_tone}">{story_state}</span></h2>
  <div class="card story">{story}</div>
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

<section id="episodes">
  <h2>カルテ（{episode_count} 話まで実装）</h2>
  <p class="note">1 話 = そうだん → よそう → 場所を 1〜3 こ めぐる → カルテ。秒数は、自動操縦が そうだんから カルテまでに かかった ゲームの中の時間。子どもが遊ぶと 1 話 10〜15 分の想定。</p>
  <div class="card">{episodes}</div>
</section>

<section id="stages">
  <h2>場所（{stage_count}）</h2>
  <p class="note">カルテが めぐる 場所（臓器）。ミッションは 場所の 既定で、カルテの 場面が 上書きする。自動テストは 場所だけを 既定の ミッションで 通した 結果。</p>
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
    ap.add_argument("--compare-dir", default="", help="tools/compare/build.sh の 出力フォルダ（a/ と b/ が あれば「A と B を くらべる」を 出す。一時的）")
    ap.add_argument("--play-dir", default="", help="tools/export_web.sh の 出力フォルダ（index.html が あれば「あそんで たしかめる」の ボタンを 出す）")
    a = ap.parse_args()
    md = (ROOT / "docs/dashboard.md").read_text(encoding="utf-8")
    gd = (ROOT / "godot/src/autoload/stage_db.gd").read_text(encoding="utf-8")
    ep_gd = (ROOT / "godot/src/autoload/episode_db.gd").read_text(encoding="utf-8")
    log_path = pathlib.Path(a.test_log) if a.test_log else None
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path and log_path.is_file() else ""
    story = (ROOT / "docs/story.md").read_text(encoding="utf-8")
    sec = sections(md)
    data = {
        "phases": first_table(sec[1]),
        "todo": first_table(sec[2]),
        "art": first_table(sec[3]),
        "models": first_table(sec[4]),
        "stages": stages(gd, log),
        "episodes": episodes(ep_gd, gd, log),
        "prompts": prompts(sec[7]),
    }
    # 進みぐあい用（空でも ページは 作れる）
    planned, recent = planned_episodes(story), records(sec.get(6, ""))
    for name, rows in data.items():
        assert rows, "%s が空（dashboard.md の章の形を確かめる）" % name
    data["planned"], data["records"] = planned, recent
    lineup = "data:image/jpeg;base64," + base64.b64encode((ROOT / "tools/dashboard_lineup.jpg").read_bytes()).decode()
    jst = datetime.timezone(datetime.timedelta(hours=9))
    updated = datetime.datetime.now(jst).strftime("%Y-%m-%d %H:%M")
    out = pathlib.Path(a.html)
    out.parent.mkdir(parents=True, exist_ok=True)
    play = ""
    if a.play_dir and (pathlib.Path(a.play_dir) / "index.html").is_file():
        play = os.path.relpath(pathlib.Path(a.play_dir).resolve(), out.parent.resolve()).replace(os.sep, "/") + "/"
    compare = compare_page = ""
    cdir = pathlib.Path(a.compare_dir) if a.compare_dir else None
    if cdir and (cdir / "a/index.html").is_file() and (cdir / "b/index.html").is_file():
        compare = os.path.relpath(cdir.resolve(), out.parent.resolve()).replace(os.sep, "/") + "/"
        url_file = ROOT / "tools/compare/page_url.txt"   # ならべて 見る ページの URL（あれば リンクを 出す）
        compare_page = url_file.read_text(encoding="utf-8").strip() if url_file.is_file() else ""
    out.write_text(render(data, story, updated, git_rev(), bool(log), lineup, play, compare, compare_page), encoding="utf-8")
    print("wrote %s（%s）" % (out, ", ".join("%s %d" % (k, len(v)) for k, v in data.items())))


if __name__ == "__main__":
    main()
