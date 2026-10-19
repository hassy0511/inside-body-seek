# からだのなか だいぼうけん（inside-body-seek）

ちいさくなって ともだちの体の中に入り、臓器をひとつずつ たすけながら 体のしくみを学ぶ、子ども向けの 3D ゲームです。
Godot 4.7（GDScript）で動き、3D モデルは Blender の Python スクリプトで生成しています（試作版）。

- 口 → 食道 → 胃 → 小腸 → 血管 → 心臓（右） → 肺 → 心臓（左） → 脳 → 鼻（くしゃみで脱出）の全 10 ステージ（血の流れの順）
- ミッションは「やっつける」だけでなく「あつめる」「とどける」「おうえん」「たどりつく」「じゅんばんをおぼえる」
- ステージ開始・はじめて出会った生き物・クリア後に「ものしりカード」が出て、見たカードは「ずかん」にたまる
- クリア後のクイズに正解すると星がもらえる（各ステージ 3 つ）
- 操作はボタン 2 つ（うごく＋おくすり。ダッシュはおまけ）。ゲームオーバーはなく、チェックポイントから何度でも

企画・設計の詳細は [docs/design.md](docs/design.md) にあります。

## 遊び方

1. [Godot 4.7 以上](https://godotengine.org/download) をインストール
2. Godot のプロジェクトマネージャーで「インポート」→ `godot/project.godot` を選ぶ
3. ▶（F5）で実行

| 動作 | キーボード | ゲームパッド | タッチ |
| --- | --- | --- | --- |
| うごく | 矢印キー / WASD | 左スティック / 十字キー | 左の丸いスティック |
| おくすり（撃つ・おうえん） | スペース / Z / Enter | A | 右の大きいボタン |
| ダッシュ | Shift / X | B | 右の小さいボタン |
| ポーズ | Esc / P | Start | ⏸ |

カメラは自動で追いかけるので、カメラ操作はいりません。船は臓器の「ゆか」の上を浮いて進みます。
おくすりは近くの敵を自動でねらい、なかまはさわるだけで応援できます。
タッチ操作はタッチ画面があると自動で出ます（タイトル画面やポーズ画面で切りかえ可能）。

進み具合（星・ずかん）は `user://save.json` に自動保存されます。

## ファイル構成

| 場所 | 中身 |
| --- | --- |
| `godot/project.godot` | Godot プロジェクト本体 |
| `godot/src/autoload/stage_db.gd` | **ステージ定義**（ミッション・文章・ものしりカード・クイズ）。文章を直すならここ |
| `godot/src/autoload/game.gd` | 画面の流れ（タイトル → ステージえらび → ステージ → けっか）と入力の設定 |
| `godot/src/level/level.gd` | ステージの読み込み・スポーン・ミッション進行・カード表示 |
| `godot/src/player/` | プレイヤー（ホバー船）・カメラ・おくすりの弾 |
| `godot/src/entities/` | 敵・ボス・なかま・アイテム・ゴール・チェックポイント・いえきの池・ぜん動の波・弁・神経 |
| `godot/src/ui/` | HUD・ものしりカード・タイトル・ステージえらび・けっか・ずかん・ポーズ・タッチ操作 |
| `godot/assets/models/characters/*.glb` | キャラクターの 3D モデル（Blender スクリプトの出力） |
| `godot/assets/models/stages/*.glb` | ステージの地形＋スポーン位置（Blender スクリプトの出力） |
| `godot/assets/audio/*.wav` | 効果音と BGM（`tools/gen_audio.py` の出力） |
| `blender/characters.py` | キャラクターを作る bpy スクリプト |
| `blender/stages.py` | ステージの地形とマーカーを作る bpy スクリプト |
| `blender/common.py` | 共通ヘルパー（マテリアル・形・書き出し） |
| `tools/gen_audio.py` | 効果音・BGM を合成 |
| `tools/run_tests.sh` | Godot ヘッドレスで全ステージを自動プレイするテスト |
| `godot/tests/smoke.gd` | その中身（自動操縦でミッション達成までを確認） |

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
| `MK_card_food` | 近づくとカードが出るだけの点（カードは `stage_db.gd`） |

## ステージを増やすには

1. `godot/src/autoload/stage_db.gd` の `STAGES` に 1 つ追加する（id・名前・ミッション・カード・クイズ・色）。
2. `blender/stages.py` に `build_<id>()` を書いて `BUILDERS` に登録し、`stage_<id>.glb` を書き出す。
   くだ型なら `tube()` と `path_markers()`、広場型なら `ellipsoid_room()` を使えば短く書けます。
3. `godot/src/ui/stage_select.gd` の `ORGAN_POS` に、からだの絵の中での位置を足す。
4. `tools/run_tests.sh --stage=<id>` で自動プレイが通るか確かめる。

ミッションの種類は `defeat` / `collect` / `deliver` / `cheer` / `reach` / `boss` / `gate` / `sequence`。
新しい敵やなかまを増やすときは `entities/enemy.gd` や `entities/friend.gd` の `CONFIG` に 1 行足し、同じ名前の GLB を置きます。

## 自動テスト

```bash
GODOT=/path/to/godot tools/run_tests.sh              # 全ステージ
GODOT=/path/to/godot tools/run_tests.sh --stage=lungs # 1 ステージ
```

Godot をヘッドレスで起動し、全スクリプトを読み込んでから、自動操縦で各ステージをクリアまで動かします
（エラーが出たり、時間内にクリアできなければ失敗）。

## 効果音・BGM

```bash
python3 tools/gen_audio.py
```

外部の音素材は使わず、numpy で合成しています。差し替えるときは同じ名前の WAV を `godot/assets/audio/` に置くだけです。

## クレジット

- フォント：Rounded M+（M PLUS Rounded 1c）— SIL Open Font License 1.1（`godot/assets/fonts/LICENSE.txt`）
- エンジン：Godot Engine（MIT）
- それ以外のコード・モデル・音・文章はこのリポジトリで作ったものです。

体のしくみの説明は子ども向けに簡単にしてあります。数字（食道の長さ・肺胞の数など）はおおよその値です。
