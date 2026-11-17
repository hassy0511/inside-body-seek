# からだのなか だいぼうけん — 開発メモ（Claude 向け）

子ども向け（6〜10 歳）の体のしくみを学ぶ 3D ゲーム。Godot 4.7（GDScript）＋ Blender（bpy スクリプトで GLB 生成）。
企画は `docs/design.md`、物語は `docs/story.md`、カルテ（1 話）形式の つくりは `docs/episodes.md`、使い方・構成は `README.md`。
遊びは「カルテ」1 本ずつ：そうだん → よそう → 場面 1〜3 こ（いまの ステージ ＝「場所」を 使う）→ カルテ（3 行・クイズ・ほし）。

## 変更するときの約束

- 文章は ひらがな・カタカナ中心。一文字の臓器名は「い（胃）」「は（歯）」「ち（血）」のように漢字を添える。分かち書き（単語の間にスペース）。この きまりは `EpisodeDB.text_problems()` が 調べ、テストが データと 画面に 出た 文の 両方に かける（くわしくは `docs/episodes.md` 2.2）。
- 体の事実は子ども向けに丸めてよいが、間違いは入れない（数値は `docs/design.md` の表に合わせる）。
- **カルテ**（そうだん・よそう・場面ごとの 上書き・あとの はなし・カルテの 3 行・クイズ）は `godot/src/autoload/episode_db.gd`。**場所**（既定の ミッション・ものしりカード・まとめ）は `godot/src/autoload/stage_db.gd`。場所の 形と スポーン位置は `blender/stages.py`（Empty の名前 `MK_...` がスポーン）。
- カルテを 足すのは データだけ（`EPISODES` に 1 件。`docs/episodes.md` 8 章）。`episode_db.gd` の 先頭の「書きかたの きまり」は ダッシュボードが 読むので 守る。場面は `hints` と、さいごの 場面の `after` を かならず 書く。
- 原因の 種あかしや 学びは、ボタンで 進む 画面（`after`・カルテ）に 書く。HUD の 文（`intro`・`goal_say` など）は 時間で 消えるので「いま 何を するか」だけ。
- モデルを変えたら GLB を作り直す：`<venv>/bin/python -m blender.characters <name>` / `-m blender.stages <stage_env>`（`blender -b -P blender/stages.py -- stage_mouth` でも可）。
- 生成した GLB・WAV はコミットする。`godot/.godot/` と `blender/out/` はコミットしない。
- Godot 側のコードは「子どもが詰まらない」を最優先：ゲームオーバーなし、はさまったら戻す、ヒントは上書きしない（`Game.hud_busy()`）。よそうの はずれは しからない（ほしにも 入れない）。データが まちがって いても ゴールは 開く（`Level._fit_missions()`。テストは 失敗に なる）。
- カルテの 流れの 画面（`src/ui/flow_screen.gd` を 継ぐ 4 つ）は、いつも 押せる ボタンに フォーカスが ある こと・時間で 勝手に 進まない こと・1280×720 に 入る こと。

## ブランチとダッシュボード

- 本線は `main`。Claude はセッションの作業ブランチで直し、テストが通ったら `main` にも push する（fast-forward）。Codex の依頼文も `main` を見る。
- Codex の納品は `art/<波>` ブランチ。`main` には spec の md と「そのまま使う PNG」だけ取り込む（`docs/art_orders/取り込み手順.md`）。
- ブックマーク用のページ（GitHub Pages）：https://hassy0511.github.io/inside-body-seek/ 。main に push すると CI がテストのあと `tools/build_dashboard.py` で `docs/dashboard.md` から作りなおして `gh-pages` に出す。手で更新しない（dashboard.md 8 章）。
- ブラウザで 遊べる 版も 同じ CI が 出す：`play/`（いまの main。`tools/export_web.sh`）。ページの 先頭の ボタンから 開く。`compare/a`・`compare/b` と `tools/compare/` は、作りかたの 分担を 決める ための 一時的な くらべもの（決まったら 消す）。

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
tools/run_tests.sh                 # 全部：インポート → 床プローブ → 全カルテ（画面は ボタンを 押して 進む）→ 全部の 場所 → ダッシュボードの 試し作り
tools/run_tests.sh --episode=ep03  # カルテ 1 本だけ
tools/run_tests.sh --stage=mouth   # 場所 1 つだけ（既定の ミッション）
tools/export_web.sh /tmp/web       # ブラウザ版を 書き出す（「WEB EXPORT: OK」。テンプレートの 入れかたは test.yml。見る ときは http で 出す）
tools/screenshot.sh mouth /tmp/a.png --play=3   # Xvfb + Mesa でスクリーンショット（見た目の確認）
tools/screenshot.sh model:pod /tmp/b.png        # キャラクター 1 体だけ
tools/screenshot.sh guess:ep03 /tmp/c.png       # カルテの 画面（select／consult:ep03／guess_go:ep01／after:ep03:0／karte:ep03:1／ep03:1 …）
tools/screenshot.sh "select,consult:ep01+p1,karte:ep02:3+hurt" /tmp/shots/   # 「,」で 何枚も。しるし（+p1 +hit +wrong +hurt +touch）は godot/tests/shot.gd の 先頭
```

- `PROBE RESULT: OK`・`RESULT: OK`・`DASHBOARD: OK` が出ること。`SCRIPT ERROR` が 1 つも出ないこと。
- 自動操縦は `godot/tests/autopilot.gd`（テストとスクリーンショットで共用）。テストと 撮影は 別の セーブ（`SaveData.use_path()`）を 使うので、手元の `user://save.json` は 変わらない。
- 画面を 変えたら スクリーンショットで 見る（文の はみ出し・重なり。`--touch` も）。テストは 文の きまり・はみ出し・フォーカスの 行き先（本物の 入力）も 見るが、見た目の よしあしは 見ない。

## よくある落とし穴

- Godot の trimesh 当たり判定は片面。部屋・くだのメッシュは面を内向きにそろえる（`orient_inward()` = 一貫化＋全反転）。
- マーカーの高さがずれても、ひろいもの・ゴール・神経などは実行時に床へ吸着する（`ModelLib.snap_to_floor`）。
- `set_anchors_preset` ではなく `set_anchors_and_offsets_preset`（前者は 0 サイズのまま）。
- CanvasLayer の下の Control にはテーマが届かないので `Game.add_overlay()` / `_set_screen()` 経由で付ける。
- GDScript のラムダはローカル変数を値でつかむ（テストのフラグはメンバ変数にする）。
- 前は Blender の +Y（Godot の -Z）。
- フォーカスは、`focus_mode = FOCUS_NONE` に した 瞬間と、フォーカス中の ノードを `queue_free` した 瞬間に 消える。画面の 中身を 作りかえたら 同じ 関数の 中で `set_focus()`。上下左右の 行き先は、まかせると 思わぬ ボタンへ とぶ 所だけ `focus_neighbor_*` で 決める。
- 押しすぎ よけは `lock()`／`locked()`（ボタンを `disabled` に しない）。時間は `_process` の delta で 数える（テストは 実時間より ずっと 速く 回る）。
- `flow_screen.gd` を 継いだ 画面で `const T` を もう一度 書くと エラー。
- 自動で 折りかえす 文は `T.body()`／`T.nobreak()` を 通す（そのままだと かなの 途中で 折れる）。文が 箱に 入るかは `lines_of()` で 本物の フォントで はかる。
- HUD の 文：物語の ひとことは `Level.say_story()`（出てから 2 秒は 上書きされない）、おまけの ひとことは `Game.say_soft()`（あいて いる ときだけ）。`m.add()` の あとに `Game.say()` を 書くと、中で 出た `goal_say` を 消す。
- `const` の 辞書は 読み取り専用。場面の 辞書は `EpisodeDB.scene_stage()` の 写し（`duplicate(true)`）に 書く。
- 数は グループから 数えない（`queue_free` した 前の Level の ノードが フレームの 終わりまで のこる）。マーカーの 配列から 数える。
- ヘッドレスの 窓は 64×64。画面の はみ出しを 見る テストは 1280×720 に 固定して から（`smoke.gd` の 先頭）。
- セーブの JSON は 数や 文字が まざる。`== true` で くらべず 型を 見る（`SaveData._yes()`）。
- ブラウザ版（Web）には、パソコンの フォントの 代わりが 無い。入れて ある フォントに 無い 字は 四角に 化ける（場面の 一時停止ボタンの 絵が そう）。記号を 足したら ブラウザ版でも 見る。
- 同じ サイトに 置いた Godot の ブラウザ版は、どれも 同じ 入れ物（IndexedDB の `/userfs`）に セーブを 書く。版を ならべる ときは 名前を 分ける（`tools/compare/build.sh`）。
