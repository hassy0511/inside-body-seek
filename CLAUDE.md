# からだのなか だいぼうけん — 開発メモ（Claude 向け）

子ども向け（6〜10 歳）の体のしくみを学ぶ 3D ゲーム。Godot 4.7（GDScript）＋ Blender（bpy スクリプトで GLB 生成）。
企画は `docs/design.md`、使い方・構成は `README.md`。

## 変更するときの約束

- 文章は ひらがな・カタカナ中心。一文字の臓器名は「い（胃）」「は（歯）」「ち（血）」のように漢字を添える。分かち書き（単語の間にスペース）。
- 体の事実は子ども向けに丸めてよいが、間違いは入れない（数値は `docs/design.md` の表に合わせる）。
- ステージの文章・ミッション・カード・クイズはすべて `godot/src/autoload/stage_db.gd`。ステージの形とスポーン位置は `blender/stages.py`（Empty の名前 `MK_...` がスポーン）。
- モデルを変えたら GLB を作り直す：`<venv>/bin/python -m blender.characters <name>` / `-m blender.stages <stage_env>`（`blender -b -P blender/stages.py -- stage_mouth` でも可）。
- 生成した GLB・WAV はコミットする。`godot/.godot/` と `blender/out/` はコミットしない。
- Godot 側のコードは「子どもが詰まらない」を最優先：ゲームオーバーなし、はさまったら戻す、ヒントは上書きしない（`Game.hud_busy()`）。

## ブランチとダッシュボード

- 本線は `main`。Claude はセッションの作業ブランチで直し、テストが通ったら `main` にも push する（fast-forward）。Codex の依頼文も `main` を見る。
- Codex の納品は `art/<波>` ブランチ。`main` には spec の md と「そのまま使う PNG」だけ取り込む（`docs/art_orders/取り込み手順.md`）。
- ブックマーク用のページ（GitHub Pages）：https://hassy0511.github.io/inside-body-seek/ 。main に push すると CI がテストのあと `tools/build_dashboard.py` で `docs/dashboard.md` から作りなおして `gh-pages` に出す。手で更新しない（dashboard.md 8 章）。

## 絵と 3D モデルは Codex に発注する

- アートバイブルは **A-model**（A 案の画風を 3D にしやすくした派生）に決定済み（`docs/art_orders/W0_取り込みの結果.md`）。
- いまの見た目はすべて**仮**。絵やモデルの作り込みを自分で頑張らない。必要な絵は `docs/art_orders/` の発注書にまとめ、`codex_prompts.md` の文をユーザーに渡して Codex に出してもらう。
- 新しいキャラクター・物・ステージを足すときは、**仮モデルを作るのと同時に発注書（または既存の発注書への追記）を書く**。
- 差しかえの約束：GLB の名前（`godot/assets/models/characters/<ID>.glb`、`stages/stage_<id>.glb`）、`BUILDERS` の関数名、Godot が探す部品名（`Propeller`、`Window`）、当たり判定の `CONFIG` は変えない。UI・カードの挿絵は `res://assets/ui/...png` があれば自動で使う（`T.art()`。一覧は `docs/dashboard.md` 4 章）。
- 納品の取り込みは `docs/art_orders/取り込み手順.md`、3D 化は `.claude/skills/model-from-art/SKILL.md`。
- 発注を出した・納品を受けた・組み込んだら、`docs/dashboard.md`（3・4・7 章）と `docs/progress.md` を更新する。

## テスト（必ず通してからコミット）

```bash
# クラウドの環境に Godot が無ければ CI と同じ URL から落とす：
# https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip
export GODOT=/path/to/Godot_v4.7-stable_linux.x86_64
tools/run_tests.sh                 # 全ステージ：インポート → 床プローブ → 自動操縦でクリアまで
tools/run_tests.sh --stage=mouth   # 1 ステージだけ
tools/screenshot.sh mouth /tmp/a.png --play=3   # Xvfb + Mesa でスクリーンショット（見た目の確認）
tools/screenshot.sh model:pod /tmp/b.png        # キャラクター 1 体だけ
```

- `RESULT: OK` と `PROBE RESULT: OK` が出ること。`SCRIPT ERROR` が 1 つも出ないこと。
- 自動操縦は `godot/tests/autopilot.gd`（テストとスクリーンショットで共用）。

## よくある落とし穴

- Godot の trimesh 当たり判定は片面。部屋・くだのメッシュは面を内向きにそろえる（`orient_inward()` = 一貫化＋全反転）。
- マーカーの高さがずれても、ひろいもの・ゴール・神経などは実行時に床へ吸着する（`ModelLib.snap_to_floor`）。
- `set_anchors_preset` ではなく `set_anchors_and_offsets_preset`（前者は 0 サイズのまま）。
- CanvasLayer の下の Control にはテーマが届かないので `Game.add_overlay()` / `_set_screen()` 経由で付ける。
- GDScript のラムダはローカル変数を値でつかむ（テストのフラグはメンバ変数にする）。
- 前は Blender の +Y（Godot の -Z）。
