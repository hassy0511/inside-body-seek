# からだのなか だいぼうけん（inside-body-seek）

ちいさくなって 体の中に入り、ぐあいのわるいところを さがして なおしながら 体のしくみを学ぶ、子ども向けの 3D ゲームです。
Godot 4.7（GDScript）で動き、3D モデルは Blender の Python スクリプトで生成しています（試作版）。

- きみは「ミクロしんりょうじょ」の見習いのおいしゃさん。毎回だれかが相談に来る、**1 話ごとの「カルテ」形式**（いま 1〜3 話。全 10 話の予定）
- 1 話の流れ：そうだん（患者さんの話を聞く）→ よそう（からだの地図で「どこが あやしいか」をえらぶ。はずれても しかられない）→ からだの入口から、とちゅうの場所もじゅんばんにめぐる（とおるだけの場所は短い「とおりみち」。場面のあいだに「みちの ちず」）→ カルテ（なにが おきていた／どうして／これからは の 3 行とクイズ）
- 体の中の「場所」は 口・食道・胃・小腸・血管・心臓（右）・肺・心臓（左）・脳・鼻 の 10 こ。話ごとに、出てくるものとミッションが変わる
- ミッションは「やっつける」だけでなく「あつめる」「とどける」「おうえん（しらべる）」「たどりつく」「じゅんばんをおぼえる」
- はじめて出会った生き物・場所の「ものしりカード」と、解いた「カルテ」が「ずかん」にたまる
- 星は 1 話に 3 つ（カルテ かんせい／ハートをへらさずに／クイズにせいかい）。別々の回で取ってもよい
- 操作はボタン 2 つ（うごく＋おくすり。ダッシュはおまけ）。ゲームオーバーはなく、チェックポイントから何度でも。とちゅうでやめても「つづきから」入れる

企画は [docs/design.md](docs/design.md)、物語は [docs/story.md](docs/story.md)、カルテ形式のつくり（データの形・画面・テスト）は [docs/episodes.md](docs/episodes.md) にあります。
開発の進み具合（ダッシュボード）：https://hassy0511.github.io/inside-body-seek/

## 遊び方

**ブラウザで遊ぶ（インストール不要）**：https://hassy0511.github.io/inside-body-seek/play/ （いまの main のゲーム。最初の読みこみは 50 MB ほど。スマホは横向き）

**手元で動かす**：

1. [Godot 4.7 以上](https://godotengine.org/download) をインストール
2. Godot のプロジェクトマネージャーで「インポート」→ `godot/project.godot` を選ぶ
3. ▶（F5）で実行

| 動作 | キーボード | ゲームパッド | タッチ |
| --- | --- | --- | --- |
| うごく | 矢印キー / WASD | 左スティック / 十字キー | 左の丸いスティック |
| おくすり（撃つ・おうえん） | スペース / Z / Enter | A | 右の大きいボタン |
| ダッシュ | Shift / X | B | 右の小さいボタン |
| ポーズ | Esc / P | Start | ⏸ |

そうだん・よそう・カルテの画面は、えらんで決定（スペース / Z / Enter / A）、もどるは Esc / X / B。タッチやマウスならボタンを直接おします。

カメラは自動で追いかけるので、カメラ操作はいりません。船は臓器の「ゆか」の上を浮いて進みます。
おくすりは近くの敵を自動でねらい、なかまはさわるだけで応援できます。
タッチ操作はタッチ画面があると自動で出ます（タイトル画面やポーズ画面で切りかえ可能）。

進み具合（星・とちゅうのカルテ・ずかん）は `user://save.json` に自動保存されます。

## ファイル構成

| 場所 | 中身 |
| --- | --- |
| `godot/project.godot` | Godot プロジェクト本体 |
| `godot/src/autoload/episode_db.gd` | **カルテ（1 話）の定義**：そうだん・よそう・場面ごとの上書き（ミッション・文・出すもの）・カルテの 3 行・クイズ。話の文を直すならここ |
| `godot/src/autoload/stage_db.gd` | **場所（臓器）の定義**：既定のミッション・ものしりカード・まとめ。カードの文を直すならここ |
| `godot/src/autoload/game.gd` | 画面の流れ（タイトル → カルテえらび → そうだん → よそう → からだに はいる → 場面（あいだに みちの ちず）→ からだから でる → カルテ）と入力の設定 |
| `godot/src/autoload/save_data.gd` | セーブ（カルテごとの星・とちゅうのカルテ・見たカード・設定） |
| `godot/src/level/level.gd` | 場面（場所 1 つ）の読み込み・スポーン・ミッション進行・カードを見つける合図（ゲームは止めない）。話のことは知らず、わたされた辞書だけを読む |
| `godot/src/level/peristalsis.gd` | 食道のぜん動の波（筋肉の輪がしまり、船をはこぶ）。カルテ 2 の食べ物のかたまり（`entities/lump.gd`）と、気管のふたもここ |
| `godot/src/player/` | プレイヤー（ホバー船）・カメラ・おくすりの弾 |
| `godot/src/entities/` | 敵・ボス・なかま・アイテム・ゴール・チェックポイント・いえきの池・食べ物のかたまり・弁・神経 |
| `godot/src/ui/` | カルテえらび（`episode_select.gd`）・はなし（`talk.gd`）・よそう（`guess.gd`）・カルテ（`karte.gd`、紙は `karte_sheet.gd`）と、その土台（`flow_screen.gd`）。HUD・ものしりカード（`card.gd`）と「みつけた ものしりカード」（`cards_found.gd`）・タイトル・ずかん・ポーズ・タッチ操作・テーマと絵の差しかえ口（`ui_theme.gd`） |
| `godot/assets/models/characters/*.glb` | キャラクターの 3D モデル（Blender スクリプトの出力） |
| `godot/assets/models/stages/*.glb` | 場所の地形＋スポーン位置（Blender スクリプトの出力） |
| `godot/assets/ui/*.png` | 納品された絵（顔・全身など）。同じ名前で置くと自動で使われる |
| `godot/assets/audio/*.wav`（`clear.wav` の ほか） | 効果音（`tools/gen_audio.py` の出力） |
| `godot/assets/audio/bgm_*.ogg`・`jingle_*.ogg`・`clear.wav` | 音楽（`tools/music/` で楽譜から作る。`docs/audio.md`） |
| `blender/characters.py` | キャラクターを作る bpy スクリプト |
| `blender/stages.py` | ステージの地形とマーカーを作る bpy スクリプト |
| `blender/common.py` | 共通ヘルパー（マテリアル・形・書き出し） |
| `tools/gen_audio.py` | 効果音を合成 |
| `tools/music/` | 音楽を楽譜から作る（`python -m tools.music build`。`docs/audio.md`） |
| `tools/run_tests.sh` | Godot ヘッドレスのテスト（全カルテ ＋ 全部の場所 ＋ ダッシュボードの試し作り） |
| `tools/export_web.sh` | ブラウザで遊べる版（Web）の書き出し。CI が GitHub Pages の `play/` に出す |
| `tools/web_text_check.sh` | ブラウザ版とテストで、画面の文が同じ行で折れるかをくらべる（「WEB TEXT: OK」。文・フォント・書き出しの設定を変えたら回す。Chromium が要るので CI では回さない） |
| `tools/compare/` | 同じ指示文で別々に作られた 2 つの実装（A・B）を遊べる形にする、一時的なくらべもの |
| `godot/tests/smoke.gd` | その中身（画面はボタンを押して進め、場面は自動操縦でクリアまで） |
| `tools/screenshot.sh`、`godot/tests/shot.gd` | 画面・場面・モデルのスクリーンショット（Xvfb + Mesa） |
| `tools/build_dashboard.py` | 進み具合のページ（GitHub Pages）を作る。CI が main への push ごとに回す |

## 3D モデルの作り直し（Blender）

モデルはすべて `blender/` の Python で作っています。Blender 本体でも、pip の `bpy` でも動きます。

```bash
# A. Blender 本体を使う（4.2 以降）
blender -b -P blender/build_all.py              # 全部（.blend も保存するなら -- --blend）
blender -b -P blender/characters.py -- pod       # キャラクター 1 つだけ
blender -b -P blender/stages.py -- stage_mouth   # ステージ 1 つだけ

# B. pip の bpy を使う（Python 3.11 または 3.13。環境に合う bpy を入れる）
python -m venv .venv && .venv/bin/pip install bpy numpy
.venv/bin/python -m blender.build_all          # --blend を付けると blender/out/ に .blend も保存
```

出力は `godot/assets/models/` に書かれ、Godot を開き直すと自動でインポートされます。
キャラデザを描き直したときは、`blender/characters.py` の関数を書きかえるか、
Blender で手作業で作ったモデルを **同じ名前の GLB** で上書きすれば差し替わります（前は Blender の +Y 方向で作ってください）。

### ステージの GLB に入れるマーカー

Godot は GLB の中の Empty の名前を見てスポーンします（`MK_<種類>_<名前>_<番号>`）。
メッシュには自動で当たり判定がつきます。名前が `NC_` で始まるメッシュはかざり（当たり判定なし）です。

| 名前 | 意味 |
| --- | --- |
| `MK_player` | スタート位置（向きは Empty の -Z = Blender の +Y） |
| `MK_goal` | ゴール（ほかのミッションが終わるまでロック） |
| `MK_checkpoint_1` | チェックポイント |
| `MK_path_000`… | 道（くだステージの中心線。番号順。流れ・波・カメラの向きに使う） |
| `MK_enemy_mushiba_1` | 敵（mushiba / pylori / akudama / virus） |
| `MK_boss_boss_virus` | ボス |
| `MK_friend_rbc_1` | なかま（wallcell / zendama / rbc / wbc） |
| `MK_pickup_nutrient_0_1` | ひろうもの（nutrient は 0〜2 で見た目が変わる / heart_item） |
| `MK_deliver_villus_1` | とどけ先 |
| `MK_hazard_acid_r6_1` | いえきの池（r のあとが半径） |
| `MK_gate_1` | 弁（ドア）。Empty の向きで通る方向が決まる |
| `MK_neuron_1` | 神経（じゅんばんパズル） |
| `MK_sign_ra` | かんばん（文字は `level.gd` の `SIGN_TEXT`） |
| `MK_card_epiglottis` | 近づくとカードが見つかるだけの点（カードは `stage_db.gd`。場面のとちゅうは HUD の小さいふだだけで、ゲームは止まらない） |

## カルテ（話）を増やすには

話はデータだけで足せます（くわしい形は [docs/episodes.md](docs/episodes.md) 2.2、4〜10 話の手順は同 8 章）。

1. `godot/src/autoload/episode_db.gd` の `EPISODES` に 1 件追加する。先頭のコメントの「書きかたの きまり」を守る（ダッシュボードが読みます）。
   - `consult`（そうだん 1〜3 ページ）、`guess`（よそう 2〜3 たく。出発できるえらびに `go`、原因に当たっているえらびに `hit`）
   - `scenes`（1〜5 こ。入口からじゅんばんに、とちゅうの場所をとばさない。とおるだけの場所は `"pass": true` と `say` の「とおりみち」。遊ぶ場面は 3 こまで）：`place`（場所の id）＋ その場面の `missions`・`intro`・`hints`、出すものを変える `spawn`（`skip`／`swap`）、場面のあとの会話 `after`（さいごの場面には必ず）
   - `karte`（なにが おきていた／どうして／これからは）と `quiz`
2. 新しい患者なら `PATIENTS` に足す（絵が無いあいだは仮の顔が出ます）。
3. `tools/run_tests.sh --episode=epNN` を通す。データのまちがい・文の長さ・文のきまり（ひらがな、わかち書き、「い（胃）」）・文が画面に入るかを、テストが調べます。
4. `tools/screenshot.sh consult:epNN /tmp/a.png`（`guess:`、`after:epNN:0`、`karte:epNN:1` など）で画面を見る。

原因の種あかしや学びは、ボタンで進む画面（`after` とカルテ）に書きます。遊んでいるあいだの HUD の文は時間で消えるので、「いま何をするか」だけにします。

## 場所（臓器）を増やすには

1. `godot/src/autoload/stage_db.gd` の `STAGES` に 1 つ追加する（id・名前・既定のミッション・カード・まとめ・クイズ・色）。
2. `blender/stages.py` に `build_<id>()` を書いて `BUILDERS` に登録し、`stage_<id>.glb` を書き出す。
   くだ型なら `tube()` と `path_markers()`、広場型なら `ellipsoid_room()` を使えば短く書けます。
3. よそうの地図に出すなら、`godot/src/autoload/episode_db.gd` の `ORGAN_POS` に、からだの絵の中での位置を足す。
4. `tools/run_tests.sh --stage=<id>` で、場所だけの自動プレイ（既定のミッション）が通るか確かめる。
5. どれかのカルテの `scenes` から使う（使われた場所だけが「ずかん」に出ます）。

ミッションの種類は `defeat` / `collect` / `deliver` / `cheer` / `reach` / `boss` / `gate` / `sequence`（増やさず、文と種類で言いかえる方針）。
新しい敵やなかまを増やすときは `entities/enemy.gd` や `entities/friend.gd` の `CONFIG` に 1 行足し、同じ名前の GLB を置きます。ものしりカードは場所の `cards` に足します。

## 絵と 3D モデルの発注（Codex）

見た目はすべて仮（スクリプト生成）。本番の絵は Codex に発注し、届いた絵をもとに Claude が組み込む。

- 発注書と進め方：`docs/art_orders/README.md`（波 W0〜W4、渡すもの、納品先 `art/concepts/`、修正の出し方）
- Codex に貼る文：`docs/art_orders/codex_prompts.md`（いま出すものは `docs/dashboard.md` 7 章）
- 届いた絵の取り込み：`docs/art_orders/取り込み手順.md`。UI・カードの挿絵は `godot/assets/ui/` に同じ名前の PNG を置くだけで差しかわる
- 状態：`docs/dashboard.md`

## 自動テスト

```bash
GODOT=/path/to/godot tools/run_tests.sh                # 全部
GODOT=/path/to/godot tools/run_tests.sh --episode=ep03 # カルテ 1 本
GODOT=/path/to/godot tools/run_tests.sh --stage=lungs  # 場所 1 つ（既定のミッション）
GODOT=/path/to/godot tools/screenshot.sh guess:ep03 /tmp/guess.png   # スクリーンショット（Xvfb + Mesa が必要）
```

Godot をヘッドレスで起動し、①インポート ②床プローブ（全部の場所の GLB）③全スクリプトの読み込みとデータの検査 ④全カルテを
カルテえらびからカルテまで（画面はフォーカス中のボタンを押して進め、場面は自動操縦）⑤つづきから・ずかん・キー操作 ⑥全部の場所を
既定のミッションで ⑦ダッシュボードの試し作り、の順に動かします。`PROBE RESULT: OK`・`RESULT: OK`・`DASHBOARD: OK` が出て、
`SCRIPT ERROR` が 1 つも無ければ合格です。テストは別のセーブファイルを使うので、手元のセーブは変わりません。

## 効果音と音楽

効果音は numpy で合成しています（外部の音素材なし）。差し替えるときは同じ名前の WAV を `godot/assets/audio/` に置くだけです。

```bash
python3 tools/gen_audio.py
```

音楽（場所・画面ごとの ループ 10 曲と 短い 曲 4 つ）は `tools/music/` の 楽譜から FluidSynth と MuseScore General の 音色で 作ります。
作りなおし方・確認・どこで どの 曲が 鳴るか・ブラウザ版での 鳴らし方は [`docs/audio.md`](docs/audio.md)。
ダッシュボードの「おとを きく」で 1 曲ずつ 聞けます。

## クレジット

- フォント：Rounded M+（M PLUS Rounded 1c）— SIL Open Font License 1.1（`godot/assets/fonts/LICENSE.txt`）
- エンジン：Godot Engine（MIT）
- 音楽の 音色：MuseScore General（MIT。© 2018-2021 S. Christian Collins、Fluid R3 © 2000-2002, 2008 Frank Wen ほか。一部 パブリックドメイン・CC0。全文は `/usr/share/doc/musescore-general-soundfont/copyright`）。曲は このリポジトリで 作った もの（音色の ファイルは コミットしない）。
- それ以外のコード・モデル・音・文章はこのリポジトリで作ったものです。

体のしくみの説明は子ども向けに簡単にしてあります。数字（食道の長さ・肺胞の数など）はおおよその値です。
