# カルテ（1 話）形式の 設計

> 状態：**実装ずみ（マイルストーン 1）**。枠組み ＋ 1〜3 話が `godot/` に 入って いる。この 文書は **できあがった 形**の 説明（コードの 全文は 載せない。ファイルを 見る）。
> 物語は `docs/story.md`（2026-11-12 に OK。9〜10 話の 大きな病気は **はいえん（肺炎）**）。場所は いまの 10 個の GLB と `MK_` マーカーを 変えずに 使って いる。見た目は 仮（絵は あとで 発注する。差しかえ口は 3.5）。
> 4〜10 話は まだ（スケッチは 2.4、作る 手順は 8 章）。設計の レビューで 出た 指摘 26 件の 結果は 7.2。

目次：1 ねらいと用語 ／ 2 データ ／ 3 画面と流れ ／ 4 Level ／ 5 セーブ・ほし・ずかん ／ 6 テスト・CI・ダッシュボード ／ 7 M1 の記録（指摘 26 件の結果）／ 8 ep4〜10 の追加手順 ／ 9 決めたことと リスク

---

## 1. ねらいと 用語

「10 ステージを 順に 遊ぶ」から「**カルテ（1 話）を 1 本ずつ 解く**」へ。1 話 ＝ そうだん → よそう → **からだに はいる**（たびの 画面）→ 場面 1〜3 こ（場面の あとに「あとの はなし」）→ **からだから でる**（たびの 画面）→ カルテ（3 行 ＋ げんいんの タイプ ＋ クイズ ＋ ほし）。
話ごとに かならず 患者の からだに はいって、なおしたら 出る。つぎの 話は べつの 人の からだに もう一度 はいる（1 話の はなちゃんの のどから 2 話の おとうさんの しょくどうへ そのまま 続いて 見えない ように）。

| 用語 | コードでの名前 | 意味 |
|------|--------------|------|
| カルテ（話） | episode、`EpisodeDB.EPISODES` の 1 要素、id は `ep01`… | 1 回の 相談。ほし・解放・ずかんの 単位 |
| 場所 | place ＝ `StageDB.STAGES` の 1 要素（id は `mouth` など） | 臓器。GLB・マーカー・霧の色・ものしりカード・既定の ミッションを 持つ。形も キーも 前の まま |
| 場面 | scene ＝ カルテの `scenes[i]` | 「場所 id ＋ 上書き」。`EpisodeDB.scene_stage()` が 場所の 辞書の 写しに 上書きを 重ね、`Level.setup()` に 渡す |
| 患者 | patient ＝ `EpisodeDB.PATIENTS` の キー（`hana` `kenta` `papa` `jiji`） | そうだんに 来る 人 |
| そうだん | phase `consult`（画面 `talk.gd`） | 患者と ピコの 会話 1〜3 ページ |
| よそう | phase `guess`（画面 `guess.gd`） | からだの地図で 行き先を えらぶ。はずれは ヒントが 出て えらびなおし（しかられない・ほしに 関係なし） |
| たびの 画面 | phase `enter`／`exit`（画面 `journey.gd`） | からだに はいる（よそうの あと）／からだから でる（さいごの あとの はなしの あと）。患者の 名前と 顔・からだの地図の 上の 道・ミクロごうの 動き・ピコの ひとこと |
| 入口・出口 | 話の `enter`／`exit`、`EpisodeDB.ENTRANCES`／`EXITS` | どこから はいって どこから 出るか（くち・おみずで ごくん・はな・きずぐち ／ うがい・げっぷ・くしゃみ・うんち・きずぐち） |
| あとの はなし | phase `after`（画面 `talk.gd`） | 場面の あとの 会話（ボタンで 進む）。「い（胃）は げんき！」の どんでん返しと、さいごの 場面の「ピコッと はっけん！」（種あかし）は これ |
| カルテ画面 | phase `karte`（画面 `karte.gd`） | かいけつ → カルテの 紙（なにが おきていた／どうして／これからは ＋ げんいんの タイプ）→ クイズ → ほし |
| カルテの 紙 | `karte_sheet.gd` | 3 行 ＋ げんいんの タイプ。カルテ画面と ずかんが 同じ ものを 使う |
| げんいんの タイプ | `EpisodeDB.PATTERNS`（A〜F） | 不調の パターン（story.md 3 章）。名前と ひとことを カルテの 紙に 出す（シリーズで 学ぶ こと） |
| つづきから | `SaveData.resume()`、`Game.resume_episode()` | 場面を 1 つ おえる たびに 記録。やめても、おえた 場面の 次から 入れる |
| 場所モード | `Game.start_stage(place_id)` | 場所を 既定の ミッションで 開く。**テストと スクリーンショット専用**（子どもの 画面からは 行けない） |

設計の 原則（迷ったら これ）：

1. **子どもが 詰まらない が 最優先**。ゲームオーバーなし。よそうの はずれは 罰しない。データが まちがっていても ゴールは 開く（4.3）。どの 画面も いつも 何かに フォーカスが ある（3.3）。
2. **話は データだけで 足せる**。Level は「場面の 辞書 1 枚」しか 見ない。話を 知っている コードは `Game`・`EpisodeDB`・`SaveData` と 画面（`ui/`）だけ。`level/`・`entities/`・`player/` は 話を 知らない。
3. **`level.stage_id` は 場所の id の まま**。カードの 既読キー（`stomach/pylori`）、挿絵の 名前（`card_stomach_pylori.png`）、しょくどうの なみが そのまま 動く。
4. **ミッションの 型は ふやさない**。「しらべる」「なだめる」＝ `cheer`、「そうじ」＝ `collect` を、文と 種類（kind）で 言いかえる。型を ふやすと `current_target_position()`・`_nearest_open_target()`・`_fit_missions()`・`autopilot.gd` を 同時に 直す ことに なる。
5. **大事な 文は ボタンで 進む 画面に 書く**。遊んでいる あいだの HUD の 文（`intro`・`each_say`・`done_say`・`goal_say`・`clear_say`）は 時間で 消え、子どもは 操縦しながら 読む。だから HUD には「いま 何を するか」の 短い ひとことだけを 書き、原因の 種あかし・学びは `after`（あとの はなし）と `karte` に 書く（2.2「HUD の 文」）。

---

## 2. データ

### 2.1 ファイル構成

| ファイル | 役目 | おぼえて おく こと |
|---------|------|-------------|
| `godot/src/autoload/stage_db.gd`（`StageDB`） | **場所**の 定義。`STAGES`・`KIND_NAMES`・ものしりカード | `STAGES` の キー・ミッション・数は 前の まま（`tools/build_dashboard.py` の `stages()` と、場所モードの テストが これを 読む）。話の 順番に かかわる もの（`STORY_INTRO`・`next_stage_id()` など）は 消した |
| `godot/src/autoload/episode_db.gd`（`EpisodeDB`、**新規**） | **カルテ**の 定義と 読み出し。`PATIENTS`・`PATTERNS`・`ORGAN_POS`・`ENTRANCES`・`EXITS`・`ROUTE_POS`・`ROUTE_LINKS`・`OPENING`・`ENDING`・`EPISODES`・`scene_stage()`・`journey()`・`validate()`・`text_problems()` | 中身の 地図は 2.3。先頭の コメントに 書きかたの きまり |
| `godot/project.godot` | autoload | `EpisodeDB` は `StageDB` の 次（`SaveData` が `EpisodeDB.ids()` を 使うので `SaveData` より 前） |
| `blender/stages.py`、`godot/assets/models/stages/*.glb` | 場所の 形と マーカー | 変えて いない |

別ファイルに した 理由：`build_dashboard.py` は `stage_db.gd` を `\n\t\t"id": ` で 切って 場所の 表を 作る。同じ ファイルに 話を 入れると こわれる。

きまり：**新しい 知識カード（ものしりカード）は 場所に 足す**（`STAGES[..]["cards"]`）。話ごとに カードを 複製しない。その 生き物が 出ない 場面では `_add_card_point()` が 呼ばれないので、カードも 出ない。話が 持つ カードは カルテ（`epNN/karte`）だけ。

場所の 文の 検査：`validate()` は、**カルテで 行く 場所**（`used_places()`）の ものしりカードと まとめにも 文の きまり（2.2）を かける。1〜3 話で 行く 4 つの 場所は 直して ある。まだ 行かない 場所（けっかん・しんぞう・はい）には 一文字の 臓器名の 書きもらし（「ちは」「ちを」など）が のこって いて、その 場所を 使う 話（ep5・ep8）を 足すと `validate()` が 止めるので、そこで 直す（7.3）。

### 2.2 スキーマ

**EPISODE**（`EPISODES` の 1 要素。1 行目は かならず `"id"`〜`"difficulty"` を この 順で 1 行に 書く）

| キー | 型 | 必須 | 内容 |
|------|----|:---:|------|
| `id` | String | ○ | `"ep01"`…（`"ep%02d" % no`）。セーブ・ずかん・挿絵の キー |
| `no` | int | ○ | 1 から 順番。解放の 順 |
| `title` | String | ○ | だいめい（24 字まで） |
| `patient` | String | ○ | `PATIENTS` の キー |
| `pattern` | String | ○ | 不調の パターン。`PATTERNS` の 記号を「・」で つなぐ（`"A・C"`。1〜2 こ）。**カルテの 紙に「げんいんの タイプ」として 名前と ひとことが 出る**（シリーズで 学ぶ こと）。ダッシュボードにも 出る |
| `difficulty` | int | ○ | 1〜3。カルテえらびの「むずかしさ」 |
| `consult` | Array[LINE] | ○ | そうだん。**1〜3 ページ**（空は だめ：カルテえらびが 1 ページ目を 見せる）。患者が 話さない 話（10 話：ピコの おさらい）も 1 ページは 書く |
| `guess` | GUESS | — | 無ければ よそうを とばす |
| `enter` | ENTER | ○ | からだの 入口（たびの 画面。よそうの あと） |
| `exit` | EXIT | ○ | からだの 出口（たびの 画面。さいごの 場面の `after` の あと、カルテの 前） |
| `scenes` | Array[SCENE] | ○ | 1〜3 こ。同じ 場所を 2 回 使って よい（5 話：はな → はい → はな） |
| `karte` | KARTE | ○ | カルテ画面の 文 |
| `quiz` | QUIZ | ○ | `StageDB` の quiz と 同じ 形 |

（第 1 版に あった `culprit` は やめた。「あたりの よそう」は えらび（CHOICE）の `hit` で 書く。場所の id と くらべると、8 話の ように「地図では しんぞう、場面は けっかん」の 話で 合わなく なる。）

**PATTERNS**（`const PATTERNS`。story.md 3 章）：`記号 → {"name": なまえ（12 字まで）, "msg": ひとこと（30 字まで）}`。A ばいきん・ウイルス ／ B けが ／ C まいにちの くせ ／ D からだの まちがい ／ E ばしょ ちがい ／ F おおきな びょうき。文は `episode_db.gd`。

**LINE**（会話の 1 ページ）：`{"who": "hana" | "pico" | …, "text": "…"}`。`who` は `"pico"` か `PATIENTS` の キー。`text` は 90 字まで、`\n` で 改行。ふきだし（32 px・幅 726）で **6 行まで**（テストが 本物の フォントで はかる）。

**GUESS**

| キー | 型 | 必須 | 内容 |
|------|----|:---:|------|
| `q` | String | ○ | ピコの 問い（40 字まで） |
| `choices` | Array[CHOICE] | ○ | 2〜3 こ。**書いた 順に** 上から ならぶ（まぜない。最初の フォーカスは 1 つめ）。答えの 位置は 話ごとに 変える。同じ `place` を 2 回 書かない |

（しゅっぱつの ひとこと `depart` は 話の `enter.say` に うつした。`guess` に `depart` が あると `validate()` が 止める。）

**ENTER**／**EXIT**：`{"way": "swallow", "say": "おとうさん、おみずと いっしょに ごくん！ ミクロごう、はっしん！"}`

| キー | 型 | 必須 | 内容 |
|------|----|:---:|------|
| `way` | String | ○ | `enter` は `ENTRANCES` の キー（`mouth`・`swallow`・`nose`・`wound`）、`exit` は `EXITS` の キー（`gargle`・`burp`・`sneeze`・`poop`・`wound`）。知らない 名前や 書きわすれは `validate()` が 止める |
| `say` | String | ○ | ピコの ひとこと（60 字まで。たびの 画面の ふきだし 28 px・幅 430 で **5 行まで**）。enter は「だれに 何を して もらって はいるか」、exit は **その 話の さいごの 場所から つじつまが 合う 出かた**（のどの おくで まわれみぎ → うがい、い（胃）の いりぐちまで もどって → げっぷ） |

**ENTRANCES**／**EXITS**（`episode_db.gd` の 定数。入口・出口の 一覧。新しい 出入りを 足す ときだけ 書く）：`"キー": {"at": 点, "out": [外への 道], "fx": しかけ, "name": ふだ, "go": ひとこと}`。

| キー | 内容 |
|------|------|
| `at` | からだの 出入りする 点。`ORGAN_POS` か `ROUTE_POS`（のど `throat`・おしり `bottom`・ひざ `knee`）の 名前 |
| `out` | `at` から 外へ 出る 道（地図の 中の 0〜1。1 を こえて よい）。さいごの 点で ミクロごうが 大きく なる／ちいさく なる |
| `fx` | 出入りの しかけ：`water`（おみずの つぶ）・`open`（おおきく あーん）・`breath`（いき）・`spray`（おみずが ふきだす）・`puff`（くうきの かたまり）・`drop`（ぽとん）・`spark`（きらきら）。`journey.gd` の `_draw_way_fx()` |
| `name` | 画面の ふだ「いりぐち： …」「でぐち： …」（9 字まで） |
| `go` | ミクロごうが 出入りする ときに 地図の 下に 出る ひとこと（18 字まで） |

`"name"` を 先頭に 書かない（`build_dashboard.py` が「`"キー": {"name"`」を 患者と みなす）。

**ROUTE_LINKS**（からだの 中の 道）：となり どうしの 点の 組（`["esophagus", "stomach", [あいだの 点]]`）。入口の `at` から さいしょの 場面の 場所へ、さいごの 場面の 場所から 出口の `at` へは、`EpisodeDB.route()` が この 道を いちばん 少ない 数で たどる。いまの 道：くち・はな → のど → しょくどう → い（胃）→ しょうちょう → おしり、のど → はい、ひざ → けっかん → しんぞう → しんぞう ひだり、しんぞう → はい、けっかん → のう。道が つながらない 組は `validate()` が 止める。

**CHOICE**

| キー | 型 | 必須 | 内容 |
|------|----|:---:|------|
| `place` | String | ○ | `ORGAN_POS` の キー（地図の 位置）。ふつうは 場所 id |
| `go` | bool | — | `true` ＝ これを えらぶと 出発できる。**1 つ 以上 必須**（無いと 行き止まり。`validate()` が 止める）。2 つ あって よい（3 話：い（胃）と しょうちょう） |
| `hit` | bool | — | `true` ＝ ほんとうの 原因に **あたっている** よそう。さいしょに これを えらんだ 子には、かいけつの 画面に「★ きみの さいしょの よそう、あたっていたね！」が 出て、`after.lines_hit` が 使われる。**`hit` は `go` の えらびだけ**（はずれと 言った あとで あたりと 言わない。`validate()` が 止める）。原因が まだ 分からない 話（9 話）は どれにも 付けない |
| `say` | String | ○ | えらんだ ときの ピコの 返事（70 字まで、ふきだしで **4 行まで**）。`go` で ない えらびは「ほめる ＋ ヒント」を 書く |
| `label` | String | — | ボタンの 名前（20 字まで）。無ければ 場所の「なまえ（漢字）」。`heart` を「しんぞう（心臓）」と 出したい とき、場所が まだ 無い とき（ひざ）に 使う |

**SCENE**

| キー | 型 | 必須 | 内容 |
|------|----|:---:|------|
| `place` | String | ○ | 場所 id（`StageDB`）。4 タブで `"place": "…",` を 1 行に 単独で 書く |
| `missions` | Array[MISSION] | ○ | **かならず 書く**（場所の 既定に たよらない）。さいごは `reach` |
| `intro` | String | ○ | 場面の はじめの ピコの ひとこと（**45 字まで**。HUD。「いま 何を するか」） |
| `hints` | Array | ○ | `[{"at": 秒, "text": …, "text_touch"?: …}]`（文は 60 字まで）。**かならず 書く**（無ければ `[]`）。場所の ヒントは 引きつがない：ミッションや 出る ものを 変えた 場面で、合わない ヒントが だまって 出るのを ふせぐ。1 話の そうさ説明も 場面に 書く |
| `arrow` | String | — | `"nearest"` ＝ 矢印が「開いている ミッションの 相手の うち いちばん 近い もの」を 指す（4.3）。無ければ リストの 上から 順。相手が 道ぞいに まざって ならぶ 場面（3 話の しょうちょう）で 使う |
| `spawn` | SPAWN | — | マーカーの 出しかたの 上書き（4.2） |
| `goal_say` | String | — | ゴールが 開いた ときの ひとこと（45 字まで。＝ さいごの 非 reach ミッションが おわった とき）。無ければ「やったね！ ぜんぶ できた！ きいろい わっかの ゴールへ いこう！」。**「ゴールへ いこう」まで**を 書く。種あかしは `after` に |
| `clear_say` | String | — | ゴールに 入った ときの ひとこと（30 字まで）。無ければ「クリア！」 |
| `after` | AFTER | — | この 場面の あとの 会話。無ければ すぐ 次へ。**さいごの 場面には 書く**（「ピコッと はっけん！」＝ 原因の 種あかし。カルテの 前に 出る） |
| そのほか | — | — | 場所の キーは どれでも 上書きできる：`flow_speed`、`bgm`（`"bgm_boss"` など）、`fog`、`ambient` … |
| `reverse` `hide_nodes` | — | — | **予約**（まだ 読む 側が 無い。8 章の ep5・ep4） |

**SPAWN**（マーカー名は `MK_` を 取った 形で 書く。合わせかたは「同じ」または「その 語 ＋ `_` で 始まる」＝ `Level.spawn_rule_matches()`）

| キー | 型 | 内容 | 例 |
|------|----|------|----|
| `skip` | Array[String] | 出さない | `["enemy_pylori"]`（5 ひき 全部）、`["enemy_pylori_4", "enemy_pylori_5"]`（2 ひきだけ）、`["enemy"]`（てき 全部）、`["card_acid"]` |
| `swap` | Dictionary | 種類を 読みかえる。**番号は のこる**：`MK_friend_rbc_2` に `{"friend_rbc_2": "friend_wbc"}` も `{"friend_rbc": "friend_wbc"}` も `MK_friend_wbc_2` に なる。番号の 無い マーカーは そのまま（`MK_boss_boss_virus` → `MK_boss_boss_haien`） | `{"friend_rbc_2": "friend_wbc"}`、`{"boss_boss_virus": "boss_boss_haien"}` |
| `add` | Array | **予約**（GLB に 無い 所へ 出す。8 章の ep5 で 作る。いまは `validate()` が 止める）。1 件に `"after": ミッションの 番号` を 書くと、その ミッションが おわった ときに 出る（ep10 の おくすり） | |

- `player`・`goal`・`path`・`checkpoint` は かえられない（書くと `validate()` が 止め、Level は 無視する）。
- **えいようの マーカーは 番号が 2 つ**：`MK_pickup_nutrient_<しゅるい 0〜2>_<通し番号 1〜6>`。`skip: ["pickup_nutrient_1"]` は「しゅるい 1 の 2 こ（`_1_2`・`_1_5`）」を 消す。通し番号 1 の えいようだけを 消すなら `"pickup_nutrient_0_1"` と 全部 書く。

**MISSION**（`StageDB` と 同じ 形 ＋ 2 つの キー）

| キー | 型 | 内容 |
|------|----|------|
| `type` | String | `defeat`（てきを たおす）`boss` `cheer`（なかまに さわる）`collect`（ひろう）`deliver`（とどける）`gate`（べんを 通る）`sequence`（しんけい）`reach`（ゴール） |
| `target` | String | 種類（`pylori`、`wallcell`、`nutrient` …）。`gate`・`sequence`・`reach` は 不要 |
| `count` | int | 数。出てくる 数より 多いと Level が 切りつめて 警告（4.3） |
| `text` | String | HUD の ミッションの 文（30 字まで） |
| `done_say` | String（任意） | この ミッションが おわった ときの ピコの ひとこと（30 字まで）。無ければ「やったね！「…」クリア！」。**さいごの 非 reach ミッションでは 出ない**（`goal_say` だけが 出る） |
| `each_say` | Array[String]（任意） | 1 つ すすむ たびの ひとこと（i 番目。30 字まで）。さいごの 1 つは 出ない（`done_say`／`goal_say` に なる）。3 話の「しらべる」で 使う |

**AFTER**：`{"banner": "い（胃）は げんき！", "lines": [LINE, …], "lines_hit": [LINE, …]}`。`banner` は 任意（20 字まで）。`lines` は 1〜3 ページ。`lines_hit`（任意。1〜3 ページ）は、さいしょの よそうが `hit` だった 子に `lines` の かわりに 出す（3 話：しょうちょうを えらんだ 子に「きみの よそうどおり」と 言う）。

**KARTE**

| キー | 必須 | 内容 |
|------|:---:|------|
| `thanks` | — | 患者の おれい（かいけつの 画面。60 字まで） |

（出口の ひとこと `exit` は 話の `exit.say` に うつした。`karte` に `exit` が あると `validate()` が 止める。）
| `what` `why` `next` | ○ | 「なにが おきていた？」「どうして？」「これからは？」（それぞれ **62 字まで**。カルテの 紙で 2 行）。`next` には 予防と「びょういんに 行く めやす」を 入れる。紙 全体は 405 px まで（`KarteSheet.MAX_HEIGHT`。テストが はかる） |

**QUIZ**：`{"q", "choices": [3 つ], "answer": 0〜2, "explain"}`（表示の ときに まぜる）。

**文の きまり**（`validate()` が 全部の 文を `EpisodeDB.text_problems()` で 調べる。テストは **画面に 出た ラベルと ボタンの 文**にも 同じ 検査を かける ＝ 画面の 決まり文句も 守られる）：

- 漢字は（ ）の 中だけ。
- わかち書き。かなが 13 字 以上 つづいたら 空白の 入れわすれと みなす（「ミクロしんりょうじょへ」は 11 字で 通る）。
- 一文字の 臓器名は 漢字を そえる：「い」「は」「ち」＋ 助詞（が・の・を・に・は・も・で・へ・と・や）だけの 語（「いが」「はを」「ちの」）を 見つけたら 止める。「はは」「いも」「はで」は 見のがす（`OK_WORDS`）。
- 「〜している」「〜してくれる」「〜してみよう」は つなげて 書く（`stage_db.gd` と 同じ。画面の 見出しも「よそうしてみよう！」）。
- **地図の よそうが はずれた ときの 返事は「いい かんがえだね！」で 始める**（まだ しらべて いないので「しらべかた」とは 言わない）。「いい しらべかた だったよ！」は、場面で しらべた あとの `after` で 使う（story.md 4 章）。
- 画面は「せいかい／ざんねん／ちがった」を **子どもの よそうに 向けて** 言わない。3 話の どんでん返しは「い（胃）は げんき！」「はなちゃんは『きっと い（胃）』と いっていたけど…」と、患者の 思いこみの 話に する。
- 「ピコッと はっけん！」は 原因を 見つけた とき（さいごの 場面の `after` の 見出し）に とって おく。よそうで `go` を えらんだ ときは「うん、〜が あやしいね！」。

**HUD の 文**（`intro`・`each_say`・`done_say`・`goal_say`・`clear_say`・`hints`）：

- 出る 時間は 長さで 決まる：`Level.read_time(text, base)` ＝ `max(base, 字数 × 0.25 秒)`（6〜7 さいは 1 秒に 3〜5 字）。45 字で 約 11 秒。
- 短く：`intro`・`goal_say` は 45 字、`each_say`・`done_say`・`clear_say` は 30 字まで（HUD の ふきだしで 2 行ほど）。
- 物語の ひとこと（`hints` 以外）は、出てから 2 秒は ほかの 文に 上書きされない。その あとは「いえきだ！」の ような とっさの ひとことが 上に 出る ことが ある（4.3）。**だから ここに しか 無い 大事な 話を 書かない**（原則 5）。

### 2.3 `episode_db.gd` の 中身（1〜3 話）

全文は `godot/src/autoload/episode_db.gd`。ここには 地図だけを 書く（文を 直す ときは ファイルを 開く）。

| 部分 | 中身 |
|------|------|
| 先頭の コメント | 書きかたの きまり。`tools/build_dashboard.py` が 正規表現で 読むので 守る：各話の 1 行目は `"id"`〜`"difficulty"` を 1 行に／場面の `"place": "…",` は 4 タブで 単独の 行／`PATIENTS`・`PATTERNS` は `"キー": {"name": "…"` の 形 |
| 定数 | `SEASON_COMPLETE`（10 話 そろったら `true`）、`PATIENTS`、`PICO`、`PATTERNS`、`ORGAN_POS`、`ENTRANCES`・`EXITS`・`ROUTE_POS`・`ROUTE_LINKS`（2.2）、`OPENING`（1 ページ）、`ENDING`、`MISSION_TYPES`、`SPAWN_LOCKED`、`MAX`（文の 長さの 上限）、`OK_WORDS` |
| `EPISODES` | 話の 配列（下の 表） |
| 読み出し | `get_episode(id)`、`ids()`、`next_id(id)`、`scene_count(id)`、`used_places()`、`speaker(who)`、`select_line(ep)`（カルテえらびに 出す 患者の ひとこと）、`patterns(ep)`、`place_label(choice)`、`guess_is_hit(ep, first_guess)`、`after_lines(ep, i, first_guess)`、`scene_stage(ep, i)`、`karte_card(ep)`、`map_point(key)`、`route(a, b)`、`journey(ep, mode)`（たびの 画面の 中身：入口／出口・ひとこと・場所・道） |
| 検査 | `text_problems(text)`（static。文の きまり）、`kanji_outside_paren(text)`、`validate()`（データの まちがいを 文の 配列で 返す。空なら OK）、`validate_episode(ep, no)`（1 話ぶん。テストは こわした 写しも わたす） |

`scene_stage()` が Level に わたす 辞書（これが「場面」の 正体）：

```gdscript
func scene_stage(ep: Dictionary, i: int) -> Dictionary:
	var sc: Dictionary = ep["scenes"][i]
	var st: Dictionary = StageDB.get_stage(sc["place"]).duplicate(true)   # const は 読み取り専用。かならず 写しに 書く
	for k in sc.keys():
		if k != "place" and k != "after":
			st[k] = sc[k]
	st["ep"] = ep["id"]
	st["scene"] = i
	return st
```

1〜3 話（★ ＝ `hit`、○ ＝ `go`）：

| 話 | 患者 | パターン | よそう（書いた 順） | 入口 → 場面（場所：上書き → ミッション）→ 出口 | あとの はなし |
|----|------|--------|----------------|----------------------------|-------------|
| ep01 は（歯）が ズキズキ | hana | A・C | い（胃）／くち（口）★○／はな（鼻） | 入口 `mouth`（おおきく あーん）→ ① mouth：そうさ説明の `hints` → `defeat mushiba 4` → reach → 出口 `gargle`（うがい） | 「ピコッと はっけん！」 |
| ep02 おとうさんの い（胃）が しくしく | papa | A・C | はい（肺）／くち（口）／い（胃）★○ | 入口 `swallow`（おみずで ごくん）→ ① esophagus：reach だけ（かたまりを よける） ② stomach：`defeat pylori 4`・`cheer wallcell 3`（どちらにも `done_say`）→ reach → 出口 `burp`（げっぷ） | ①「てがかり はっけん！」（2 ページ）②「ピコッと はっけん！」 |
| ep03 おなかが いたい…どこ？ | hana | E・C | い（胃）○／しょうちょう（小腸）★○／のう（脳） | 入口 `swallow`（おみずで ごくん。くち → しょくどう → い（胃））→ ① stomach：`skip: ["enemy_pylori"]`、`cheer wallcell 3`（`each_say` で しらべた 結果）→ reach ② intestine：`arrow: "nearest"`、`collect nutrient 6`・`deliver villus 6`・`cheer zendama 3` → reach → 出口 `poop`（うんちと いっしょに） | ①「い（胃）は げんき！」（`lines_hit` あり）②「ピコッと はっけん！」 |

使う マーカー（`blender/stages.py`）：くち `MK_enemy_mushiba_1..4`／しょくどう `MK_checkpoint_1..2`（かたまりは GLB の `FoodChunks`）／い（胃）`MK_enemy_pylori_1..5`・`MK_friend_wallcell_1..3`・`MK_hazard_acid_*`／しょうちょう `MK_pickup_nutrient_*` 6・`MK_deliver_villus_1..2`・`MK_friend_zendama_1..3`・`MK_enemy_akudama_1..3`（たおさなくて よい）。

1〜3 話の 文で 気を つけた 点：

- **どの 話も さいごの 場面に `after`**（見出し「ピコッと はっけん！」）。原因の 種あかしは ここ（ボタンで 進む）と カルテの 紙に ある。`goal_say` は「ゴールへ いこう」まで。`validate()` が さいごの 場面の `after` を 求める。
- **3 話の しょうちょうは `"arrow": "nearest"`**。えいよう（道の 12〜72 %）・じゅうもう（52 %・93 %）・ぜんだまきん（18・45・66 %）が まざって ならぶ。リスト順の 矢印だと ぜんだまきんを 指すのは いちばん おくまで 行った あとで、通りすぎた 子は 流れに さからって もどる ことに なる。ヒントにも「ぜんだまきんにも さわって」と 書いた。
- **3 話は「ちょう（腸）で あくだまきんが ふえた」**と 言う（「しょうちょうで」とは 言わない。9.3）。場面の 場所は しょうちょうの まま。カルテの `next` は「すごく いたい ときや ずっと いたい とき」の 両方。
- **3 話の `after`**：見出しは「い（胃）は げんき！」。はずれたのは はなちゃんの 思いこみ、と 言う。さいしょに しょうちょうを えらんだ 子（`hit`）には `lines_hit`（「きみの よそうどおり」）。
- **2 話の カルテ**：ピロリきんは「きづかない うちに い（胃）に ながく すんでいる ことが ある」（おとなが うつる、とは 言わない）。出口（`exit.say`）は「い（胃）の いりぐちまで もどって、げっぷ」。ミッションの 文は「ゴールの わっかへ いこう」。1 話の 出口は「のどの おくで まわれみぎ → うがい」。
- **1 話の そうさ説明**は 場面の `hints` に ある（場所の ヒントは 引きつがない）。

`validate()` が 見る もの（`tests/smoke.gd` が 1 件ずつ 失敗に する）：id と no が `ep01` から 順／患者と パターンが ある／**`enter`・`exit` が ある・`way` が `ENTRANCES`／`EXITS` に ある・入口から さいしょの 場所、さいごの 場所から 出口への 道が ある・`say` の 長さと きまり**（無い／知らない ときの 文は「ep02: enter が ない。"enter": {"way": <mouth, swallow, nose, wound の どれか>, "say": ピコの ひとこと} を 書く」「ep03: exit.way「rocket」を 知らない。…」）／古い `guess.depart`・`karte.exit` が 無い／`ENTRANCES`・`EXITS` の `name`・`go` の 文と `at` の 点／そうだん 1〜3 ページ／よそうは 2〜3 たく・場所の 重複なし・`ORGAN_POS` に ある・`go` が 1 つ 以上・`hit` は `go` の えらびだけ／場面 1〜3 こ・場所が `StageDB` に ある・`intro` と `hints` を 書く・ミッションの さいごは reach・型は `MISSION_TYPES`・`arrow` は `"nearest"` だけ・`spawn` の キーは `skip`／`swap` だけ・`SPAWN_LOCKED` を 書かない・さいごの 場面に `after`／カルテの 3 行・クイズは 3 たく／全部の 文の 長さ（`MAX`）と 文の きまり／**カルテで 行く 場所**の ものしりカードと まとめの 文の きまり。

### 2.4 4〜10 話の スケッチ（データの 形が 足りる ことの 確認。くわしい 手順は 8 章）

| 話 | 患者 | よそうの `go`（★ ＝ `hit`） | 場面（場所：上書き → ミッション） | まだ 無い もの |
|----|------|------------------------|----------------------------|-------------|
| ep04 ひざを すりむいた | kenta | skin★（`label`「ひざの ひふ（皮膚）」） | ① skin（新）：`collect platelet 6` → `deliver wound 6`・`defeat bacteria 3` → reach ② vessel：`hide_nodes: ["Cholesterol"]`、`skip: ["card_cholesterol", "sign_heart"]`、`swap` で rbc の 一部を wbc に → `cheer wbc 3`（はっけっきゅうを きずへ よぶ）→ reach。**ばいきんは ひふの 場面だけ**（けっかんの 中には 出さない。9.3） | 新しい 場所 `skin`、`deliver` の `item`、`hide_nodes`、kind：bacteria・platelet・wound |
| ep05 せきが とまらない | hana | nose★、lungs | ① nose：`reverse`、`flow_speed: 3.0`、`add` で virus 4 → `defeat virus 3` → reach ② lungs：`cheer wbc 3`・`boss`・reach（文は「はいほうに ひろがる まえに おいだす」。8 章） ③ nose：くしゃみで 出る | `spawn.add`、`reverse` |
| ep06 はなが むずむず | kenta | nose★ | ① nose：`flow_speed: 1.0`、`arrow: "nearest"`、`add` で pollen 5・mihari 3・exit 1 → `cheer mihari 3`（なだめる）・`collect pollen 5`・`deliver exit 5` → reach。てき なし | kind：pollen・mihari・exit、`deliver` の `item`、矢印の collect／deliver の 直し（8 章） |
| ep07 あたまが ぼんやり | papa | brain★ | ① brain：`add` で waste 6（しんけいから 4.5 m 以上 はなす）→ `sequence 3`・`collect waste 6`（そうじ）→ reach。てき なし | kind：waste、`add` の `near`、さいしょの リレーを intro の あとに |
| ep08 かいだんで いきが きれる | jiji | heart★（`label`「しんぞう（心臓）」） | ① vessel（「しんぞうの きんにくへ いく ほそい けっかん」と 言う）：`flow_speed: 2.0`、`skip: ["sign_heart"]` → `cheer rbc 5` → reach ② heart ③ heart2 | なし（データだけ。つづきからは M1 で 作った） |
| ep09 なんか さいきん だるい（前編） | hana | vessel（`hit` なし：原因は まだ 分からない） | ① vessel：`hide_nodes`、`swap` で rbc の 一部を いそぐ wbc に、`add` で clue 3 → `collect clue 3`（`each_say` で 手がかりの ことば）→ reach ② heart：`add` で clue 2 → `gate 2`・`collect clue 2` → reach。さいごの `after` で「おおきな かげ」 | kind：clue・wbc_rush |
| ep10 （後編） | hana | lungs★（`consult` は ピコの おさらい 1 ページ） | ① lungs：`swap` で ボスを `boss_haien`、virus を bacteria に、`add` で medicine 2（`"after": 0` ＝ はっけっきゅうを おうえんし おわると とどく）、`bgm: "bgm_boss"` → `cheer wbc 3`（`done_say`：おくすりが とどいた）・`collect medicine 1`・`boss 1` → reach | Boss の CONFIG 化、おくすりの パワーアップ、`add` の `after`、`SEASON_COMPLETE = true` |

どの 話も「`EPISODES` に 1 件 ＋ Level の 小さな キー 1〜2 こ ＋ kind の 追加」で 入る。画面と 流れ（3 章）は 変えない。場面は どれも `hints` を 自分で 書く。

---

## 3. 画面と 流れ

### 3.1 状態遷移

```
タイトル ─[はじめる]→ カルテえらび(episode_select) ─[しんさつ スタート！]／[さいしょから]→ Game.start_episode(id)
   ▲ ui_cancel／← もどる        ▲  │                ├[つづきから ▶]→ Game.resume_episode() ─→ after[さいごに おえた 場面]へ
   └───────────────────────────┤  │                └[クイズに もういちど]→ Game.review_karte(id) ─→ karte（紙から。もどる で カルテえらびへ）
                                │ ui_cancel／← もどる（1 ページ目の とき）
        consult（talk.gd）──────┘   ※ はじめての ときだけ OPENING 1 ページが 前に つく（読みおえたら 既読）
            │ finished   ▲
            ▼            │ ui_cancel／← もどる（そうだんの さいごの ページへ。カルテえらびまで もどさない）
        guess（guess.gd）           ※ guess が 無い 話は とばす。はずれ → ヒント → えらびなおし（画面は そのまま）
            │ finished(first_guess)
        enter（journey.gd）         からだに はいる：外で ちいさく なる → 入口 → 道 → さいしょの 場所。もどる は 無い
            │ finished
   ┌──▶ scene[i]（Level）           intro（短い ひとこと）→ あそぶ → ゴール。遊ぶ 前に カードは 出さない
   │        │ cleared           ┌── ポーズ「カルテえらびへ」（おえた 場面までは「つづきから」で もどれる）
   │        │                   │   ポーズ「この ばめんを やりなおす」→ 同じ scene[i] を 最初から
   │        ▼ Game._on_level_cleared：ハートの 印と「つづき」を 記録 → [場所の カード（はじめて クリアした ときだけ）]
   │    after[i]（talk.gd）         ※ after が 無ければ とばす。Level は 先に 片づける。さいごの 場面の after ＝「ピコッと はっけん！」
   │        │ finished
   └────────┤ i+1 < 場面の 数
            ▼ さいごの 場面の あと
        exit（journey.gd）          からだから でる：さいごの 場所 → 道 → 出口 → 外で もとの 大きさ → 患者が げんきな 顔
            │ finished
        karte（karte.gd：かいけつ → カルテの 紙 → クイズ → ほし）  ※ 入った ときに クリアを 記録し「つづき」を 消す
            ├─[カルテえらびへ]→ カルテえらび
            └─[つぎの カルテへ ▶]→ start_episode(つぎ)　／　さいごの 話 かつ SEASON_COMPLETE →［エンディングへ ▶］
```

- 流れは 一直線。よそうは 道順を 変えない（分岐の グラフは 作らない）。
- 「画面」と「Level」は 同時に 生きない：画面を 出す 前に かならず `unload_level()`（ポーズは `level != null` の ときしか 開かないので、画面の 上に ポーズは 出ない）。場所の カードだけは、クリアした Level の 上に ポップアップで 出る。
- **はじめて 遊ぶ 子が 動きだす までの ボタン**：しんさつ スタート → OPENING 1 → そうだん 2 → よそう（えらぶ ＋ しゅっぱつ）→ たびの 画面（しらべに いこう）＝ 7 回。
- **入口と 出口は かならず 通る**（話の とちゅうから 入る とき だけ 通らない）：「つづきから」は からだの 中（さいごに おえた 場面の `after`）に もどるので 入口は 出ない。「クイズに もういちど」は カルテだけなので 出口は 出ない。テストと 撮影の `start_episode(id, "scene", n)` も 入口を 通らない。
- BGM：カルテえらび・そうだん・よそう ＝ `bgm_title`。場面 ＝ `stage.get("bgm")`、無ければ `difficulty >= 3` で `bgm_boss`、ほかは `bgm_stage`。enter・after・exit・karte は 鳴っている ものの まま。

### 3.2 `game.gd`（`Game`）

| 名前 | 内容 |
|------|------|
| `signal episode_finished(ep_id, stars)` | カルテ画面を 閉じた とき |
| `signal phase_changed(phase, index)` | フェーズに 入った とき（テストが 順番を 見る） |
| `signal said(text)` | HUD に 文が 出た とき（テストが `goal_say` などを 見る） |
| `signal stage_started(id)`／`stage_finished(id, stars)` | Level を 始めた／クリアした とき（場面でも 場所モードでも）。`stars` は いつも 0 |
| `var episode`／`scene_index`／`phase`／`first_guess`／`_review` | いまの カルテ（空 ＝ 場所モード）、場面の 番号、フェーズ（`consult`／`guess`／`enter`／`scene`／`after`／`exit`／`karte`）、さいしょの よそう、読みかえし中か |
| `show_title()`／`show_episode_select()`／`show_zukan()` | 画面を 出す。前の 2 つは `episode` と `phase` を 空に もどす |
| `start_episode(ep_id, from_phase := "consult", from_scene := 0, guess := "")` | カルテの 入口。うしろ 3 つの 引数は「つづきから」と テスト・撮影用（`start_episode("ep03", "scene", 1)`、`("ep03", "karte")`、`("ep02", "enter")`、`("ep02", "exit", 1)`） |
| `resume_episode()` | つづきから：`SaveData.resume()` の 話を、**さいごに おえた 場面の `after`** から 始める（おさらいに なる。`after` が 無ければ 次の 場面か 出口へ）。入口は 通らない（ミクロごうは もう からだの 中） |
| `review_karte(ep_id)` | クリアずみの カルテの 紙と クイズだけ もういちど（クイズの ほしを 取りなおせる）。出口は 通らない。クリアの 記録も ハートの 印も「つづき」も さわらない |
| `_enter(phase, back := false)` | フェーズの 切りかえは **ここ 1 か所**。データが 無い フェーズ（よそう・あとの はなし・空の そうだん）は 自分で 次へ 進む。`back` は よそうから そうだんへ もどる とき（さいごの ページを 出す） |
| `_after_done()`／`_on_karte_finished(go_next)` | つぎの 場面 or 出口（`exit` → カルテ）へ／つぎの 話 or カルテえらびへ |
| `start_stage(place_id)` | 場所モード（テスト・撮影専用） |
| `_start_level(stage)` | Level と HUD を 作って 始める（`stage` ＝ 場所の 辞書か `scene_stage()` の 辞書） |
| `retry_stage()` | カルテの 中なら いまの 場面だけ やりなおす |
| `_on_level_cleared(place_id, no_damage)` | 場所モード → カルテえらびへ。カルテ → ハートの 印（場面ごと）と「つづき」を 記録 → 場所の まとめを 既読に → 場所の カード（はじめて クリアした ときだけ）→ `_enter("after")` |
| `_set_screen(c)`／`screen()` | 画面を 入れかえる（テーマを 付け、タッチの ボタンを かくす）／いまの 画面（テスト用） |
| `say(text, seconds, hold := 0.0)` | HUD の ひとこと。`hold` ＞ 0 は 物語の ひとこと（4.3）。HUD が 受けとったら `said` を 出す |
| `say_soft(text, seconds)` | おまけの ひとこと（チェックポイント・とどけた）：HUD が あいている ときだけ 出す（ヒントと 同じ きまり） |
| `show_card()` `add_overlay()` `toggle_pause()` `hud_busy()` `show_ending()` | 前から ある もの。`show_ending()` は `SEASON_COMPLETE` の ときだけ 呼ばれる |

流れの きまり（`_enter()` と その まわり）：

- `OPENING` は **読みおえた とき**（そうだんの さいごの ボタン）に 既読に する。1 ページ目で「もどる」を 押した 子には 次も 出る。
- よそうの「もどる」は そうだんの さいごの ページへ（`_enter("consult", true)`）。この とき `phase_changed("consult")` が もう一度 出る。
- クリアの 記録は カルテ画面に **入った とき**（クイズを とちゅうで やめても クリアは のこる）。クイズの ほしは `answered` で 足す。
- **`_on_karte_finished()` は `episode_finished` を 出した あと、同じ 呼び出しの 中で 次の 話の `start_episode()` まで 進む**（＝ `phase_changed("consult")` が 続けて 出る）。テストは `episode_finished` の しゅんかんの フェーズ列を 写して くらべる（6.1）。
- 「つづき」は 1 つだけ（`SaveData.data["resume"]`）。場面を クリアする たびに 書き、その 話の カルテ画面に 入ると 消える。**クリアずみの 話を 遊びなおして いる ときは、ほかの 話（まだ とちゅう）の つづきを 上書きしない**。
- 場所の ものしりカード（`cards.stage`）は、**はじめて クリアした あと**に 1 回 出す（2 話と 3 話で い（胃）の カードが 2 回 出ない）。`Level.begin()` は カードを 出さない。場所モードでは 出ない。
- カルテの 流れの 画面は セーブを 書かない（`karte.gd` の `epNN/karte` の 既読マーク 1 つを のぞく）。記録は `Game` が する。
- 知らない フェーズ名は エラーを 出して カルテえらびへ もどる（止まらない）。

### 3.3 画面の 共通の きまり

カルテえらび・はなし・よそう・たびの 画面・カルテの 5 画面は `src/ui/flow_screen.gd` を 継ぐ。

| 名前 | 内容 |
|------|------|
| `set_focus(c)`／`focus_target` | 子どもが 次に 押す ボタンへ フォーカスを 入れる。`_process` が 見はり、フォーカスが 消えたら `focus_target` に もどす |
| `lock(seconds := 0.4)`／`locked()` | 押しすぎ よけ。ボタンの ハンドラは `if locked(): return` から 始める |
| `make_stage(bg, box := Vector2(1180, 640))` | 全面の 背景 ＋ 画面中央の 固定の 入れ物を 作って 返す。中は 1280×720 の ときの 座標で ならべる |
| `add_heading(text)`／`add_back_button(on_back)` | 上の 見出し（40 px）／左上の「← もどる」 |
| `lines_of(text, font_size, width)`（static） | 文が 何行に なるかを 本物の フォントで はかる（テストが 使う） |

- **フォーカス**：画面の 中身を 作りかえる たびに `set_focus(btn)`。`disabled` に しても フォーカスは のこるが、`focus_mode = FOCUS_NONE` に した 瞬間と、フォーカス中の ノードを `queue_free` した 瞬間に 消える。だから「押せなく する ボタン」は `disabled = true` ＋ `FOCUS_NONE` に して、**同じ 関数の 中で** 別の ボタンへ `set_focus()` する。見はりは 取りこぼしの 保険。
- **フォーカスの となり**（上下左右で 行く 先）は、まかせると 思わぬ ボタンへ とぶ 所だけ 自分で 決める（カルテえらびの 右の パネル、よそうの えらび）。テストの `_check_keys` が 本物の 入力で 行き先を 見る。
- **フォーカスの わく**は こい むらさき（`T.FOCUS`）の 外がわの 輪。黄色い ボタンの 上でも 見える。
- **押しすぎ よけ**：ボタンを `disabled` に しない（色が 変わって ちらつく・フォーカスの 事故の もと）。時間は `_process` の delta で 数える（`Time.get_ticks_msec()` は 使わない。テストは 実時間より ずっと 速く 回る）。
- **入力**：キーボード・ゲームパッドは フォーカス中の ボタンに `ui_accept`、もどるは `ui_cancel`（`_unhandled_input`）。タッチ・マウスは ボタンを 直接。主ボタンと えらぶ ボタンの 高さは 76 px 以上、小さい ボタン（もどる・さいしょから など）は 60 px。
- **時間で 勝手に 進まない**。`Game.testing` でも 自動送り しない（テストは フォーカス中の ボタンを 押して 進める ＝「フォーカスが ある」ことが 毎回 テストされる）。
- **文の 折りかえし**：本文は `T.body()`／`T.nobreak()` を 通す。字の 間に WORD JOINER を はさみ、空白と 句読点の あとでだけ 折れる（「ミクロ／ごう」と 切れない）。`EpisodeDB.text_problems()` は この しるしを 取ってから 調べる。
- `const T`（`ui_theme.gd`）は 土台に ある。継いだ 側で もう一度 書くと エラーに なる。テーマは `Game._set_screen()` が 付ける。

### 3.4 各画面

どれも 1280×720 に 入り、4:3 や 横長でも 中央に まとまる。タッチの ボタンは 画面では 出ない。細かい 座標は 各ファイルの 先頭の 定数。

#### A. カルテえらび `src/ui/episode_select.gd`

- 左：カルテの 行（540×104、スクロール）。患者の 顔（クリアずみは `happy`、まだは `sick`）／「カルテ 1」＋ 小さい ほし 3 つ／だいめい。色は クリアずみ ＝ 黄、開いている ＝ 水色、まだ ＝ 灰色（だいめいは「？？？」、押せない）。下に「つづきの カルテは じゅんびちゅう！」（`SEASON_COMPLETE` で ない あいだ）。左下に「あつめた ほし　2 / 9」。
- 右：えらんだ カルテの パネル（570×580。`_select(id, go_to_start)` が 作りなおす）。患者の 顔（いつも `sick`）・番号・だいめい・「かんじゃさん： …」／そうだんの ひとこと（`EpisodeDB.select_line()`）／「むずかしさ： かんたん」＋ 大きい ほし／主ボタン。
  - 主ボタン：ふつうは「しんさつ スタート！」。その 話に つづきが あれば「つづきから ▶」（上に「ばめん 1 まで おわっているよ」）＋ 小さい「さいしょから」。
  - クリアずみで クイズの ほしが まだの 話には 小さい「クイズに もういちど」（`Game.review_karte()`）。
  - **めぐる 場所と ミッションは 見せない**（よそうの ねたばれ）。
- 最初に えらぶ 話：つづきが ある 話 → まだ クリアして いない 最初の 開いている 話 → 1 話。主ボタンに フォーカス。
- フォーカス：行の 上下で 行を うつる（右の パネルが 入れかわる。フォーカスは うばわない）。行 → 右 ＝ 主ボタン、主ボタン → 左 ＝ えらんだ 行、主ボタン → 下 ＝ 小さい ボタン、小さい ボタンは 左右で うつる。行の 左は 動かない。
- `ui_cancel`／「← もどる」→ タイトル。解放は `SaveData.is_unlocked(id)`（1 話、前の 話が クリア、または `unlock_all`）。
- テストが 見る もの：`selected_id`、`main_btn`、`main_is_resume`、`restart_btn`、`quiz_btn`、`rows`、`fits()`。

#### B. はなし `src/ui/talk.gd`（そうだん・あとの はなし の 両方）

- `setup(lines, opts)`。`opts`：`banner`（上の 見出し）、`last_label`（さいごの ページの ボタン。既定「つぎへ ▶」）、`can_cancel`（最初の ページで もどれるか）、`start_page`（よそうから もどった とき ＝ さいごの ページ）、`mood`（患者の 顔）。シグナル `finished`、`cancelled`。
- 左に 話す 人の 絵（300×400。`T.portrait(who, mood, …, true)` ＝ 全身の 絵を 先に さがす。うしろに 話す 人の 色の 台紙）、右に 名前の ふだ ＋ ふきだし（770×320。文は 32 px・幅 726・**6 行まで**）＋ ページの まる ＋「つぎへ ▶」。ふきだしを タップしても 次へ。
- 見出し（`banner`）は 白い ふだに 青い 字（**赤に しない**。まちがいの 色に 見せない）。出る ときに ぽよん ＋ `Sfx.play("card")`。
- ピコの 顔は、見出しが ある 画面（はっけん）で `happy`、ほかは `normal`。患者は `mood`（いまは いつも `sick`）。
- 背景：`consult_bg.png` が あれば 全面に、無ければ コードで 描く しんりょうじょ（かべ・ゆか・まど）。
- もどる（`ui_cancel`／「← もどる」）：2 ページ目からは 1 ページ もどる（読みなおせる）。1 ページ目は `can_cancel` の ときだけ `cancelled`。
- `Game` からの 呼びかた：そうだん ＝ `can_cancel: true`、`last_label`「よそうする ▶」（よそうが 無い 話は「しゅっぱつ！ ▶」）。あとの はなし ＝ `banner`、`last_label`「つぎへ いこう ▶」（さいごの 場面は「つぎへ ▶」）。
- テストが 見る もの：`lines`、`page`、`text_fits()`（static）、`fits()`。

#### C. よそう `src/ui/guess.gd`

- `setup(ep)`。シグナル `finished(first_guess)`、`cancelled`。見出し「よそうしてみよう！」。
- 左：からだの地図（430×604。絵は 3.5）。えらびごとに 丸い しるし「Ａ」「Ｂ」「Ｃ」（72 px。ピンク・みどり・黄）を `ORGAN_POS` の 位置に 置く。**近すぎる しるしは おしはなして、臓器の 点と 線で つなぐ**（1 話の くちと はな）。しるしは タップできるが、ゲームパッドの 順番には 入れない。
- 右上：ピコの ふきだし（700×212。文は 26 px・幅 540・**4 行まで**）。最初は `guess.q`。
- 右下：えらぶ ボタン（「Ａ　くち（口）」。書いた 順。名前は `EpisodeDB.place_label()`）。フォーカスが 来ると その しるしが 大きく なる。上下だけで 動く（左右は 動かない）。
- はずれ（`go` で ない）：ふきだしが 返事（ほめる ＋ ヒント）に 変わる。その ボタンは 灰色に なり、右に 小さく「かんがえたよ」（ボタンの 文には 足さない：「い（胃）（…）」と かっこが ならぶと 読みにくい）。音は `card`（`wrong` は 使わない）。フォーカスは のこりの 上から 1 つめへ。
- あたり（`go`）：ふきだしは 返事だけ。**えらぶ ボタンを かくし、その 場所に「えらんだ 場所の ふだ ＋ だれの からだに 行くか（`depart_line()`「ミクロごうに のって、おとうさんの からだの なかへ！」。28 px・幅 640・3 行まで）」の 箱**を 出す。地図には えらんだ しるしだけ のこる（色も そのまま）。「しゅっぱつ！ ▶」に フォーカス → `finished(first)` → たびの 画面（3.4 E）。しゅっぱつの ひとこと（`enter.say`）は たびの 画面だけに 出す（2 回 読ませない）。
- 地図は `body_map.gd`（3.5）。絵が 無い 患者は 患者ごとに コードで 描く。
- `first` は さいしょに えらんだ 場所。あたり（`hit`）だったかは `EpisodeDB.guess_is_hit()` が 見る。
- **行き止まりに ならない 理由**：`go` の えらびは 押せなく ならない。はずれは 多くて 2 回。`validate()` が「`go` が 1 つ 以上」を 保証する。
- 画面は「せいかい／ざんねん」と 言わない。ほしにも 入れない。
- テストが 見る もの：`buttons`、`marks`、`choose(place)`、`say_fits()`・`depart_fits()`・`depart_line()`（static）、`fits()`／`overflow()`、`SAY_*`・`DEPART_*` の 定数（箱の 大きさを 変えたら 定数も 直す）。

#### D. カルテ `src/ui/karte.gd`

- `setup(ep, opts)`。`opts`：`guess_hit`、`review`（読みかえし）。シグナル `answered(correct)`、`finished(go_next)`。中央の パネル 940×640。段ごとに 中身を 作りなおし、主ボタンへ `set_focus()`。

| 段（`step`） | 中身 | 主ボタン |
|------------|------|---------|
| 0 かいけつ | 「かいけつ！」／「カルテ 1　だいめい」／患者（`happy`。顔 200 px）の おれい `karte.thanks`（32 px）／（出口の ひとことは 前の たびの 画面に うつした）／`guess_hit` なら「★ きみの さいしょの よそう、あたっていたね！」。`Sfx.play("clear")` | 「カルテを かく ▶」 |
| 1 カルテの 紙 | `SaveData.mark_card(ep_id, "karte")`。`karte_sheet.gd` の 紙：「なにが おきていた？／どうして？／これからは？」＋「げんいんの タイプ」（パターンの 名前の ふだ ＋ ひとこと）。挿絵 `cards/card_<ep>_karte.png` が あれば 左に | 「クイズに ちょうせん！」 |
| 2 クイズ | `ep["quiz"]`。えらびは まぜて「Ａ／Ｂ／Ｃ」で 出す | 1 つめの えらび |
| 3 ほし | `answered.emit(correct)` の あと `SaveData.star_flags()` を 読む。「せいかい！」／「おしい！」＋ ピコの `explain`／ほし 3 つ ＋「ほし 2 こ！」／「● カルテ かんせい！」「● ハートを へらさずに」「● クイズに せいかい」。まだの 行は「○ …」に どうすれば とれるかを そえる：**「（ばめん 2 が まだ）」**（場面が 1 つの 話と クイズは「（また こんど！）」） | 「つぎの カルテへ ▶」→ `finished(true)`（つぎの 話が ある とき。さいごの 話で `SEASON_COMPLETE` なら「エンディングへ ▶」）。となりに いつも「カルテえらびへ」→ `finished(false)` |

- カルテの 紙は 本文 22 px・見出し 20 px（ずかんの ポップアップにも 同じ 紙が 入る 大きさ）。高さは `KarteSheet.MAX_HEIGHT`（405 px）まで。
- 読みかえし（`review`）：段 1 から 始まる。左上に「← もどる」が あり、`ui_cancel` でも カルテえらびへ もどれる（まちがえて 開いた 子が クイズを 通らなくて よい）。ほしの 段は「カルテえらびへ」だけ。
- ふつうの カルテ画面では `ui_cancel` は 何も しない（もどる 先が 無い）。
- テストが 見る もの：`step`、`opts`、`panel`、`quiz_buttons`、`quiz_answer`、`back_btn`、`fits()`。

#### E. たびの 画面 `src/ui/journey.gd`（からだに はいる／でる）

- `setup(ep, mode)`（`mode` ＝ `"enter"`／`"exit"`）。シグナル `finished`。中身は `EpisodeDB.journey(ep, mode)`。
- 見出し：「おとうさんの からだに はいるよ！」／「おとうさんの からだから でるよ！」。
- 左（560×560）：からだの地図（`body_map.gd`。患者の 絵か、患者ごとの 仮の 地図）の 上に、道（これから 行く 道 ＝ 白い 点線、とおった 道 ＝ きいろ）、場所の 輪と 名前の ふだ（「い（胃）」）、ミクロごう（コードで 描く 横から 見た 形。からだの 中では 白い 光の 輪）、出入りの しかけ（`fx`）。下に 動きに 合わせた ひとこと（「ちいさく なあれ……」→ 入口の `go` →「しょくどう（食道）へ すすむよ」→「しょくどう（食道）に とうちゃく！」。exit は「い（胃）から でぐちへ」→ 出口の `go` →「もとの おおきさに もどるよ」→「おとうさん、げんきに なったね！」）。
- 右上（580×210）：患者の 顔（170 px。enter は `sick`、exit は 外に 出た ときに `happy` に かわって ぽよん）・「かんじゃさん」・名前（40 px）・「いりぐち： おみずで ごくん」／「でぐち： げっぷ」の ふだ。
- 右なか：ピコの ふきだし（`enter.say`／`exit.say`。28 px・幅 430・5 行まで）。
- 右下：「しらべに いこう！ ▶」（enter）／「つぎへ ▶」（exit）。**はじめから 出て いて フォーカスが ある**。動きの とちゅうで 押して よい。時間で 勝手に 進まない。`ui_cancel` は 何も しない（もどる 先が 無い）。上下左右でも ボタンから 動かない。
- 動き（`_process` の delta で 数える）：enter ＝ 外で 大きく 出る（0.35 秒）→ ちいさく なる（0.9 秒。きらきら）→ 入口へ（0.8 秒。しかけ）→ 道を すすむ（長さ ÷ 190 px／秒、0.9 秒 以上）→ 場所の 輪が ひかる。exit ＝ 場所で 出る → 道を もどる → 出口から 外へ（0.8 秒。しかけ）→ もとの 大きさ（0.8 秒）・患者が にっこり。音は `pop`・`heal`・`goal_open`・`cheer`。
- テストが 見る もの：`mode`、`ep`、`j`、`button`、`captions()`、`path_points()`、`place_point()`、`say_fits()`（static）、`fits()`／`overflow()`（ふきだし・患者の ふだ・道の 点・下の ひとこと）。撮影用に `freeze_at(割合)`・`rest_time()`。

#### F. そのほかの 画面

| ファイル | いまの 形 |
|---------|---------|
| `pause.gd` | 「つづける」「この ばめんを やりなおす」「カルテえらびへ」。その 話に つづきが あれば 3 つめは「カルテえらびへ（つづきから できるよ）」。パネルは 不透明（うしろの HUD の 文が すけない） |
| `title.gd` | 「はじめる」→ `Game.show_episode_select()`。ほしの 分母は `EpisodeDB.EPISODES.size() * 3`。エンディングの 文は `EpisodeDB.ENDING` |
| `hud.gd` | 題は **患者の 顔 ＋「おとうさんの しょくどう（食道）」**（だれの からだか。`title_text(stage)`。場所モード（テスト）は 場所の「なまえ（漢字）」だけ）。26 px・幅 650 まで（`title_fits()`。テストが 全部の 患者 × 場所で はかる）。番号も 場面の「1 / 2」も 出さない（3 話の ねたばれに なる）。ピコの 顔は `T.portrait("pico", "normal", …)`。`say(text, seconds, hold)` は 出せたら `true` を 返す |
| `card.gd` | カードに `"tag"` が あれば 上の 小さい 見出しに 使う（無ければ「ものしりカード」）。`"karte"`（話の id）が あれば 絵の 列の かわりに カルテの 紙を 出す（ずかんの 読みかえし）。`panel_height()`・`button()` は テスト用 |
| `zukan.gd` | 5.3 |

### 3.5 仮の 見た目と 差しかえ口

`ui_theme.gd`（`T`）の 絵の 口：

| 関数 | さがす 順 |
|------|---------|
| `T.portrait(who, mood, size, color, prefer_full := false)` | （`prefer_full` なら）`<who>_fullbody_<mood>.png` → `<who>_face_<mood>.png` →（ピコだけ）`pico_face_normal.png` → コードで 描く 仮の 絵（ピコ ＝ `draw_pico`、患者の 顔 ＝ `draw_face`、`prefer_full` の 患者 ＝ 顔 ＋ 上半身の `draw_person`） |
| `T.bodymap(who)` | `bodymap_<who>.png` → `body_map.svg`（はなちゃんだけ）→ `null`（`body_map.gd` が コードで 描く）。**ほかの 人の 地図で 代わりに しない**（前は `bodymap_hana.png` に おちて いた。おとうさんの 話で 女の子の 体が 出ると、同じ 子の 中に いる ように 見える） |
| `body_map.gd`（`BodyMap`） | よそうと たびの 画面の 地図。絵 か コードで 描く 仮の 地図：患者の 色の 服。大人（papa・jiji）は えり・ベルト・長ズボン・茶色の くつ・大人の かみがた（おとうさんは 茶色の みじかい かみ・そでを まくった シャツ、おじいちゃんは ふんわりした 白っぽい かみ・カーディガン）、子どもは 半ズボン・はだの ひざ・ほっぺ。体の 配置と 臓器は 4 人 同じ（W1_02 4.3・4.4）。`point(key)`／`to_local_pos(p)` で 地図の 点を 聞く。4 人を ならべた 撮影は `tools/screenshot.sh bodymaps` |
| `T.art(name)`／`T.art_rect(name, size)` | `res://assets/ui/<name>.png` が あれば それ |

`mood`：患者は `sick`／`happy`。ピコは `normal`／`happy`／`surprised`／`worried`（いま 使うのは `normal` と `happy`）。色は `EpisodeDB.speaker(who)["color"]`。

絵を 置くだけで 差しかわる もの（`godot/assets/ui/`）：

| 絵 | 名前 | 使う 画面 | いま |
|----|------|---------|------|
| 患者の 顔 | `<who>_face_sick.png`、`<who>_face_happy.png`（who ＝ hana／kenta／papa／jiji） | カルテえらび・カルテ・ずかん | hana は 納品ずみ。papa・kenta・jiji は 仮の 顔 |
| 患者の 全身 | `<who>_fullbody_sick.png`、`<who>_fullbody_happy.png` | はなし（顔より 先に さがす） | hana は 納品ずみ。ほかは 仮の 上半身 |
| ピコ | `pico_face_<mood>.png`、`pico_fullbody_<mood>.png` | HUD・よそう・カルテ（顔）、はなし（全身 → 顔） | 顔 4 つは 納品ずみ。全身は まだ（顔が 出る） |
| からだの地図 | `bodymap_<who>.png` | よそう・たびの 画面 | 仮の SVG（はなちゃん）と コードの 絵（ほかの 患者。`body_map.gd`） |
| そうだんの 背景 | `consult_bg.png` | はなし | コードで 描く しんりょうじょ |
| カルテの 挿絵 | `cards/card_<ep>_karte.png`（`card_ep01_karte.png`） | カルテの 紙（カルテ画面・ずかん） | 無し（文が 幅 いっぱい） |

絵を 頼む ときの 注意：

- **からだの地図は、臓器が `EpisodeDB.ORGAN_POS`（絵の 中の 0〜1 の 位置）に 来る ように 描いて もらう**。ちがう 体つきの 絵だと しるしが ずれる。位置を 変えるなら `ORGAN_POS` を 直す。
- `bodymap_hana.png` だけが 先に 届いても、ほかの 患者は コードの 仮の 地図の まま（はなちゃんの 体には ならない）。届いた 人から 置いて よい。絵の 中の 外がわ（たびの 画面で ミクロごうが 外に 出る 所、`ENTRANCES`／`EXITS` の `out`）は 透明に して もらう。
- `consult_bg.png` は 落ち着いた 色に（左に 人物、右に ふきだしが 乗る。名前と ページの まるは 白い ふだに のせて ある）。
- 前の ステージえらびに あった 場所の アイコン（`stage_icons/stage_icon_<id>.png`）の 口は、画面ごと 無くなった。出す 場所（よそうの えらぶ ボタンか、ずかんの 見出しか）は まだ 決めて いない。
- 新しい 患者・絵の 口を 足したら、発注書と `docs/dashboard.md` 4 章にも 書く（開発メモの 約束）。

---

## 4. Level（`godot/src/level/level.gd`）

Level は 話を 知らない。`setup()` に わたされた `stage` 辞書（場所の 辞書か、`scene_stage()` の 辞書）を 読むだけ。

### 4.1 場面が 上書きできる キー

`missions`・`intro`・`hints`・`spawn`（`skip`／`swap`）・`arrow`・`goal_say`・`clear_say`・`flow_speed`・`bgm`、そのほか 場所の キー（`fog`、`ambient` …）。`stage_id` は 場所の id の まま。

### 4.2 はじまりと マーカー

- `begin()` は すぐ 遊びはじめ、`intro` を `say_story()` で 出す。カードは 出さない（3.2）。
- `_collect_markers()` が GLB の `MK_*` を 集める とき、場面の `spawn` を マーカー名に かける（`_apply_spawn_rules()`）。ルールは「名前を 読みかえる／出さない」だけで、`_spawn_all()` は 配列しか 見ない。
- 合わせかた ＝ `Level.spawn_rule_matches(key, p)`：「`MK_` を 取った 名前が `p` と 同じ、または `p + "_"` で 始まる」。`swap` は **番号を のこす**（前方一致なら のこり 全部、ぴったり 同じなら さいごの 番号）。`SPAWN_LOCKED`（player・goal・path・checkpoint）は かえられない。
- 合う マーカーが 1 つも 無い ルールは `data_warnings` に 入る（つづりちがいを テストが 見つける）。
- あとで 足す `spawn.add`（8 章）も、この `markers` 配列に 辞書を 足す 形で 入れる。

### 4.3 ミッションの 守りと 文

- **`_fit_missions()`**：出て こない ものを 数える ミッションが あると ゴールが 開かない。`_build_missions()` の さいごに、ミッションの 数を「出る マーカーの 数」に 合わせ、0 なら 外す。合わせた ときは `data_warnings` に 書く ＝ **子どもは 詰まらず、テストは 失敗に なる**。数は マーカーの 配列から 数える（グループからは 数えない：前の Level の ノードは `queue_free` しても フレームの 終わりまで グループに のこる）。
- **HUD の 文の 出る 順**：すすむ たびに `each_say[i]`（さいごの 1 つは 出ない）→ ミッションが おわると `done_say`（まだ ほかに 残っている とき）→ ぜんぶ おわると `goal_say` → ゴールで `clear_say`。`Mission.add()` は `progressed` → `done` → `completed` の 順なので、`each_say` の 条件は `m.current < m.count`。
- **`say_story(text, base)`**：物語の ひとこと（`intro`・`each_say`・`done_say`・`goal_say`・`clear_say`）は ここを 通る。出る 時間は `read_time(text, base)` ＝ `max(base, 字数 × 0.25 秒)`。出てから **2 秒は ほかの 文に 上書きさせない**（`Game.say(…, hold = 2.0)`。HUD が `hold` なしの 文を ことわる）。
- **おまけの ひとこと**（「チェックポイント！」「えいようを とどけた！」）は `Game.say_soft()`：HUD が あいて いる ときだけ 出る。とどけた ときの 文は `m.add()` の **前**に 言う（`add()` の 中で 出る `done_say`／`goal_say` を 上書きしない）。
- **ヒント**（`hints`）は `Game.hud_busy()` を 見て 待つ。やる ことが 全部 おわったら、のこりの ヒントは すてる（「さわってね」と 言われて もどって しまう）。
- **矢印**（`current_target_position()`）：ふつうは ミッションの リストの 上から。`"arrow": "nearest"` の 場面は `_nearest_open_target()` ＝ 開いている ミッションの 相手（てき・なかま・ひろいもの。ポケットに 何か あれば とどけ先も）の うち いちばん 近い もの。
- `mission.gd`：`done_say`（String）と `each_say`（Array）を 読む。

### 4.4 カード

- ものしりカードは 場所の もの（`stage["cards"]`、既読キー `場所id/key`、挿絵 `card_<場所id>_<key>.png`）。
- 出さなかった 生き物の カードは 出ない（`_add_card_point()` は スポーンの ときに 呼ばれる）。`MK_card_acid` の ような 点は のこる（いえきの いけは 3 話でも ある ので 正しい）。点ごと 消すなら `skip: ["card_acid"]`。
- 場所の「きょうの まとめ」（`summary`）は、場面を クリアした ときに 既読に なる（`Game._on_level_cleared`。ポップアップは 出さない。ずかんで 読める）。

### 4.5 変えなかった もの

`_spawn_all()`、しんけいパズル、なみ（`stage_id == "esophagus"`）、プレイヤー、てき、なかま、`autopilot.gd`、`probe.gd`、GLB、`blender/`。ミッションの 型も ふやして いない。

---

## 5. セーブ・ほし・ずかん

### 5.1 `save_data.gd`（`SaveData`。version 2）

```gdscript
{
	"version": 2,
	"episodes": {},        # ep_id -> {"clear": bool, "quiz": bool, "nd": [bool, …]}（nd[i] ＝ 場面 i を ハートを へらさずに クリアした ことが ある）
	"resume": {},          # とちゅうの カルテ：{"ep": id, "cleared": おえた 場面の 数（1〜）, "guess": さいしょの よそう}。無ければ 空
	"cards_seen": [],      # "場所id/key" と "epNN/karte"
	"opening_seen": false,
	"settings": {"volume": 0.8, "touch": "auto", "unlock_all": false},
}
```

- 読みこみは 型を 1 つずつ 確かめる（こわれた JSON・型ちがい・知らない 話の「つづき」は 既定値に）。
- **v1（ステージごとの ほし）や 知らない 版**：設定と 見た カードは 引きつぎ、ほしと クリアは 引きつがない。元の ファイルは `save.v1.json` の ように 写して のこす。
- API：`star_flags(id)`（`[かんせい, ハート, クイズ]`）、`stars(id)`、`scene_flags(id)`、`is_cleared(id)`、`is_unlocked(id)`、`total_stars()`、`record_scene(id, i, no_damage)`、`record_clear(id)`、`record_quiz(id, correct)`、`resume()`／`set_resume(id, cleared, guess)`／`clear_resume(id := "")`、`card_seen()`／`mark_card()`、`setting()`／`set_setting()`、`reset()`。
- `use_path(p)`：テストは `user://save_test.json`、撮影は `user://save_shot.json` を 使う（本物の セーブを さわらない）。

### 5.2 ほし

- カルテごとに 3 つ：① カルテ かんせい ② **全部の 場面で** ハートを へらさずに ③ クイズに せいかい。
- **よそうは ほしに 入れない**（まちがえても しかられない）。
- **ほしの 印は 回を またいで たまる**（1 回 とった 印は 消えない）。ハートの 印は **場面ごと**（`nd[i]`）：ハートが へった 場面だけ、もういちど 遊べば よい。カルテの ほしの 段が「ばめん 2 が まだ」と 教える。
- クイズの ほしは、カルテえらびの「クイズに もういちど」で 取りなおせる（場面を 遊びなおさなくて よい）。
- 「この ばめんを やりなおす」と、その 場面の ダメージは 数えない（子どもに 甘い 側）。
- 合計の 分母は `EpisodeDB.EPISODES.size() * 3`（いまは 9）。

### 5.3 ずかん（`zukan.gd`）

1. **「カルテ」の 段**（いちばん 上）：話ごとに ボタン 1 つ。`epNN/karte` が 既読なら「カルテ 1　は（歯）が ズキズキ」、まだなら「？？？」（押せない）。押すと `CardPopup`（`EpisodeDB.karte_card(ep)`）が カルテの 紙を 出す。ポップアップの 高さは 680 px まで（テストが はかる。いまは 640）。
2. **場所の 段**：`EpisodeDB.used_places()` の 順に、その 場所の カード ＋「きょうの まとめ」。**まだ どの 話にも 出ない 場所は 出さない**（行けない 場所の「？？？」で 分母が ふくらまない）。いまは くち・しょくどう・い（胃）・しょうちょう。
3. 見出しの「（見た 数 / 全部）」は カルテの 段も 数える。

---

## 6. テスト・CI・ダッシュボード

### 6.1 `godot/tests/smoke.gd`

`tools/run_tests.sh` が ヘッドレスで 回す。画面は 1280×720 に 固定する（ヘッドレスの 窓の ままだと たての はみ出しが 見えない）。セーブは `user://save_test.json`。

| 順 | 見る もの |
|----|---------|
| 1 スクリプト | `src/` の 全スクリプトが 読みこめる |
| 2 データ | `EpisodeDB.validate()`／はなし・よそう・**たびの 画面の ふきだし**の 文が 箱に 入る（本物の フォントで 行数を はかる）／入口・出口の 道が 入口の 点と 場所を むすぶ／たびの 画面の 下の ひとことの 文の きまり／**HUD の 題**（患者の 名前で 始まる・1 行に 入る・文の きまり。全部の 患者 × 場所でも はかる。場所だけなら 名前だけ）／**入口・出口を こわした 写し**（`enter` を 消す・`exit` を 消す・知らない `way`・古い `guess.depart`／`karte.exit`）を `validate_episode()` が わかる 文で 止める／`lines_hit` の えらびかた／`spawn` の ルールの 表（境目・えいようの 2 つの 番号・かえられない マーカー）／カルテの 紙の 高さ（挿絵 あり・なし）／`T.portrait()` が 絵と 仮の 顔の 両方を 通る |
| 3 セーブ | v1 からの 移行、こわれた ファイル、型ちがい、ほしの たまりかた、つづき |
| 4 全カルテ | カルテえらびから 始め、**フォーカス中の ボタンを 押して** そうだん → よそう（まず はずれを 1 回）→ **からだに はいる**（動きの とちゅうで 押す）→ 場面（自動操縦）→ **からだから でる** → カルテ（クイズは 話ごとに あたり・はずれを 交互に）→「つぎの カルテへ」。フェーズの 列／場面の クリア数／`data_warnings` が 空／`skip` が きいている／記録／おわった あとに Level と ポーズが のこって いない。画面ごとに 文の きまり・はみ出し・重なりも 見る。たびの 画面は 2 つとも 出たか・患者・入口／出口・道の 始まりと おわり・ひとことと 名前が 出て いるか・ボタンに フォーカス・タッチの ボタンが かくれて いるか。入口・出口の ひとことが ほかの 画面（よそう・カルテ）に 出て いないか。場面ごとに HUD の 題が 患者の 名前で 始まるか |
| 5 そのほかの 道 | タイトル、よそうの「もどる」、あたりの よそう（`lines_hit` と「あたっていたね」）、つづきから（**入口を 通らず** after0 → scene1。場面の やりなおし・ポーズから やめる・クリアずみの 話が つづきを 上書きしない）、クイズの やりなおし（**karte だけ。出口を 通らない**）、ずかん（カルテを 開いて 閉じる）、**本物の 入力**（矢印・決定・もどる の アクション）で 5 つの 画面を 動かして フォーカスの 行き先を 見る（`_check_keys`） |
| 6 全部の 場所 | 10 場所を 場所モードで 自動操縦（カルテで まだ 使わない 場所も ここで 守る）。HUD の 題は 場所の 名前だけ |

- HUD の 文：場面ごとに `intro`・`each_say`・`goal_say`・`clear_say` が 出たか、`goal_say` が 出てから 2 秒の うちに ほかの 文に 上書きされて いないか（`Game.said` を 記録して 見る）。出た 文にも 文の きまりを かける。
- 引数：`--episode=<epNN>`（4 を その 話だけ）、`--stage=<場所id>`（6 を その 場所だけ）。5 は 全部 回す ときだけ。知らない id は 失敗に なる。`--debug` は 2 秒ごとに ミッションの 進みを 出す。
- ログ：`cleared ep03 in 49.0s (sim) …` と `cleared mouth in 17.8s (sim) …`（ダッシュボードの 正規表現 `cleared (\w+) in ([\d.]+)s \(sim\)` に 両方 当たる）。いまの めやす：ep01 約 24 秒／ep02 約 50 秒／ep03 約 49 秒、10 場所で 計 220 秒ほど（sim）。全部で 実時間 1 分 かからない。
- 自動操縦は いえきの いけを よけないので、ハートの ほしは あてに しない。

### 6.2 `autopilot.gd`・`probe.gd`

変えて いない。`probe.gd` は `StageDB.STAGES` の GLB を 全部 調べる。ミッションの 型を 足さない かぎり `autopilot.gd` は 変えなくて よい（8 章の ep06 は 矢印と いっしょに 直す）。

### 6.3 スクリーンショット（`godot/tests/shot.gd`、`tools/screenshot.sh`）

`tools/screenshot.sh <なにを> <出力.png> [--play=秒] [--frames=N] [--touch]`。セーブは `user://save_shot.json`。「,」で ならべると 1 回の 起動で 何枚も 撮る（出力は フォルダ）。

| `<なにを>` | 写る もの |
|-----------|---------|
| `title`、`zukan`、`card`、`pause`、`model:<id>` | タイトル、ずかん（ep01・ep02 クリアずみ）、ものしりカード、ポーズ、キャラクター 1 体 |
| `select_new`／`select`／`resume` | カルテえらび：はじめて／ep01 クリアずみ／つづき ＋ クイズの やりなおし（ボタンが いちばん 多い 形） |
| `opening`、`consult:ep03` | はじめての そうだん（OPENING）、そうだん |
| `guess:ep03`、`guess_wrong:ep01`、`guess_go:ep01` | よそう：えらぶ 前／はずれを 1 回 えらんだ あと／`go` を 押した あと（しゅっぱつの 箱） |
| `enter:ep02`、`exit:ep02` | たびの 画面（からだに はいる／でる）。`+t0`／`+t50`／`+t100` で 動きを その ％ で 止める（無ければ おわり） |
| `bodymaps` | 4 人の からだの地図を ならべる（絵が 無い 人は コードの 仮の 地図） |
| `after:ep03:0` | 場面 0 の あとの はなし |
| `karte:ep03[:n]` | カルテ画面の 段 0（n ＝ 1 紙／2 クイズ／3 ほし） |
| `review:ep02[:n]` | クリアずみの カルテの 読みかえし（紙から。n ＝ 1 クイズ／2 ほし） |
| `zukan_karte:ep02` | ずかんで カルテを 開いた ところ |
| `ep03:1` | 3 話の 2 つめの 場面（＋`--play=秒`） |
| `<場所id>` | 場所モード（＋`--play=秒`） |

しるし（「+」で つなぐ）：`+p<N>`（はなしの N ページ目）、`+hit`（さいしょの よそうが あたりの 子）、`+wrong`（クイズで はずれ）、`+hurt`（ハートが へった 場面が ある）、`+touch`、`+t<N>`（たびの 画面の 動きの ％）。例：`after:ep03:0+hit+p1`、`karte:ep02:3+wrong+hurt`。

`tools/make_screenshots.sh` は 主な 画面と 10 場所を `docs/screenshots/` に まとめて 撮る。CI では 撮らない。

### 6.4 `tools/run_tests.sh`・CI

- 順番：インポート → 床プローブ（`probe.gd`）→ smoke → **ダッシュボードの 試し作り**（`build_dashboard.py` の パーサが こわれたら その 場で 落ちる）。引数（`--stage=`／`--episode=`／`--debug`）は そのまま smoke に わたる。
- 合格：`PROBE RESULT: OK`、`RESULT: OK`、`DASHBOARD: OK`、`SCRIPT ERROR` なし。
- `.github/workflows/test.yml`：push と pull request で `tools/run_tests.sh` を 回し、ログ（`/tmp/inside-body-seek-test.log*`。試し作りの HTML も 入る）を artifact に のこす。main への push の ときだけ、ダッシュボードを 作って `gh-pages` に 出す（テストが 落ちても、その 結果を 出す）。

### 6.5 `tools/build_dashboard.py`

- 元に する もの：`docs/dashboard.md`（1〜4・7 章）、`docs/story.md`（3 行目の `状態：**…**` を 見出しの しるしに 使う）、`episode_db.gd`（カルテの 表）、`stage_db.gd`（場所の 表）、テストの ログ。
- **カルテの 表**（`episodes()`）：話・だいめい・患者・場所・パターン（記号 ＋ `PATTERNS` の 名前）・むずかしさ・自動テスト。**場所の 表**（`stages()`）は 前の まま（`STAGES` の 形を 変えて いないので）。上の 1 行は「自動テスト：カルテ a / b、場所 c / d がクリアまで通る」。
- 正規表現が たよる 書きかたは `episode_db.gd` の 先頭の コメント（2.3）。どの 表も 空なら 止まる。

---

## 7. マイルストーン 1 の 記録

### 7.1 作った もの

| 種類 | ファイル |
|------|---------|
| 新規 | `godot/src/autoload/episode_db.gd`、`godot/src/ui/flow_screen.gd`・`talk.gd`・`guess.gd`・`karte_sheet.gd` |
| 改名して 作りかえ（`git mv`） | `stage_select.gd` → `episode_select.gd`、`result.gd` → `karte.gd` |
| 変更 | `game.gd`、`save_data.gd`、`stage_db.gd`（`STORY_INTRO`・`STORY_ENDING`・`next_stage_id()`・`all_cards()` を 消し、カードの 文を 2 か所 直した）、`level.gd`、`mission.gd`、`hud.gd`、`card.gd`、`pause.gd`、`title.gd`、`zukan.gd`、`ui_theme.gd`、`project.godot`（autoload に `EpisodeDB`）、`tests/smoke.gd`、`tests/shot.gd`、`tools/run_tests.sh`・`screenshot.sh`・`make_screenshots.sh`・`build_dashboard.py`、`.github/workflows/test.yml` |
| 変えて いない | `blender/`、GLB、`autopilot.gd`、`probe.gd`、`entities/`、`player/` |

### 7.2 レビューの 指摘 26 件と 結果

設計の 第 1 版に 出た 指摘（F1〜F26）。「M1」は いまの コードに 入って いる。「8 章」は その 話を 作る ときに やる ことで、手順は 8 章に 書いた。

| # | 指摘 | 結果 |
|---|------|------|
| F1 | とちゅうで やめると 最初から | M1：つづきから（場面を おえる たびに 記録。カルテえらびの 主ボタン、ポーズの ボタンの 文）。テストあり |
| F2 | 3 話の `goal_say` が 同じ フレームで 上書きされる | M1：`say_story()` の 2 秒の 守り、とどけた 文は `add()` の 前に `say_soft()`。テストが 上書きを 失敗に する |
| F3 | よそうの 返事 ＋ `depart` が ふきだしに 入らない | M1：ふきだしは 返事だけ、`depart` は 別の 箱。上限 70／40 字。テストが 行数を はかる |
| F4 | 不調の パターンが 子どもに 見えない | M1：`PATTERNS` と、カルテの 紙の「げんいんの タイプ」（カルテ画面・ずかん） |
| F5 | HUD の 文が 長く、読む 前に 消える | M1：`read_time()`（1 字 0.25 秒）、上限 45／30 字、種あかしは さいごの 場面の `after` へ |
| F6 | 3 話「しょうちょうで あくだまきん」は 正しくない | M1：「ちょう（腸）で」。`next` に「すごく いたい とき」。カードの 文 2 か所 |
| F7 | ハートの ほしが 1 回の 通しで しか 取れない | M1：場面ごとに ためる、「ばめん 2 が まだ」、「クイズに もういちど」（`review_karte`） |
| F8 | 3 話で あたった 子にも「ちがった！」 | M1：見出し「い（胃）は げんき！」、患者の 思いこみと して 言う、`lines_hit` |
| F9 | `culprit` と `go` が 合わない（8 話） | M1：`culprit` を やめ、えらびの `hit`（`go` の えらびだけ）。8 話の 文は 8 章 |
| F10 | 5 話の はいの 場面が はいえんと まぎらわしい | 8 章（ep05）：場面 2 の 文、カルテの `next`、10 話との ちがい |
| F11 | 4 話で ばいきんが けっかんの 中に いる | 8 章（ep04）：ばいきんは ひふの 場面だけ。けっかんは「はっけっきゅうを よぶ」 |
| F12 | 2 話の「おとなの い（胃）に」、出口の つじつま | M1：文を 直した（2.3） |
| F13 | 地図の はずれに「いい しらべかた だったね」「（しらべたよ）」 | M1：「いい かんがえだね！」、灰色 ＋ 小さい「かんがえたよ」 |
| F14 | `validate()` が わかち書きと 一文字の 臓器名を 見ない | M1：`text_problems()`。画面と HUD に 出た 文にも かける。見出しは「よそうしてみよう！」 |
| F15 | 遊ぶ 前の ボタンと 文が 多い | M1：OPENING 1 ページ・読みおえて 既読、場所の カードは クリアの あと、よそうの もどるは そうだんへ |
| F16 | 「つぎの カルテへ」で テストが かならず 落ちる（ブロッカー） | M1：テストは `episode_finished` の しゅんかんの フェーズ列を 写し、次の そうだんが 出た ことも 見る |
| F17 | とどけた 文・チェックポイントの 文が 物語の 文を 消す | M1：F2 と 同じ |
| F18 | 空の そうだんで こわれる | M1：`validate()` が 1〜3 ページを 求める。空でも 先へ 進む。カルテえらびは `select_line()` |
| F19 | カルテえらびと ずかんを テストが 通らない | M1：どの 話も カルテえらびから。タイトル・ずかん・本物の 入力の テスト |
| F20 | ずかんの カルテが 画面から はみ出す | M1：`CardPopup` の カルテ用の 形 ＋ 同じ 紙。高さを テストが はかる |
| F21 | `go` の あとの ふきだしが 入らない・えらんだ ボタンが 灰色 | M1：えらぶ ボタンを かくして しゅっぱつの 箱。えらんだ しるしは 色を のこす |
| F22 | 場面が 場所の ヒントを だまって 引きつぐ | M1：`hints` は 場面で かならず 書く。3 話の しょうちょうに ヒントと `arrow: "nearest"` |
| F23 | `swap` の 番号、えいようの 2 つの 番号、テストの 合わせかた | M1：番号を のこす。`spawn_rule_matches()` を Level と テストが 共用。表の テスト |
| F24 | のうの さいしょの リレーが `intro` を 消す（7 話） | 8 章（ep07） |
| F25 | とどけ先が 1 つだけ 遠い ときの 矢印（6 話） | 8 章（ep06） |
| F26 | ミッションの あとに 物を 出せない（10 話） | 8 章（ep10）：`add` の `"after"` を 予約。`validate()` は 作る まで `add` を 通さない |

### 7.3 まだ 仮の もの・のこって いる こと

- 絵が 無い 患者（papa・kenta・jiji）、からだの地図、そうだんの 背景、カルテの 挿絵は 仮（3.5）。くちと はなの しるしは 顔の 上に 乗る。
- 「つづき」は 1 つだけ。
- HUD の ミッションの 一覧で、長い 文は 数（「0 / 6」）が 次の 行に 折れる（読める。前からの 形）。
- 3 話で しょうちょうを えらぶと、しゅっぱつの 箱の ふだは「しょうちょう（小腸）」の まま、ピコが「まず い（胃）から」と 言う。文を 見なおす ときに 見る（たびの 画面は い（胃）へ 行く）。
- たびの 画面の ミクロごうと 出入りの しかけ（おみずの つぶ・げっぷの くうき など）は コードで 描いた 仮の 絵。からだの地図は はなちゃん（仮の SVG）と、ほかの 3 人（コードで 描く 仮の 地図）で 画風が ちがう。4 人分の `bodymap_<who>.png` が 届けば そろう（W1_02）。
- 1 話は 入口も 出口も くち（場所も くち）なので、からだの 中の 道は 短い（外から くちへ 入る／くちから 外へ 出る だけ）。
- のうの パズルの「ざんねん！ もういちど みてね。」は 場所の 前からの 文（7 話を 作る ときに 見なおす。8 章）。
- けっかん・しんぞう（みぎ・ひだり）・はい の ものしりカードと まとめには、一文字の 臓器名の 書きもらし（「ちを」「ちが」など）が 10 か所あまり のこって いる。その 場所を 使う 話を 足すと `validate()` が 止めるので、そこで 直す。
- テストの すきま（わざと こわしても 通って しまう もの）：ハートの ほし（ノーダメージ）の 数を 確かめて いない。`Level._fit_missions()` の 呼び出しだけを 消しても 気づかない。ヒントが 画面に 出たかを 見て いない。「あたっていたね」は 画面の 文で なく `opts["guess_hit"]` を 見て いる。4〜10 話を 足す 前に ふさぐ。
- そうだん・よそうの 画面で 上や 左を 押すと、フォーカスが「← もどる」に 移る（行き止まりには ならない。スティックの 子が まちがえて もどる ことが ある）。
- 物語の ひとこと（`say_story()`）が 守られるのは 2 秒。長い `goal_say` は 読みおわる 前に、ほかの ひとことで 上書きされる ことが ある（2 話の い（胃）の 場面）。
- 2 話の カルテの「げんいんの タイプ」は A の 文（てあらい・うがい・はみがき）が 出る。ピロリきんには 合いにくいので、文を 見なおす ときに 見る。
- `place` に 無い 名前を 書くと、テストは「StageDB に ない」と 知らせる。遊ぶ 側は その 場面で エラーに なる（テストが 先に 止めるので、子どもには 届かない）。

---

## 8. 4〜10 話の 追加手順

作る 順は story.md 9 章と 同じ：**ep5 → ep8 → ep7 → ep6 → ep4 → ep9 → ep10**（前の 話で 作った しくみを 次が 使う）。データだけで 入る ep8 を 先に しても よい。

どの 話も 共通で：

1. `EPISODES` に 1 件 足す（2.2 の 形。1 行目の 書きかたを 守る）。`hints` と、さいごの 場面の `after` を わすれない。原因に あたる えらびに `hit`。
   **入口と 出口**も かならず 書く（`guess` の 次に `enter`、`scenes` の 次に `exit`。どちらも 1 行）：
   ```gdscript
   "enter": {"way": "nose", "say": "はなちゃん、おおきく いきを すって！ ミクロごう、はなから はっしん！"},
   ...（scenes）
   "exit": {"way": "sneeze", "say": "はなの おくまで もどって…… はっくしょん！ くしゃみに のって そとへ！"},
   ```
   - `way` は 2.2 の `ENTRANCES`／`EXITS` から えらぶ。入口は「さいしょの 場面の 場所へ 行ける 所」、出口は「さいごの 場面の 場所から もどれる 所」に する（はなから はいって い（胃）へ は 行けない。道は `ROUTE_LINKS`。つながらないと `validate()` が 止める）。
   - `say` は ピコの ひとこと 1 つ（60 字まで）。enter は 患者への 声かけ ＋「ミクロごう、はっしん！」、exit は 出かたを 体の 事実に 合わせて（うがい・げっぷ・くしゃみ・なみだ・あせ・きずぐち・うんち。story.md 2 章）。
   - 合う 入口・出口が 無い ときは `ENTRANCES`／`EXITS` に 1 件 足す（`at` は 地図の 点、`out` は 外への 道、`fx` は いまの しかけから えらぶ。新しい しかけは `journey.gd` の `_draw_way_fx()` に）。道が 足りなければ `ROUTE_LINKS`（と 臓器で ない 点なら `ROUTE_POS`）に 足す。
2. 新しい 場所・人が 地図に 出るなら `ORGAN_POS`、患者なら `PATIENTS`。
3. `tools/run_tests.sh --episode=epNN` → 全部。`validate()` が 文の 長さ・きまり・その 場所の カードの 文を 見る。テストは `EpisodeDB.ids()` を 回るので、足した 話は 自動で 対象に なる。
4. `tools/screenshot.sh` で そうだん・よそう（はずれ・あたり）・**たびの 画面（`enter:epNN+t0`・`+t50`・`enter:epNN`、`exit:epNN` も 同じ）**・あとの はなし・カルテの 4 段を 撮って 見る。
5. 仮モデルを 作るのと 同時に 発注書へ（`docs/art_orders/`：患者は `W1_02`、てき・なかまは `W2_04`、小物は `W2_03`、場所は `W3_01`、カードと カルテの 挿絵は `W4_02`）。`docs/dashboard.md` と `docs/progress.md` を 更新。

新しい しくみを 足す ときの 受け口（いまの コード）：

- **場面の キー**（`reverse`・`hide_nodes` など）：Level が `stage.get()` で 読むだけ。`validate()` は 場面の 知らない キーを 止めない（場所の キーは 何でも 上書きできる）ので、読む 側を 書いたら 2.2 の 表に 足す。
- **`spawn.add`**：`validate()` が `spawn` の キーを `skip`／`swap` だけに して いる。作る ときに `add` を 通し、`tests/smoke.gd` の `_check_spawn_rules` に 例を 足す。
- **ミッションの 型は ふやさない**。ふやすなら `MISSION_TYPES`・`_fit_missions()`・`current_target_position()`・`_nearest_open_target()`・`autopilot.gd` を 同時に 直す。
- **新しい kind**：`Enemy.CONFIG`／`Friend.CONFIG`／`pickup.gd`、`StageDB.KIND_NAMES`、`ModelLib.PLACEHOLDER_COLORS`、`blender/characters.py` の `BUILDERS`、ものしりカードは 場所の `cards` に。

### ep05「せきが とまらない」（はな → はい → はな）

- **データ**：① `{"place": "nose", "reverse": true, "flow_speed": 3.0, "spawn": {"skip": ["card_sneeze"], "add": [{"mk": "enemy_virus", "path": 0.35, "side": 1.5}, … 4 つ]}, missions: defeat virus 3 → reach}` ② lungs：`cheer wbc 3`・`boss 1` → reach ③ nose（くしゃみで 出る）。よそう：nose が `go` ＋ `hit`、lungs も `go`。
- **文（F10）**：かぜは はなと のどで ふえる 話。はいの 場面は「はいほうに すみついた」と 言わない。場面 ② の `intro` は「ウイルスが はい（肺）の いりぐちまで きた！ ひろがる まえに おいだそう！」（39 字）。長い 説明は 場面 ① の `after` に。カルテの `next` に「せきや ねつが ながく つづく ときは、おとなに いって びょういんへ いこう。」（9〜10 話の 前ふり）。場所の 既定の `intro`（「ここは はいほう。かぜウイルスだいおうが いる！」）は 場面の `intro` が 上書きするので 出ない。はいの ものしりカードは 5 話と 10 話の 両方で 出るので、どちらの 話でも 正しい 文の ままに する（いまは「はい（肺）は いきを する ところ」で、どちらにも 合う）。
- **入口・出口**：入口 `nose`、出口 `sneeze`（どちらも はなの 場所から つながる）。
- **コード**（`level.gd`）：
  - `spawn.add`：`_ready()` の `_build_path()` と `_spawn_all()` の 間に `_add_spawns()`。1 件ごとに `markers.append({"node": null, "kind": …, "rest": […], "name": "MK_<mk>_a<i>", "position": pos, "basis": Basis.IDENTITY})`。`pos` は `"path": 0.35`（道の 割合 ＋ 右へ `side` m）か、`"near": "neuron_2", "offset": Vector3(3, 0, 2)`（いまある マーカーの そば。ep7）。`mk` の 1 語目は `enemy`／`friend`／`pickup`／`deliver` だけ。`_fit_missions()` は `markers` を 数えるので そのまま 効く。
  - 床の 検査：GLB に 無い 点は `probe.gd` が 見ない。Level が 始まって 0.5 秒後、`add` した 点の 真下に ゆかが あるかを 調べ、無ければ `data_warnings`（テストが 失敗に する）。
  - `reverse`：`MK_player` と `MK_goal` の 位置を 入れかえ、`_build_path()` で 点の 順を 逆に、`_spawn_player()` は 道の 向きを 使う。
- **仮モデル・発注書**：なし（virus・boss_virus は ある）。

### ep08「かいだんで いきが きれる」（けっかん → しんぞう みぎ → しんぞう ひだり）

- **データだけで 入る**（つづきからは M1 で 作った）。① vessel：`flow_speed: 2.0`、`skip: ["sign_heart"]`、`cheer rbc 5`「せっけっきゅうを とおしてあげよう」→ reach（あぶらの かたまりは GLB の `Cholesterol` と `MK_card_cholesterol` が そのまま 使える）② heart ③ heart2（`gate 2` → reach）。
- **よそうと 文（F9）**：えらびは `{"place": "heart", "label": "しんぞう（心臓）", "go": true, "hit": true, …}`。せまく なって いるのは しんぞうの きんにくに さんそを とどける ほそい けっかん なので、「しんぞう」が あたり。場面 ① は **からだから しんぞうへ もどる 血の 話に しない**：`intro`「しんぞうの きんにくへ いく ほそい けっかん。せっけっきゅうを とおそう！」（38 字）、ミッションの 文も 場面で 書く（場所の「しんぞうの いりぐちへ いこう」を 使わない）。カルテの `next` で「なおすのは おいしゃさんと、まいにちの しょくじと うんどう」と はっきり 言う（story.md 8 章）。
- けっかん・しんぞうの カードの 文の 書きもらし（7.3）を ここで 直す。おじいちゃんの 絵は `W1_02`。

### ep07「あたまが ぼんやり」（のう。てき なし・そうじ）

- **データ**：① brain：`"spawn": {"add": [{"mk": "pickup_waste", "near": "neuron_1", "offset": Vector3(5, 0, 2)}, … 6 つ]}`、`sequence 3`「しんけいの リレーを てつだおう」・`collect waste 6`「のうの ごみを かたづけよう」→ reach。種あかし（「ばいきんは いなかった。ねぶそくで そうじが おわっていなかった」）は `after` に。
- **コード（F24）**：のうでは `MK_player` が しんけいの まん中に あり、さいしょの リレーが 1 フレーム目に 始まって `intro` を「よく みてね！」で 消す。**さいしょの 回は `intro` が 出て いる あいだ 始めない**（`level.gd` の リレーを 始める 条件に `not Game.hud_busy()`、または 場面の キー `"sequence_delay": 秒`）。ごみは しんけいから **4.5 m 以上** はなす（ひろう ときに しんけいに さわって リレーを こわさない）。
- `pickup.gd` を 種類ごとの `CONFIG` に（`"nutrient": {"pocket": true}`、`"heart_item": {"heal": 1}`、`"waste": {}` ＝ ひろうと 消えるだけ）。`KIND_NAMES`・`PLACEHOLDER_COLORS` に `waste`。brain の `cards` に `"waste"`。リレーを まちがえた ときの「ざんねん！」は「おしい！」などに 見なおす。
- **仮モデル**：`waste`（灰色の もやもや玉）。**発注書**：`W2_03`（waste）、`W4_02`（`card_brain_waste.png`）。

### ep06「はなが むずむず、でも かぜじゃない」（はな。てき なし・なだめる）

- **データ**：① nose：`flow_speed: 1.0`、`arrow: "nearest"`、`add` で `pickup_pollen` 5・`friend_mihari` 3・`deliver_exit` 1（`"path": 0.93`）。`cheer mihari 3`「みはりの さいぼうを なだめよう」（`each_say`：「かふんは てきじゃ ないよ。おちついて！」）・`collect pollen 5`・`{"type": "deliver", "target": "exit", "item": "pollen", "count": 5, "text": "かふんを そとへ はこぼう"}` → reach。
- **コード**：`deliver` の 一般化 ― ミッションに `item`（既定 `"nutrient"`）、`deliver_zone.gd` の `"nutrient"` 固定を `accepts` に、`_on_delivered()` の「えいようを とどけた！」を ミッションの `each_say`／`done_say` に まかせる、HUD の ポケット表示を `StageDB.kind_name()` で、`_fit_missions()` の `deliver` を `item` で 数える。`Friend.CONFIG` に `"mihari": {"radius": 0.9, "move": "static", "panic": true}`。
- **矢印と 自動操縦（F25）**：とどけ先が 道の おく（93 %）に 1 つだけ なので、「ポケットに 何か あれば とどけ先へ」の ままだと、1 つ ひろう たびに おくまで 行って もどる ことに なる。`current_target_position()` の `collect`、`_nearest_open_target()` の `deliver`、`autopilot.gd` を、**「その 種類の ひろいものが もう 無い」か「ポケットに のこりの 数が そろった」ときだけ とどけ先を 指す**に 直す。`deliver` の 枝の ひろいもの さがしは ミッションの `item` で しぼる。直したら しょうちょう（場所モードと 3 話）の 秒数を はかりなおす。
- **仮モデル**：`pollen`、`mihari`、`exit`（いまの ゴールの わっかの 色ちがいで 代用）。**発注書**：`W2_04`（mihari）、`W2_03`（pollen・exit）、`W4_02`（`card_nose_pollen.png`・`card_nose_mihari.png`）。

### ep04「ひざを すりむいた」（ひふ（新）→ けっかん）

- **データ**：`StageDB.STAGES` に 場所 `skin`（`"id": "skin", "order": 11, "name": "ひふ", "kanji": "皮膚", "env": "stage_skin", "kind": "arena"`、既定の ミッション ＝ 下の ①、`cards`：stage・platelet・bacteria・scab、`summary`、`quiz`）。`ORGAN_POS["skin"] = Vector2(0.43, 0.86)`（ひざ）。① skin：`collect platelet 6` → `{"type": "deliver", "target": "wound", "item": "platelet", "count": 6}`・`defeat bacteria 3` → reach ② vessel：`"hide_nodes": ["Cholesterol"]`、`"spawn": {"skip": ["card_cholesterol", "sign_heart"], "swap": {"friend_rbc_2": "friend_wbc", "friend_rbc_4": "friend_wbc", "friend_rbc_6": "friend_wbc"}}`、`cheer wbc 3`「はっけっきゅうを きずへ よぼう」（`each_say`：「きずの ところへ いそいで！」）→ reach「ひざの きずの ほうへ いこう」。
- **事実（F11）**：**ばいきんは ひふの 場面だけ**。けっかんの 中に ばいきんを 出さない・たおさない（血の 中を しんぞうへ 流れる ばいきんは、すりきずとは べつの 重い 病気）。けっかんの 場面は「おうえんを よびに 行く」だけで、ゴールも しんぞうへ 向かう 話に しない。あかく あつく なるのは たたかって いる しるし、と カルテに 書く。
- **コード**：`blender/stages.py` に `build_skin()` と `BUILDERS["stage_skin"]`（マーカー：`MK_player`、`MK_goal`、`MK_path_00N`、`MK_pickup_platelet_1..6`、`MK_deliver_wound_1`、`MK_enemy_bacteria_1..4`、`MK_pickup_heart_item_1`）。`Enemy.CONFIG` に `bacteria`、`pickup.gd` に `"platelet": {"pocket": true}`。`hide_nodes`：`_load_env()` で `_ensure_collisions()` の 前に `env.find_child(name)` を `free()`。`probe.gd` と テストの 場所の 回は `STAGES` を 回るので 自動で 対象に なる。
- **入口・出口**：入口 `wound`（ひざの きずぐち）。いまの `wound` の `at` は 道の 点 `knee`（`ROUTE_POS`、ひざ）なので、`ORGAN_POS["skin"]` を 足す ときに `ROUTE_LINKS` に `["knee", "skin"]` を 足すか、`wound` の `at` を `"skin"` に かえる（`validate()` が 道の 有る・無しを 見る）。出口は けっかんの 場面の あとなので、もどる 道の ある `wound` か、出口を 1 つ 足す。
- **仮モデル**：`stage_skin.glb`、`bacteria`、`platelet`、`wound`。**発注書**：`W3_01`（ひふ）、`W2_04`（bacteria）、`W2_03`（platelet・wound）、`W4_02`（`card_skin_*.png`）、けんたくんは `W1_02`。

### ep09「なんか さいきん だるい（前編）」（けっかん → しんぞう みぎ。手がかりあつめ）

- **データ**：どの えらびにも `hit` を 付けない（原因は まだ 分からない）。① vessel：`hide_nodes`、`swap` で rbc の 一部を `friend_wbc_rush` に、`add` で `pickup_clue` 3。`{"type": "collect", "target": "clue", "count": 3, "text": "てがかりを さがそう", "each_say": ["はっけっきゅうが いそいでいるね。どこへ いくんだろう？", …]}` → reach ② heart：`add` で clue 2、`gate 2`・`collect clue 2` → reach。さいごの `after`：`banner`「つづく……」＋「はい（肺）の ほうに おおきな かげが……」。カルテは「まだ わからない。てがかりは はい（肺）を さしている」「ねつが つづく ときは がまんしないで おとなに いおう」。
- **コード**：`pickup.gd` に `"clue": {}`、`Friend.CONFIG` に `"wbc_rush": {"radius": 0.9, "move": "flow", "model": "wbc"}`。新しい ミッション型は いらない（手がかりの ことばは `each_say`）。
- **仮モデル**：`clue`（ひかる むしめがね）。**発注書**：`W2_03`。

### ep10「（後編）」（はい。はいえんの ボス）

- **データ**：`consult` は ピコの おさらい 1 ページ（`who: "pico"`。5 話との ちがいを 言う：「こんどは ばいきんが はいほう（肺胞）の なかまで ひろがっているんだ。」）。よそう：lungs が `go` ＋ `hit`。① lungs：`"bgm": "bgm_boss"`、`"spawn": {"swap": {"boss_boss_virus": "boss_boss_haien", "enemy_virus": "enemy_bacteria"}, "add": [{"mk": "pickup_medicine", …, "after": 0}, … 2 つ]}`、`cheer wbc 3`（`done_say`：おくすりが とどいた）・`collect medicine 1`・`boss 1` → reach。`SEASON_COMPLETE = true`、`ENDING` の 文を 仕上げる。
- **`add` の `"after"`（F26）**：`"after": ミッションの 番号` を 書いた 物は、その ミッションが おわった ときに 出す（はっけっきゅうを おうえんし おわると おくすりが とどく）。最初から 置くと、先に ひろった 子に「とどいたよ」と 言う ことに なる。`_fit_missions()` は あとから 出る 物も「出る」と 数える。
- **コード**：`boss.gd` の 固定値を `Boss.CONFIG[kind]`（HP、速さ、ひらく／とじる 秒、手下の 種類と 数、`needs_power`）に。種類は マーカーから 取り、`level.gd` と `friend.gd` の `"boss_virus"` 固定を `is Boss` に。おくすり：`pickup.gd` に `"medicine": {"power": true}`、`player.gd` に `powered`（**その 場面の あいだ ずっと**。時間切れを 作らない ＝ 取りなおしで 詰まらない）。`needs_power` の ボスは `powered` で ない 弾を はじき、ピコが「まだ きかない！ おくすりの カプセルを とろう！」。5 話の ボスと 見た目・しくみを はっきり 変える（story.md 7 章）。lungs の `cards` に `haien`・`medicine`（「ばいきんの はいえんには こうせいぶっしつが きく。ウイルスには きかない」）。
- **仮モデル**：`boss_haien`、`medicine`。**発注書**：`W2_04`（ボス）、`W2_03`（medicine）、`W4_02`（`card_lungs_haien.png`・`card_lungs_medicine.png`）。

---

## 9. 決めたことと リスク

### 9.1 決めたこと

| # | 決めたこと | 理由 |
|---|-----------|------|
| 1 | 話は 新しい autoload `EpisodeDB`（別ファイル）。`STAGES` は 変えない | ダッシュボードの パーサ、挿絵・既読の キーが そのまま |
| 2 | よそうは「`go` を えらぶ まで えらびなおし」。道順は 変えない、ほしに 入れない | 「まちがえても ヒントが ふえるだけ」に いちばん 近く、症状から 場所を 考える 意味が のこる。3 たくなので 多くて 3 回で 進む |
| 3 | 場面の あいだは `talk.gd`（Level を 片づけてから 全画面）。そうだんと 同じ 画面 | 画面が 1 つで 済む。「画面か Level の どちらか 1 つだけ」に すると、タッチの ボタン・HUD・ポーズの 重なりを 考えなくて よい |
| 4 | 画面は `Game.testing` で 自動送り しない。テストが フォーカス中の ボタンを 押す | 「いつも フォーカスが ある」を 毎回 自動で 検査できる |
| 5 | スポーンの 上書きは `skip`／`swap`（マーカー名の 読みかえ）。`add` は ep5 で 作る | 名前を 読みかえる だけなので `_spawn_all()` を 触らない。M1 の 3 話は いまの マーカーで 足りる |
| 6 | ミッションの 型は ふやさない（しらべる・なだめる ＝ `cheer`、そうじ ＝ `collect`）。`each_say`／`done_say`／`goal_say`／`clear_say` で 言いかえる | 型を ふやすと 矢印・守り・自動操縦を 同時に 直す ことに なる |
| 7 | ほしは 印を **回を またいで ためる**。ハートは 場面ごと | 1 話が 10〜15 分。1 つ 取りそこねた だけで 全部 やりなおしは きびしい |
| 8 | 「つづきから」は M1 から。記録は 1 つ | 2 場面の 話でも、やめたら 最初からは つらい（F1）。1 つなら セーブも 画面も 小さい |
| 9 | テストは 全カルテ ＋ **全 10 場所**（場所モード） | 規則が 1 つで、`--stage=mouth` が そのまま 生きる。まだ 使わない 場所も 守れる |
| 10 | ダッシュボードは `episode_db.gd` を 正規表現で 読む ＋ `run_tests.sh` で 毎回 試しに 作る | テストログが 無くても 表が 出る。こわれたら テストで 分かる |
| 11 | ずかんは「カルテの 段 ＋ 使った 場所の 段」 | 知識カードは 場所の もの（2 話と 3 話が 同じ い（胃）の カードを 使う） |
| 12 | 矢印は ふつう リスト順。まざって ならぶ 場面だけ `"arrow": "nearest"` | 3 話の しょうちょうで、通りすぎた 子が 流れに さからって もどらない（F22） |
| 13 | HUD の 題は「患者の 顔 ＋ 患者の 名前の 場所」（場面の 数は 出さない） | だれの からだか 分かる（1 話の あと 2 話の しょくどうが はなちゃんの 中に 見えた）。場面の 数は 3 話の ねたばれ。幅は 650 px まで 広げた |
| 18 | 話ごとに 入口と 出口の たびの 画面（`journey.gd`）を 1 回ずつ 通る。入口・出口は データ（`enter`／`exit`）、道は `ROUTE_LINKS` | 「なおしたら 出て、つぎの 人に また はいる」を 目で 見せる（文 1 つだと 読みとばされる）。つづきから・クイズの やりなおしは 通らない |
| 19 | 絵の 無い 患者の からだの地図は ほかの 人の 絵で 代わりに しない（コードで 描く 仮の 地図） | おとうさんの 話で 女の子の 体が 出ると、同じ 子の 中に 見える |
| 14 | 場所の カードは はじめて クリアした あとに 1 回。「まとめ」は クリアで 既読に（ポップアップなし） | 遊ぶ 前の ボタンを へらす。内容は ずかんで 読める |
| 15 | はじめての 1 回だけ `OPENING`（1 ページ）を そうだんの 前に | 「ミクロしんりょうじょの 見習い」の 設定を 伝える 場所が 要る |
| 16 | 大事な 種あかしは HUD に 書かず、`after` と カルテに | HUD の 文は 時間で 消え、子どもは 操縦しながら 読む（F5） |
| 17 | CI で スクリーンショットを 撮らない | 入れるなら 持ち主に 聞いてから |

### 9.2 リスクと 守り

| リスク | 守り |
|-------|------|
| 場面の データの まちがいで ゴールが 開かない | `_fit_missions()` ＋ `data_warnings` を テストで 失敗に ＋ `validate()` |
| よそうで 行き止まり | `go` の ボタンは 押せなく ならない。`validate()` が `go` を 1 つ 以上 求める |
| 画面で フォーカスが 消えて ゲームパッドの 子が 止まる | 作りかえの たびに `set_focus()`、`flow_screen.gd` の 見はり、テスト（フォーカス中の ボタンを 押す ＋ 本物の 入力） |
| 古い セーブで 落ちる・合計が 狂う | version 2 への 移行 ＋ 型の 検査 ＋ テスト。**前の ほしは 0 に もどる。ずかんと 設定は のこる** |
| テスト・撮影が 本物の セーブを 書きかえる | `SaveData.use_path()` |
| 文が 箱から はみ出す | 上限（`MAX`）＋ 本物の フォントで 行数を はかる テスト ＋ 画面ごとの `fits()` |
| タッチの ボタンが 画面の 上に のこる | `_set_screen()` で かならず かくす |
| ダッシュボードの 正規表現が 書きかたに 弱い | きまりを `episode_db.gd` の 先頭に 書く。`run_tests.sh` が 毎回 試しに 作る |
| `const` の 辞書に 書きこんで エラー | `scene_stage()` は かならず `duplicate(true)` の 写しに 書く。`Game.episode` には 書かない |
| 体の 事実 | 下の 9.3。話を 足す たびに 見る |

### 9.3 体の 事実で 気を つけた 点

- **1 話**：あなの あいた むしばは 自分では なおらない。患者の おれいは「はいしゃさんにも いってくるね」、カルテは「はいしゃさんに なおしてもらおう」。
- **2 話**：はやぐいが ピロリきんを よぶ とは 言わない。カルテの「どうして？」は 2 つを 分けて 書いた。ピロリきんは「きづかない うちに ながく すんでいる ことが ある」「びょういんで しらべて、おくすりで なおせる」。患者は おとうさん（子どもの 腹痛の 原因としては まれ）。
- **3 話**：入口は「おみずと いっしょに ごくん」。おなかの きんが 多いのは だいちょう なので、「しょうちょうで」とは 言わず「ちょう（腸）で あくだまきんが ふえた」と 丸めた。
- **4 話**（これから）：ばいきんは きずの ところだけ。けっかんの 中には 出さない。
- **5 話と 10 話**（これから）：かぜは はなと のど。はいほうに ばいきんが ひろがるのが はいえん。2 つを まぜない。
- **8 話**（これから）：せまく なるのは しんぞうの きんにくへ 行く けっかん。ゲームで できるのは「ながれを てつだう」まで。

### 9.4 持ち主に 伝える 点

1. 前の セーブの ほしは 0 に もどる（ずかんと 設定は のこる。元の ファイルは `save.v1.json` に 写る）。
2. ほしは「別々の 回で 取れる」に 変えた。
3. ずかんは「カルテの 段 ＋ 場所の 段」に した。
4. 患者 3 人・からだの地図・そうだんの 背景・カルテの 挿絵は 仮。絵の 口は 3.5、発注書は `docs/art_orders/`。
