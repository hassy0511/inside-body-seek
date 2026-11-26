# からだのなか だいぼうけん — 開発メモ（Claude 向け）

子ども向け（6〜10 歳）の体のしくみを学ぶ 3D ゲーム。Godot 4.7（GDScript）＋ Blender（bpy スクリプトで GLB 生成）。
企画は `docs/design.md`、物語は `docs/story.md`、カルテ（1 話）形式の つくりは `docs/episodes.md`、使い方・構成は `README.md`。
遊びは「カルテ」1 本ずつ：そうだん → よそう → 体に 入る → 場面（いまの ステージ ＝「場所」を 使う。入口から じゅんばんに、あいだに みちの ちず `src/ui/hop.gd`）→ 体から 出る → カルテ（3 行・クイズ・ほし）。入口と 出口は 話ごとの データ（`enter`／`exit`。画面は `src/ui/journey.gd`）。

## 変更するときの約束

- 文章は ひらがな・カタカナ中心。一文字の臓器名は「い（胃）」「は（歯）」「ち（血）」のように漢字を添える。分かち書き（単語の間にスペース）。この きまりは `EpisodeDB.text_problems()` が 調べ、テストが データと 画面に 出た 文の 両方に かける（くわしくは `docs/episodes.md` 2.2）。
- 体の事実は子ども向けに丸めてよいが、間違いは入れない（数値は `docs/design.md` の表に合わせる）。
- **カルテ**（そうだん・よそう・場面ごとの 上書き・あとの はなし・カルテの 3 行・クイズ）は `godot/src/autoload/episode_db.gd`。**場所**（既定の ミッション・ものしりカード・まとめ）は `godot/src/autoload/stage_db.gd`。場所の 形と スポーン位置は `blender/stages.py`（Empty の名前 `MK_...` がスポーン）。作りなおした 場所は 1 つ 1 ファイル（`blender/stage_mouth.py`・`stage_esophagus.py`・`stage_stomach.py`。部品は `blender/stage_kit.py`）。絵から 作りなおした キャラクターも 1 体 1 ファイル（`blender/pod.py`、`blender/mushiba.py`、`blender/pylori.py`、`blender/wallcell.py`。手本は pod。絵との 見くらべは `tools/pod_views.sh <出力> <id>` と `tools/pod_compare.py`）で、`characters.py` の `BUILDERS` から 呼ぶ。
- 場面は 体の 入口から じゅんばんに 並べ、とちゅうの 場所を とばさない（`validate()` の みちの きまり）。とおるだけの 場所は `"pass": true` と `say` の「とおりみち」（てき・ミッションなし。ハートの ほしに 数えない）。くわしくは `docs/episodes.md` 10 章。
- カルテを 足すのは データだけ（`EPISODES` に 1 件。`docs/episodes.md` 8 章）。`episode_db.gd` の 先頭の「書きかたの きまり」は ダッシュボードが 読むので 守る。場面は `hints` と、さいごの 場面の `after` を かならず 書く。
- 原因の 種あかしや 学びは、ボタンで 進む 画面（`after`・カルテ）に 書く。HUD の 文（`intro`・`goal_say` など）は 時間で 消えるので「いま 何を するか」だけ。
- ものしりカードは ゲームを 止めない：場面の とちゅうは `Game.find_card()`（音と HUD の 小さい ふだ。本文なし）だけ。読むのは ふつうの 場面の あとの「みつけた ものしりカード」（`src/ui/cards_found.gd`、phase `cards`。新しい カードが ある ときだけ。とおりみちは 出さない）と ずかん。Level が 動いて いる あいだに `Game.show_card()` や ポップアップを 出さない（テストの `_watch_cards` が 失敗に する）。
- 「よけろ」「のれ」と 言う ものは、そう しないと 何かが 起きる ように 作る（しょくどうの かたまりは ぶつかると なみから おちて おそく なる。ハートは へらない）。体に ふつうは 無い ものを 場所の モデルに 置かない（食べものの かたまりは カルテ 2 の 場面の データ `"lumps"` だけ）。
- モデルを変えたら GLB を作り直す：`<venv>/bin/python -m blender.characters <name>` / `-m blender.stages <stage_env>`（`blender -b -P blender/stages.py -- stage_mouth` でも可）。
- 生成した GLB・WAV はコミットする。`godot/.godot/` と `blender/out/` はコミットしない。
- 音楽は `tools/music/`（1 曲 1 ファイル `tracks/<名前>.py`、共通の モチーフ `motif.py`）。`<music-venv>/bin/python -m tools.music build <名前>` で `godot/assets/audio/<名前>.ogg`（と `.import`）を 作り、`check` が `MUSIC: OK` を 出す こと。OGG と `clear.wav` は コミットし、作業用の `tools/music/out/` と 音色（86 MB の sf3）は コミットしない。手順は `docs/audio.md`。
- どこで どの 曲かは 場所の `"bgm"`（`stage_db.gd`）と `sfx.gd` の `PHASE_MUSIC`（フェーズ）。ボスの いる 場面は `bgm_boss`。ブラウザ版では 音楽を Stream 再生に している（Sample 再生は OGG を 丸ごと ほどいて 手ばなさない。`docs/audio.md`）。
- 操作：ひろい 場所（ひろば・へや）は 乗りものの ように 動かす（ひだり・みぎで 向きを 変え、カメラは いつも 後ろ。うえで 進み、したで 下がる）。くだの 場所は 道に そって 進み、ひだり・みぎで 横に 動く。しょくどうは うしろから くる なみが 船を はこぶ（`src/level/peristalsis.gd`、場所の `"waves"`）。ひろい 場所で ↑ だけを おして かべに ぶつかると、船は じぶんで かべから 45° はなれる 向きまで まがって へやの 中へ もどる（`player.gd` の `_wall_glide`。←→ を すこしでも おして いる あいだは はたらかない）。数値は `player.gd`・`follow_camera.gd` の 先頭。入力を 決めて 動きを 記録する 道具は `godot/tests/steer_trace.tscn`。
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
tools/web_text_check.sh            # ブラウザ版と テストで 文の 行の 折りかたが 同じか（「WEB TEXT: OK（N 画面、M 文）」。約 8 分。写しを 書き出すので XDG_DATA_HOME は そのままで よい。--setting=off で ちがいが 出る ことを たしかめる）
tools/screenshot.sh mouth /tmp/a.png --play=3   # Xvfb + Mesa でスクリーンショット（見た目の確認）
tools/screenshot.sh model:pod /tmp/b.png        # キャラクター 1 体だけ
tools/screenshot.sh guess:ep03 /tmp/c.png       # カルテの 画面（select／consult:ep03／guess_go:ep01／after:ep03:0／karte:ep03:1／ep03:1 …）
tools/screenshot.sh hop:ep02:0 /tmp/d.png       # みちの ちず（hop:ep02:-1 は とおりみちを とばす とき。enter:ep02+cleared で とばす ボタン。guide:mouth は そうじゅうの てびき）
tools/screenshot.sh "chip:stomach:acid,cards:intestine" /tmp/shots/   # カードの ふだ（chip:<場所>:<key>）と「みつけた ものしりカード」（cards:<場所>[:n]）
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
- ブラウザ版（Web）には、パソコンの フォントの 代わりが 無い。入れて ある フォントに 無い 字は 四角に 化ける。記号は 字で なく 形で 描く（一時停止ボタンは 棒 2 本）。字を 足したら ブラウザ版でも 見る。
- 場所の 見た目は `StageDB` の `"look"`（光・きり・面の 色と 画像・あわ・ゆれ。キーの 説明は `src/level/stage_look.gd` の 先頭）。`"look"` が 無い 場所は 前の まま。面の 画像は `godot/assets/textures/stages/tex_<場所>_<floor|wall>.png` を 置くだけ（GLB は 作りなおさない。`.import` は 手で mipmaps を 入れる。口は Codex の 絵で、512 px で 読みこむ。`tools/gen_stage_textures.py` は ある 画像を 上書きしない）。場面の 看板は 板の 絵（`assets/ui/sign_board.png`）に 字を のせる（`level.gd` の `_sign_board()`。幅は 7 m まで）。見た目を 作る ときの 撮影は `godot/tests/stage_view.tscn`（HUD なし・すきな 位置）。
- この 描画方式（Compatibility）は 色の 計算を 画面の 色の まま する（sRGB と リニアを 変換しない）。頂点の 色で かける 倍率は、見た 目の 色の 比で 書く。自動の LOD は 丸い 形を つぶす ことが ある（pod・stage_mouth は `.import` で 切った）。
- この 描画方式では まわりの 光・たいよう・ミクロごうの ライトが 別々に 描かれ、画面の 色の まま 足される。とても 弱い たいよう（0.035）でも 色の 約 0.2 ぶん 明るく なる。キャラクターの 色は、色の わかった 球を ゲームの カメラの 位置に 置いて 測る。
- 場所の 面（`stage_clay.gdshader`）は 向きの ある 光（"fill" も）に `light_gain` を、ミクロごうの ライトに `light_gain × lamp_gain` を かける。場所の たいようを 変えたら 3 つの 積を たもつ：`sun_energy × light_gain`、`fill_energy × light_gain`、ライト 0.9 × `light_gain × lamp_gain`（い（胃）では 0.45・0.24・0.24）。でないと 面の 見た目が 変わる。
- い（胃）の 光は キャラクターが 自分の 色で 見える ように して ある（光の がわ 0.95〜1.1 倍、かげ 0.75〜0.9 倍）。い（胃）に 出る モデルは 絵の 色を そのまま 使い、明るさの おぎないを しない。ほかの 場所は まだ 測って いない（たいようが 強く、1.3〜1.45 倍に 明るい らしい）。
- うごかない なかま（`friend.gd` の move "static"。いまは かべの さいぼう）は 子ノード `Stand` の 上に 立つ（`Stand` の 原点 ＝ モデルの いちばん 下、ゆかより `SINK` 下）。いき・はずみ・向きを 足す コードは `Stand` を 大きく したり まわしたり する。モデルを 直接 動かすと 底が ゆかから はなれる。
- 当たりの レイヤー 128（`Friend.SOLID_LAYER`）は、うごかない なかまの 中の 円柱（`FriendSolid`）。見るのは 船だけ（ゆか・カメラ・`_free_step` の レイ、ピロリきん、たまは 当たらない）。正面から ぶつかると 船は よこへ すべり（`_slip_around_friends`）、これに ふれて いる だけでは `_check_stuck` は はさまった ことに しない。うごかない なかまは かべから はなして 置く（当たりと かべの あいだ 1.6 m いじょう。せまいと ↑ を 押しつづけた 船が 6 秒ほど 止まる。テストの `FRIEND_GAP`）。
- `MouthHappy` は なかまの GLB に あっても なくても よい ノード（ひらいた 口）。ゲームは はじめて おうえんされる まで かくす（`Friend.find_happy_mouth`）。GLB を 見せる だけの 道具（カード・ずかん・`pod_views`）では 見える。
- カードの 3D の 絵は 回らない。顔の まわりで ±50° ゆれ（`card.gd` の `SWAY_DEG`・`SWAY_SEC`。タイルは 止まった `STILL_DEG` 35°）、大きさは `picture_fit()`（どの 角度でも 箱の かどが わくの 94% に 入る）、光は 前からの 共通の `add_picture_light()`（カードに 合わせて モデルの 色を 変えない）。絵は いつも はかった 大きさ（`size`。カードは `PIC_SIZE` 320×400）の まま 入れものの まん中に 置く：ならべる 側が 入れものを のばしても 絵は のばさない。のばすと たての 画角が 同じ なので 中身が 大きく なり、よこが 切れる（ブラウザ版の ずかんで ピロリきんが 切れた）。`smoke.gd` の `_check_card_pictures` が キャラクターの GLB ぜんぶを 見る（長い 部品は そこで 落ちる）。一覧で 見るのは `tools/card_sheet.sh`。
- 体を 弓なりに 曲げる ときは、切り口も 曲げに そって まわす（`pylori.py` の `bend_map`）。中心の 線だけ ずらすと 曲がった ところで 太さが くずれる。
- 1 体の 絵どうしが 食いちがう ときは、ゲームの カメラが 見る 向き（うしろ上）の 絵を とり、えらんだ ことを 記録（`docs/art_orders/<波>_<ID>_3D化の結果.md`）に 書く（ピロリきんの 帯は 真横より 真上を とった）。
- 同じ サイトに 置いた Godot の ブラウザ版は、どれも 同じ 入れ物（IndexedDB の `/userfs`）に セーブを 書く。版を ならべる ときは 名前を 分ける（`tools/compare/build.sh`）。
- HUD の 左上（ハートの 下）は カードの ふだ（`hud.gd` の `CHIP_POS`）と しょくどうの「なみに のって N センチ」（`RideReadout`。ふだは その 下に 出る）が 使う。HUD に 部品を 足したら `hud.hud_rects()` に 入れる（ふだと 重ならない ことを テストが 見る）。出す 数は 本物の からだの 長さ（場所の `"waves"` の `body_cm`。カードの 数と 食いちがわせない）。
- 光る 黄色は ゴールだけ（い（胃）で テストが 見る）。ミクロごうの 上の 矢印は、いつも 画面に 向いた ひらたい 水色の 矢じるし（画面の 上 ＝ まえ、右 ＝ みぎ、下 ＝ うしろ。`player.gd` の `_make_arrow`・`_update_arrow`）。立体の 矢印（円すい）を 行き先へ 向けると、カメラが いつも 後ろなので まえを 指す ときに ただの 丸に 見える。いえきの いけは 光らない 琥珀色。
- いえきの いけの 水は `hazard_pool.gd` が マーカーの 高さに 出す。水の ふちは モデルの `PoolRims` が 水面を よこぎる ところ（半径 r）。あぶない ところは ミクロごうの まんなかが r より 内がわ。`smoke.gd` の `_check_pools()` が 見る。い（胃）の GLB は LOD を 切る（ふちが くずれると 水の ふちが ずれる）。
- しょくどうの きかん（気管）は 見た目だけ（`NC_Trachea`）。あなは 当たるだけの 面（`TracheaPlug`）で ふさぐ。くだの 場所に わき道を 作る ときは、入れない ように ふさぐか、入っても 出られる ように する（行きどまりに 入ると 出られない）。
- はさまった ときの もどし（`player.gd` の `_check_stuck`）は ひろい 場所では 押した 向きの はんたいへ。かべの 手前で とめ、下に ゆかが ない 所へは うごかさない（`_free_step`）。テストは `_check_back_hold()`。
- ひろい 場所の カメラ（`follow_camera.gd`。くだと 俯瞰は SpringArm3D の まま）は、うしろの かべで ちぢまずに、まず 上がって 見おろし、たりなければ かべを ぬけて 船から 3.6 m を たもつ。場所の 面は うらを 描かない（`cull_back`）ので 中は 見えるが、場所の 外は 何も ない 色で 見える。ぬけて よいのは、そこからの 画面の どの 向きにも 面の おもてが あり、かべを 1.2 m より 近くで なめない ときだけ（`_sees_void`）。だめなら かべの 手前まで よる（2.2 m まで）。かべを 0.3 m で なめる 画面も、外と 同じ 平らな こい 色に 見える。テストの 外の はかりかた（`smoke.gd` の `_void_share`）は `hit_back_faces = false` の 線（`cull_back` が 描く ものと 同じ）。
- かべで はねかえる とき（`_wall_glide`）、かべと ならんだ ところで やめない（かべに そって すすむと、かべぞいの てきへ はこび、うしろの かべで カメラが よったり はなれたり する）。かべへ むいて いる あいだは ゆっくり（`GLIDE_SPEED`）：はやい ままだと まがりながら 坂を ななめに のぼり、口の くちびるを こえる。かべに ふれて いるかは `get_slide_collision` で 見るので、船を とめる 守りを 足すと（ゆかの ない 先へ すすませない、など）かべに ふれなく なって はねかえらない。
- ゆかの ない まま 0.8 秒で チェックポイントへ もどる（`player.gd` の `NO_FLOOR_BACK`）。船の ゆかさがしは かたむき（`normal.y`）0.35 より きつい 面を ゆかと 見ない。ふつうに こえる すきまは 長くて 0.25 秒。
- ↑ だけの 走りで へる ハートの 数は、1 本ごとの ぶれが 大きい（きまりを 少し 変えると 道すじが まるごと 変わる）。きまりを くらべる ときは、向きを 変えた 16 本（30 秒ずつ）で、とまった 時間・もどしの 回数と いっしょに 数える。
- かんばんは `Level.signs` に 入れ、カメラからの きょりで うすく する（`_fade_signs`）。`visibility_range` の フェードは この 描画方式（ブラウザ版も）では きかない。
- ソフトウェア描画の `stage_view.tscn` は 待つ あいだに 物理が 何秒も すすむ。ながれ・なみの ある 場所は `--still`。
- 書き出した 版（ブラウザ版）の 行の 折りかたは、`project.godot` の `internationalization/locale/include_text_server_data=true` が ある ときだけ テスト（エディタ）と 同じに なる。無いと 空白でしか 折れず、はかった 箱から 文が はみ出す・ことばの 中で 折れる（テストが 設定を 見る。消さない）。行を きっちり 決めたい せまい 箱（「みつけた ものしりカード」の タイルの だいめい）は、折りかえしに まかせず 自分で「\n」を 入れる。
- くだの 場所の はじめ 2.5 m では うしろへ 進めない（`player.gd` の `_tube_start_guard`。はじめが ひらいた くだから 船が 出て おちる）。もどしの テスト（`BACK_PLACES`・`_check_free_step`）は 口・胃・小腸・血管・鼻を 見る。
- `XDG_DATA_HOME` を 変えて Godot を 動かすと セーブの 場所が 分かれる（いくつもの 写しで 同時に テストする ときに 使う）。ただし 書き出しの テンプレートも その 下を さがすので、`tools/export_web.sh` は 変えずに 動かす。
