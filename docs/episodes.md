# カルテ（1 話）形式の 設計

> 状態：**設計確定・第 2 版**（2026-11-12。レビュー 2 件の 指摘 26 件を 反映）。物語は `docs/story.md`（OK 済み。9〜10 話の 大きな病気は **はいえん（肺炎）**）。
> この文書は 実装者向け。マイルストーン 1（M1）＝ 枠組み ＋ 1〜3 話を、**いまの 10 個の GLB と MK_ マーカーを 変えずに** 作る。見た目は すべて 仮（絵は あとで Codex に 発注）。
> 「確認ずみ」と 書いた コードは、リポジトリの 写しで 実際に 動かした もの（1〜3 話 ＋ つづきから ＋ ずかん ＋ 10 場所が `RESULT: OK`、`SCRIPT ERROR` なし、`DASHBOARD: OK`。自動操縦で ep01 約 25 秒／ep02 約 50 秒／ep03 約 50 秒（sim）、全部で 実時間 20 秒ほど）。写しの 画面は「動きは 本物・見た目は 最小」の 試作で、カルテ画面の 主ボタンは 仕様どおり「つぎの カルテへ ▶」（`finished(true)`）を 出す。カルテの 紙（`karte_sheet.gd`）と、文が 箱に 入るかの 計測（本物の フォント）は 本物を 動かした。それ以外の レイアウト（3.4 の 座標）と `ui_theme.gd` の 絵（3.5）、`shot.gd` の モード（6.3）は 仕様だけで、まだ 動かして いない。

目次：1 ねらいと用語 ／ 2 データ ／ 3 画面と流れ ／ 4 Level の変更 ／ 5 セーブ・ほし・ずかん ／ 6 テスト・CI・ダッシュボード ／ 7 M1 の作業手順 ／ 8 ep4〜10 の追加手順 ／ 9 リスクと決めたこと

---

## 1. ねらいと 用語

「10 ステージを 順に 遊ぶ」から「**カルテ（1 話）を 1 本ずつ 解く**」へ。1 話 ＝ そうだん → よそう → 場面 1〜3 こ（場面の あとに「あとの はなし」）→ カルテ（3 行 ＋ げんいんの タイプ ＋ クイズ ＋ ほし）。

| 用語 | コードでの名前 | 意味 |
|------|--------------|------|
| カルテ（話） | episode、`EpisodeDB.EPISODES` の 1 要素、id は `ep01`… | 1 回の 相談。ほし・解放・ずかんの 単位 |
| 場所 | place ＝ `StageDB.STAGES` の 1 要素（id は `mouth` など） | 臓器。GLB・マーカー・霧の色・ものしりカード・既定の ミッションを 持つ。**M1 では 形も キーも そのまま**（カードの 文を 2 か所 直すだけ。2.1） |
| 場面 | scene ＝ カルテの `scenes[i]` | 「場所 id ＋ 上書き」。`EpisodeDB.scene_stage()` が 場所の 辞書の 写しに 上書きを 重ね、`Level.setup()` に 渡す |
| 患者 | patient ＝ `EpisodeDB.PATIENTS` の キー（`hana` `kenta` `papa` `jiji`） | そうだんに 来る 人 |
| そうだん | phase `consult`（画面 `talk.gd`） | 患者と ピコの 会話 1〜3 ページ |
| よそう | phase `guess`（画面 `guess.gd`） | からだの地図で 行き先を えらぶ。はずれは ヒントが 出て えらびなおし（しかられない・ほしに 関係なし） |
| あとの はなし | phase `after`（画面 `talk.gd`） | 場面の あとの 会話（ボタンで 進む）。「い（胃）は げんき！」の どんでん返しと、さいごの 場面の「ピコッと はっけん！」（種あかし）は これ |
| カルテ画面 | phase `karte`（画面 `karte.gd`） | かいけつ → カルテの 紙（なにが おきていた／どうして／これからは ＋ げんいんの タイプ）→ クイズ → ほし |
| カルテの 紙 | `karte_sheet.gd` | 3 行 ＋ げんいんの タイプ。カルテ画面と ずかんが 同じ ものを 使う |
| げんいんの タイプ | `EpisodeDB.PATTERNS`（A〜F） | 不調の パターン（story.md 3 章）。名前と ひとことを カルテの 紙に 出す（シリーズで 学ぶ こと） |
| つづきから | `SaveData.resume()`、`Game.resume_episode()` | 場面を 1 つ おえる たびに 記録。やめても、おえた 場面の 次から 入れる |
| 場所モード | `Game.start_stage(place_id)` | 場所を 既定の ミッションで 開く。**テストと スクリーンショット専用**（子どもの 画面からは 行けない） |

設計の 原則（迷ったら これ）：

1. **子どもが 詰まらない が 最優先**。ゲームオーバーなし。よそうの はずれは 罰しない。データが まちがっていても ゴールは 開く（4.3）。どの 画面も いつも 何かに フォーカスが ある（3.3）。
2. **話は データだけで 足せる**。Level は「場面の 辞書 1 枚」しか 見ない。話を 知っている コードは `Game`・`EpisodeDB`・`SaveData` と 画面（`ui/`）だけ。`level/`・`entities/`・`player/` は 話を 知らない。
3. **`level.stage_id` は 場所の id の まま**。カードの 既読キー（`stomach/pylori`）、挿絵の 名前（`card_stomach_pylori.png`）、しょくどうの なみ（`level.gd:659`）が そのまま 動く。
4. **ミッションの 型は ふやさない**。「しらべる」「なだめる」＝ `cheer`、「そうじ」＝ `collect` を、文と 種類（kind）で 言いかえる。型を ふやすと `current_target_position()`・`_fit_missions()`・`autopilot.gd` の 3 か所を 同時に 直す ことに なる。
5. **大事な 文は ボタンで 進む 画面に 書く**。遊んでいる あいだの HUD の 文（`intro`・`each_say`・`done_say`・`goal_say`・`clear_say`）は 時間で 消え、子どもは 操縦しながら 読む。だから HUD には「いま 何を するか」の 短い ひとことだけを 書き、原因の 種あかし・学びは `after`（あとの はなし）と `karte` に 書く（2.2「HUD の 文」）。

---

## 2. データ

### 2.1 ファイル構成

| ファイル | 役目 | M1 での 変更 |
|---------|------|-------------|
| `godot/src/autoload/stage_db.gd`（`StageDB`） | **場所**の 定義。`STAGES`・`KIND_NAMES`・ものしりカード | `STORY_INTRO`／`STORY_ENDING`（6-7 行）、`next_stage_id()`（257-262）、`all_cards()`（277-284）を 消す。**`STAGES` は キー・ミッション・数を 変えない**（`tools/build_dashboard.py` の `stages()` が そのまま 動く）。カードの 文だけ 2 か所 直す（一文字の 臓器名。`validate()` が 見つける）：71 行「いの かべに」→「い（胃）の かべに」、94 行「ちに わたすんだ」→「ち（血）に わたすんだ」 |
| `godot/src/autoload/episode_db.gd`（`EpisodeDB`、**新規**） | **カルテ**の 定義と 読み出し。`PATIENTS`・`PATTERNS`・`ORGAN_POS`・`OPENING`・`ENDING`・`EPISODES`・`scene_stage()`・`validate()`・`text_problems()` | 2.3 の 全文を そのまま 置く |
| `godot/project.godot` | autoload | `StageDB` の 次の 行に `EpisodeDB="*res://src/autoload/episode_db.gd"`（`SaveData` が `EpisodeDB.ids()` を 使うので `SaveData` より 前） |
| `blender/stages.py`、`godot/assets/models/stages/*.glb` | 場所の 形と マーカー | 変更なし |

別ファイルに する 理由：`build_dashboard.py:60` は `stage_db.gd` を `\n\t\t"id": ` で 切って 場所の 表を 作る。同じ ファイルに 話を 入れると こわれる。

きまり：**新しい 知識カード（ものしりカード）は 場所に 足す**（`STAGES[..]["cards"]`）。話ごとに カードを 複製しない。その 生き物が 出ない 場面では `_add_card_point()` が 呼ばれないので、カードも 出ない。話が 持つ カードは カルテ（`epNN/karte`）だけ。

場所の 文の 検査：`validate()` は、**カルテで 行く 場所**（`used_places()`）の ものしりカードと まとめにも 文の きまり（2.2）を かける。いまの `stage_db.gd` には 一文字の 臓器名の 書きもらしが 24 か所 ある（「ちは」「ちを」など。けっかん・しんぞう・はい に 22、M1 で 行く い（胃）・しょうちょうに 2）。M1 は 上の 2 か所だけ 直し、のこりは その 場所を 使う 話（ep5・ep8）を 足す ときに `validate()` が 止めるので、そこで 直す。

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
| `scenes` | Array[SCENE] | ○ | 1〜3 こ。同じ 場所を 2 回 使って よい（5 話：はな → はい → はな） |
| `karte` | KARTE | ○ | カルテ画面の 文 |
| `quiz` | QUIZ | ○ | `StageDB` の quiz と 同じ 形 |

（第 1 版に あった `culprit` は やめた。「あたりの よそう」は えらび（CHOICE）の `hit` で 書く。場所の id と くらべると、8 話の ように「地図では しんぞう、場面は けっかん」の 話で 合わなく なる。）

**PATTERNS**（`const PATTERNS`。story.md 3 章）：`記号 → {"name": なまえ（12 字まで）, "msg": ひとこと（30 字まで）}`。A ばいきん・ウイルス ／ B けが ／ C まいにちの くせ ／ D からだの まちがい ／ E ばしょ ちがい ／ F おおきな びょうき。文は 2.3 の 全文。

**LINE**（会話の 1 ページ）：`{"who": "hana" | "pico" | …, "text": "…"}`。`who` は `"pico"` か `PATIENTS` の キー。`text` は 90 字まで、`\n` で 改行。ふきだし（32 px・幅 726）で **6 行まで**（テストが 本物の フォントで はかる）。

**GUESS**

| キー | 型 | 必須 | 内容 |
|------|----|:---:|------|
| `q` | String | ○ | ピコの 問い（40 字まで） |
| `choices` | Array[CHOICE] | ○ | 2〜3 こ。**書いた 順に** 上から ならぶ（まぜない。最初の フォーカスは 1 つめ）。答えの 位置は 話ごとに 変える。同じ `place` を 2 回 書かない |
| `depart` | String | ○ | しゅっぱつの ひとこと（入口。40 字まで）。`go` の えらびを 押した あと、**ふきだしとは 別の 箱**に 出る（3.4 C。ふきだしに つなげると 入らない） |

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
| `arrow` | String | — | `"nearest"` ＝ 矢印が「開いている ミッションの 相手の うち いちばん 近い もの」を 指す（4.4）。無ければ いままでどおり リストの 上から 順。相手が 道ぞいに まざって ならぶ 場面（3 話の しょうちょう）で 使う |
| `spawn` | SPAWN | — | マーカーの 出しかたの 上書き（4.2） |
| `goal_say` | String | — | ゴールが 開いた ときの ひとこと（45 字まで。＝ さいごの 非 reach ミッションが おわった とき）。無ければ「やったね！ ぜんぶ できた！ きいろい わっかの ゴールへ いこう！」。**「ゴールへ いこう」まで**を 書く。種あかしは `after` に |
| `clear_say` | String | — | ゴールに 入った ときの ひとこと（30 字まで）。無ければ「クリア！」 |
| `after` | AFTER | — | この 場面の あとの 会話。無ければ すぐ 次へ。**さいごの 場面には 書く**（「ピコッと はっけん！」＝ 原因の 種あかし。カルテの 前に 出る） |
| そのほか | — | — | 場所の キーは どれでも 上書きできる：`flow_speed`、`bgm`（`"bgm_boss"` など）、`fog`、`ambient` … |
| `reverse` `hide_nodes` | — | — | **予約**（M1 では 実装しない。8 章の ep5・ep4） |

**SPAWN**（マーカー名は `MK_` を 取った 形で 書く。合わせかたは「同じ」または「その 語 ＋ `_` で 始まる」＝ `Level.spawn_rule_matches()`）

| キー | 型 | 内容 | 例 |
|------|----|------|----|
| `skip` | Array[String] | 出さない | `["enemy_pylori"]`（5 ひき 全部）、`["enemy_pylori_4", "enemy_pylori_5"]`（2 ひきだけ）、`["enemy"]`（てき 全部）、`["card_acid"]` |
| `swap` | Dictionary | 種類を 読みかえる。**番号は のこる**：`MK_friend_rbc_2` に `{"friend_rbc_2": "friend_wbc"}` も `{"friend_rbc": "friend_wbc"}` も `MK_friend_wbc_2` に なる。番号の 無い マーカーは そのまま（`MK_boss_boss_virus` → `MK_boss_boss_haien`） | `{"friend_rbc_2": "friend_wbc"}`、`{"boss_boss_virus": "boss_boss_haien"}` |
| `add` | Array | **予約**（GLB に 無い 所へ 出す。8 章の ep5 で 作る）。1 件に `"after": ミッションの 番号` を 書くと、その ミッションが おわった ときに 出る（**予約**。ep10 の おくすり） | |

- `player`・`goal`・`path`・`checkpoint` は かえられない（書くと `validate()` が 止め、Level は 無視する）。
- **えいようの マーカーは 番号が 2 つ**：`MK_pickup_nutrient_<しゅるい 0〜2>_<通し番号 1〜6>`（`blender/stages.py:600`）。`skip: ["pickup_nutrient_1"]` は「しゅるい 1 の 2 こ（`_1_2`・`_1_5`）」を 消す。通し番号 1 の えいようだけを 消すなら `"pickup_nutrient_0_1"` と 全部 書く。

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
| `exit` | — | 出口の ひとこと（ピコ。60 字まで）。**その 話の ゴールの 場所から つじつまが 合う 出かた**を 書く（のどの おくで まわれみぎ → うがい、い（胃）の いりぐちまで もどって → げっぷ） |
| `what` `why` `next` | ○ | 「なにが おきていた？」「どうして？」「これからは？」（それぞれ **62 字まで**。カルテの 紙で 2 行）。`next` には 予防と「びょういんに 行く めやす」を 入れる。紙 全体は 400 px まで（テストが はかる） |

**QUIZ**：`{"q", "choices": [3 つ], "answer": 0〜2, "explain"}`（表示の ときに まぜる。`result.gd:130-132` と 同じ）。

**文の きまり**（`validate()` が 全部の 文を `EpisodeDB.text_problems()` で 調べる。テストは **画面に 出た ラベルと ボタンの 文**にも 同じ 検査を かける ＝ 画面の 決まり文句も 守られる）：

- 漢字は（ ）の 中だけ。
- わかち書き。かなが 13 字 以上 つづいたら 空白の 入れわすれと みなす（「ミクロしんりょうじょへ」は 11 字で 通る）。
- 一文字の 臓器名は 漢字を そえる：「い」「は」「ち」＋ 助詞（が・の・を・に・は・も・で・へ・と・や）だけの 語（「いが」「はを」「ちの」）を 見つけたら 止める。「はは」「いも」「はで」は 見のがす（`OK_WORDS`）。
- 「〜している」「〜してくれる」「〜してみよう」は つなげて 書く（いまの `stage_db.gd` と 同じ。画面の 見出しも「よそうしてみよう！」）。
- **地図の よそうが はずれた ときの 返事は「いい かんがえだね！」で 始める**（まだ しらべて いないので「しらべかた」とは 言わない）。「いい しらべかた だったよ！」は、場面で しらべた あとの `after` で 使う（story.md 4 章）。
- 画面は「せいかい／ざんねん／ちがった」を **子どもの よそうに 向けて** 言わない。3 話の どんでん返しは「い（胃）は げんき！」「はなちゃんは『きっと い（胃）』と いっていたけど…」と、患者の 思いこみの 話に する。
- 「ピコッと はっけん！」は 原因を 見つけた とき（さいごの 場面の `after` の 見出し）に とって おく。よそうで `go` を えらんだ ときは「うん、〜が あやしいね！」。

**HUD の 文**（`intro`・`each_say`・`done_say`・`goal_say`・`clear_say`・`hints`）：

- 出る 時間は 長さで 決まる：`Level.read_time(text, base)` ＝ `max(base, 字数 × 0.25 秒)`（6〜7 さいは 1 秒に 3〜5 字）。45 字で 約 11 秒。
- 短く：`intro`・`goal_say` は 45 字、`each_say`・`done_say`・`clear_say` は 30 字まで（HUD の ふきだしで 2 行、タッチの 細い ふきだしでも 3 行）。
- 物語の ひとこと（`hints` 以外）は、出てから 2 秒は ほかの 文に 上書きされない。その あとは「いえきだ！」の ような とっさの ひとことが 上に 出る ことが ある（4.3）。**だから ここに しか 無い 大事な 話を 書かない**（原則 5）。

### 2.3 `episode_db.gd` 全文（1〜3 話。確認ずみ・そのまま 貼る）

マーカーとの 照合（`blender/stages.py`）：

| 場面 | 使う マーカー | 行 |
|------|------------|----|
| ep01 くち | `MK_enemy_mushiba_1..4`（defeat 4）、`MK_goal`、`MK_checkpoint_1`、`MK_card_tooth` | 365-379 |
| ep02 しょくどう | `MK_goal`、`MK_checkpoint_1..2`、`MK_card_food`・`MK_card_epiglottis`。かたまりは GLB の 中の `FoodChunks`（当たりだけ。ダメージなし） | 509-523 |
| ep02 い（胃） | `MK_enemy_pylori_1..5`（defeat 4）、`MK_friend_wallcell_1..3`（cheer 3）、`MK_hazard_acid_*` 3 | 556-569 |
| ep03 い（胃） | `MK_friend_wallcell_1..3`（cheer 3）。`MK_enemy_pylori_*` は `skip`。いえきの いけは のこる | 同上 |
| ep03 しょうちょう | `MK_pickup_nutrient_*` 6（collect 6）、`MK_deliver_villus_1..2`（deliver 6）、`MK_friend_zendama_1..3`（cheer 3）、`MK_enemy_akudama_1..3`（たおさなくて よい） | 592-607 |

1〜3 話の 文で 気を つけた 点：

- **どの 話も さいごの 場面に `after`（見出し「ピコッと はっけん！」・1 ページ）**。原因の 種あかしは ここ（ボタンで 進む）と カルテの 紙に ある。`goal_say` は「ゴールへ いこう」まで。
- **3 話の しょうちょうは `"arrow": "nearest"`**。えいよう（道の 12〜72 %）・じゅうもう（52 %・93 %）・ぜんだまきん（18・45・66 %）が まざって ならぶ。リスト順の 矢印だと、ぜんだまきんを 指すのは いちばん おく（93 %）まで 行った あとで、通りすぎた 子は 流れに さからって もどる ことに なる。近い順なら 上流から 1 回で 全部 まわれる（自動操縦で 場面 26 秒。リスト順は 38.6 秒）。ヒントにも「ぜんだまきんにも さわって」と 書いた。
- **3 話は「ちょう（腸）で あくだまきんが ふえた」**と 言う（「しょうちょうで」とは 言わない。9.3）。場面の 場所は しょうちょうの まま。
- **3 話の `after`**：見出しは「い（胃）は げんき！」。はずれたのは はなちゃんの 思いこみ、と 言う。さいしょに しょうちょうを えらんだ 子（`hit`）には `lines_hit`。
- **2 話の カルテ**：ピロリきんは「きづかない うちに い（胃）に ながく すんでいる ことが ある」（おとなが うつる、とは 言わない）。出口は「い（胃）の いりぐちまで もどって、げっぷ」。ミッションの 文は「ゴールの わっかへ いこう」（「でぐち」と 言うと、げっぷで 口から 出る 話と 合わない）。
- **1 話の そうさ説明**は 場面の `hints` に 写した（場所の ヒントは 引きつがない）。`intro` は 28 字（7 秒）で、すぐ そうさの ヒントが 出る。

```gdscript
extends Node
## カルテ（1 話）の 定義。場所（GLB・マーカー・ものしりカード・既定の ミッション）は StageDB.STAGES。
## ここには 話の 文と、場面（scene）ごとの 上書きだけを 書く。設計は docs/episodes.md。
##
## 書きかたの きまり（tools/build_dashboard.py が 正規表現で 読む）：
## - 各話の 1 行目は「\t\t"id": "epNN", "no": N, "title": "…", "patient": "…", "pattern": "…", "difficulty": N,」
## - 場面は 4 タブで「"place": "<場所 id>",」を 1 行に 単独で 書く（よそうの choices は「{"place": …}」と 波かっこから 始める）
## - 文は ひらがな・カタカナ・わかち書き。漢字は「い（胃）」の ように（ ）の 中だけ（validate() が 調べる）
## - 大事な 種あかしは HUD（intro・goal_say など。時間で 消える）に 書かない。after（ボタンで 進む）と karte に 書く

const SEASON_COMPLETE := false   # 10 話 そろったら true（さいごの カルテの あとに エンディングを 出す）

const PATIENTS := {
	"hana": {"name": "はなちゃん", "color": Color(1.0, 0.72, 0.8)},
	"kenta": {"name": "けんたくん", "color": Color(0.62, 0.86, 1.0)},
	"papa": {"name": "おとうさん", "color": Color(0.6, 0.9, 0.75)},
	"jiji": {"name": "おじいちゃん", "color": Color(1.0, 0.86, 0.35)},
}
const PICO := {"name": "ドクター・ピコ", "color": Color(0.75, 0.92, 1.0)}

## 不調の パターン（story.md 3 章）。カルテの 紙に「げんいんの タイプ」として 出る
const PATTERNS := {
	"A": {"name": "ばいきん・ウイルス", "msg": "てあらい・うがい・はみがきで ふせごう"},
	"B": {"name": "けが", "msg": "きずは あらって きれいに しよう"},
	"C": {"name": "まいにちの くせ", "msg": "まいにちの つみかさねが だいじ"},
	"D": {"name": "からだの まちがい", "msg": "てきを たおすだけが なおす ことじゃ ないよ"},
	"E": {"name": "ばしょ ちがい", "msg": "きめつけないで しらべよう"},
	"F": {"name": "おおきな びょうき", "msg": "がまんしないで はやく おとなと おいしゃさんへ"},
}

## からだの地図の 中での 位置（0〜1）。よそうの 画面が 使う
const ORGAN_POS := {
	"brain": Vector2(0.50, 0.085), "nose": Vector2(0.62, 0.17), "mouth": Vector2(0.50, 0.23),
	"esophagus": Vector2(0.50, 0.33), "lungs": Vector2(0.34, 0.42), "heart": Vector2(0.58, 0.40), "heart2": Vector2(0.72, 0.47),
	"stomach": Vector2(0.58, 0.54), "intestine": Vector2(0.50, 0.66), "vessel": Vector2(0.20, 0.58),
}

## はじめて カルテを ひらいた ときだけ、そうだんの 前に 出す（1 ページ）
const OPENING := [
	{"who": "pico", "text": "ようこそ、ミクロしんりょうじょへ！ ぼくは ドクター・ピコ。\nきみは みならいの ちいさな おいしゃさん。からだの なかから みんなを なおしてあげよう！"},
]
const ENDING := "みんな げんきに なった！\nミクロしんりょうじょは きょうも あいているよ。\nまた そうだんに きてね！"

const MISSION_TYPES := ["defeat", "boss", "cheer", "collect", "deliver", "gate", "sequence", "reach"]
const SPAWN_LOCKED := ["player", "goal", "path", "checkpoint"]
## 文の 長さの 上限（字）。HUD に 出る 文（intro〜clear_say）は 短く：子どもは 操縦しながら 読む
const MAX := {
	"title": 24, "line": 90, "q": 40, "say": 70, "depart": 40, "label": 20,
	"intro": 45, "goal_say": 45, "clear_say": 30, "hint": 60, "mission": 30, "each_say": 30, "done_say": 30,
	"banner": 20, "thanks": 60, "exit": 60, "karte": 62, "quiz_q": 40, "quiz_choice": 20, "explain": 90,
}
## 「い」「は」「ち」＋ 助詞 に 見えるが 臓器では ない ことば（_check_text が 見のがす）
const OK_WORDS := ["はは", "いも", "はで"]

const EPISODES: Array[Dictionary] = [
	{
		"id": "ep01", "no": 1, "title": "は（歯）が ズキズキ", "patient": "hana", "pattern": "A・C", "difficulty": 1,
		"consult": [
			{"who": "hana", "text": "おくの は（歯）が ズキズキ いたいよう。\nきのうの よる、チョコを たべて そのまま ねちゃったの。"},
			{"who": "pico", "text": "ピコッ。それは つらいね。\nミクロごうで ちいさくなって、からだの なかを しらべに いこう！"},
		],
		"guess": {
			"q": "どこが あやしいと おもう？",
			"choices": [
				{"place": "stomach", "say": "いい かんがえだね！ チョコは い（胃）にも いくよ。\nでも いたいのは は（歯）。は（歯）が あるのは どこかな？"},
				{"place": "mouth", "go": true, "hit": true, "say": "うん、くち（口）が あやしいね！\nは（歯）が あるのは くちの なか。しらべに いこう！"},
				{"place": "nose", "say": "いい かんがえだね！ はな（鼻）は くちの おとなり。\nでも いたいのは は（歯）。は（歯）が あるのは どこかな？"},
			],
			"depart": "はなちゃん、おおきく あーん！ ミクロごう、くちから はっしん！",
		},
		"scenes": [
			{
				"place": "mouth",
				"intro": "おくの は（歯）に むしばきんが いるよ。やっつけよう！",
				"hints": [
					{"at": 1.0, "text": "やじるしキー（または スティック）で うごけるよ。", "text_touch": "ひだりの まるを ゆびで うごかすと すすめるよ。"},
					{"at": 9.0, "text": "スペースキー（Aボタン）で おくすりを だすよ。ちかくの むしばきんを じどうで ねらうんだ！", "text_touch": "みぎの「おくすり」ボタンで うつよ。ちかくの むしばきんを じどうで ねらうんだ！"},
				],
				"missions": [
					{"type": "defeat", "target": "mushiba", "count": 4, "text": "むしばきんを やっつけよう"},
					{"type": "reach", "text": "のどの おくの ゴールへ いこう"},
				],
				"goal_say": "むしばきんを ぜんぶ やっつけた！ のどの おくの ゴールへ いこう！",
				"clear_say": "むしばきんを やっつけた！",
				"after": {"banner": "ピコッと はっけん！", "lines": [
					{"who": "pico", "text": "むしばきんが「さん」を だして、おくの は（歯）を とかしていたんだ。\nあまい ものの のこりかすが だいすきなんだよ。"},
				]},
			},
		],
		"karte": {
			"thanks": "ズキズキが らくに なったよ。ありがとう！ はいしゃさんにも いってくるね。",
			"exit": "のどの おくで まわれみぎ！ ガラガラ うがいの おみずに のって、くちから そとへ ぴゅーっ！",
			"what": "むしばきんが「さん」を だして、おくの は（歯）を とかしていた。",
			"why": "あまい ものを たべた あと、はみがきを しないで ねてしまった。",
			"next": "ねる まえは かならず はみがき。あなの あいた は（歯）は、はいしゃさんに なおしてもらおう。",
		},
		"quiz": {"q": "むしばきんが だいすきな ものは どれ？", "choices": ["あまい ものの のこりかす", "おみず", "はブラシ"], "answer": 0, "explain": "むしばきんは あまい ものの のこりかすを たべて、は（歯）を とかす「さん」を だすよ。たべたら はみがき！"},
	},
	{
		"id": "ep02", "no": 2, "title": "おとうさんの い（胃）が しくしく", "patient": "papa", "pattern": "A・C", "difficulty": 1,
		"consult": [
			{"who": "papa", "text": "ごはんの あと、い（胃）の あたりが しくしく いたいんだ。\nしごとが いそがしくて、いつも はやぐいでね。"},
			{"who": "pico", "text": "ピコッ。はやぐいは きに なるね。\nたべものと おなじ みちを とおって、しらべてみよう！"},
		],
		"guess": {
			"q": "どこが あやしいと おもう？",
			"choices": [
				{"place": "lungs", "say": "いい かんがえだね！ はい（肺）は いきを する ところ。\nたべた ごはんが たまるのは どこかな？"},
				{"place": "mouth", "say": "いい かんがえだね！ くち（口）は たべものの いりぐち。\nのみこんだ ごはんが たまるのは どこかな？"},
				{"place": "stomach", "go": true, "hit": true, "say": "うん、ごはんが たまる い（胃）が あやしいね！\nのどから しょくどう（食道）を とおって いこう。"},
			],
			"depart": "おとうさん、おみずと いっしょに ごくん！ ミクロごう、はっしん！",
		},
		"scenes": [
			{
				"place": "esophagus",
				"intro": "よく かまずに のみこんだ かたまりが ごろごろ！ よけて い（胃）まで くだろう。",
				"hints": [
					{"at": 1.0, "text": "ピンクの なみ（ぜんどううんどう）に のると はやく すすめるよ。"},
					{"at": 12.0, "text": "たべものの かたまりは よけてね。はたの ところが チェックポイントだよ。"},
				],
				"missions": [
					{"type": "reach", "text": "かたまりを よけて い（胃）へ いこう"},
				],
				"clear_say": "い（胃）の いりぐちに ついた！",
				"after": {"banner": "てがかり はっけん！", "lines": [
					{"who": "pico", "text": "おおきな かたまりが いっぱい だったね。\nよく かまないと、い（胃）は たくさん はたらかないと いけないんだ。"},
					{"who": "pico", "text": "つぎは い（胃）の なかを しらべよう！"},
				]},
			},
			{
				"place": "stomach",
				"intro": "ピロリきんが い（胃）の かべを いじめている！ やっつけよう。",
				"hints": [
					{"at": 1.0, "text": "きいろい いけ（いえき）に はいると ハートが へるよ。きをつけて！"},
					{"at": 14.0, "text": "なかまには さわるだけで おうえんできるよ。"},
				],
				"missions": [
					{"type": "defeat", "target": "pylori", "count": 4, "text": "ピロリきんを やっつけよう", "done_say": "ピロリきんが へった！ かべの さいぼうも おうえんしよう。"},
					{"type": "cheer", "target": "wallcell", "count": 3, "text": "い（胃）の かべの さいぼうを おうえんしよう", "done_say": "かべが げんきに なった！ ピロリきんも やっつけよう。"},
					{"type": "reach", "text": "ゴールの わっかへ いこう"},
				],
				"goal_say": "やったね！ い（胃）の かべが げんきに なった。ゴールの わっかへ いこう！",
				"clear_say": "おとうさんの い（胃）、もう だいじょうぶ！",
				"after": {"banner": "ピコッと はっけん！", "lines": [
					{"who": "pico", "text": "はやぐいの かたまりと、ピロリきん。\nふたつが い（胃）を つかれさせていたんだね。"},
				]},
			},
		],
		"karte": {
			"thanks": "おなかが らくに なってきたよ。ありがとう！ これからは ゆっくり たべるね。",
			"exit": "い（胃）の いりぐちまで もどって、げっぷに のって くちから そとへ ぽーん！",
			"what": "い（胃）の かべに ピロリきんが すみついていた。おおきな かたまりも い（胃）を つかれさせていた。",
			"why": "いそいで たべて、よく かんでいなかった。ピロリきんは、きづかない うちに い（胃）に ながく すんでいる ことが ある。",
			"next": "ひとくち 30かい、よく かんで たべよう。ピロリきんは びょういんで しらべて、おくすりで なおせるよ。",
		},
		"quiz": {"q": "い（胃）が らくに なる たべかたは どれ？", "choices": ["よく かんで ゆっくり たべる", "かまずに のみこむ", "はしりながら たべる"], "answer": 0, "explain": "よく かむと たべものが こまかくなって、い（胃）が とかしやすく なるよ。"},
	},
	{
		"id": "ep03", "no": 3, "title": "おなかが いたい…どこ？", "patient": "hana", "pattern": "E・C", "difficulty": 1,
		"consult": [
			{"who": "hana", "text": "おなかが いたいよう。\nきのう アイスを 3こ たべたから、きっと い（胃）だよ。"},
			{"who": "pico", "text": "ピコッ。おなかの なかには、い（胃）の ほかにも いろいろ あるよ。\nきめつけないで、しらべてみよう！"},
		],
		"guess": {
			"q": "どこが あやしいと おもう？",
			"choices": [
				{"place": "stomach", "go": true, "say": "はなちゃんと おなじ よそうだね。\nじゃあ まず い（胃）を みに いこう！"},
				{"place": "intestine", "go": true, "hit": true, "say": "いい よそうだね！ おぼえておこう。\nたべものが とおる じゅんばんに、まず い（胃）から しらべるよ。"},
				{"place": "brain", "say": "いい かんがえだね！ でも のう（脳）は あたまの なか。\nいたいのは おなか。おなかに あるのは どこかな？"},
			],
			"depart": "はなちゃん、おみずと いっしょに ごくん！ ミクロごう、はっしん！",
		},
		"scenes": [
			{
				"place": "stomach",
				"spawn": {"skip": ["enemy_pylori"]},
				"intro": "ここは はなちゃんの い（胃）。かべの さいぼうに さわって しらべよう！",
				"hints": [
					{"at": 1.0, "text": "やじるしの さきに かべの さいぼうが いるよ。さわると しらべられるんだ。"},
					{"at": 14.0, "text": "きいろい いけ（いえき）に はいると ハートが へるよ。きをつけて！"},
				],
				"missions": [
					{"type": "cheer", "target": "wallcell", "count": 3, "text": "い（胃）の かべの さいぼうを しらべよう", "each_say": ["この さいぼうは げんき いっぱい！", "ここも だいじょうぶ。ねんえきも たっぷり！"]},
					{"type": "reach", "text": "でぐちから もっと おくへ すすもう"},
				],
				"goal_say": "あれれ？ みんな げんき。ばいきんも いない……。でぐちの わっかへ いこう！",
				"clear_say": "い（胃）を しらべおわった！",
				"after": {"banner": "い（胃）は げんき！", "lines": [
					{"who": "pico", "text": "はなちゃんは「きっと い（胃）」と いっていたけど、い（胃）は どこも わるくなかったね。"},
					{"who": "pico", "text": "いたい ところと わるい ところは、ちがう ことが あるんだ。\nいい しらべかた だったよ！ つぎは もっと おくの ちょう（腸）を しらべよう！"},
				], "lines_hit": [
					{"who": "pico", "text": "い（胃）は どこも わるくなかったね。\nいたい ところと わるい ところは、ちがう ことが あるんだ。"},
					{"who": "pico", "text": "きみの よそうどおり、もっと おくが あやしいね！\nつぎは ちょう（腸）を しらべよう！"},
				]},
			},
			{
				"place": "intestine",
				"arrow": "nearest",
				"intro": "みつけた！ ちょう（腸）で あくだまきんが ふえて、ぜんだまきんが こまっている！",
				"hints": [
					{"at": 1.0, "text": "ひかる えいようを ひろって、みどりの おおきな じゅうもうに とどけよう。"},
					{"at": 15.0, "text": "みどりの ぜんだまきんにも さわって おうえんしてね。やじるしが おしえてくれるよ。"},
				],
				"missions": [
					{"type": "collect", "target": "nutrient", "count": 6, "text": "えいようを あつめよう"},
					{"type": "deliver", "target": "villus", "count": 6, "text": "えいようを じゅうもうに とどけよう"},
					{"type": "cheer", "target": "zendama", "count": 3, "text": "ぜんだまきんを おうえんしよう", "done_say": "ぜんだまきんが げんきに なった！"},
					{"type": "reach", "text": "ちょうの おくの ゴールへ いこう"},
				],
				"goal_say": "やったね！ おなかの なかが げんきに なってきた。おくの ゴールへ いこう！",
				"clear_say": "おなかの なかが げんきに なった！",
				"after": {"banner": "ピコッと はっけん！", "lines": [
					{"who": "pico", "text": "わるかったのは い（胃）じゃなくて、その おくの ちょう（腸）だったね。\nあくだまきんが ふえて、おなかの ちょうしが わるくなっていたんだ。"},
				]},
			},
		],
		"karte": {
			"thanks": "おなかが いたくなくなってきた！ ありがとう！ やさいも たべてみるね。",
			"exit": "かえりは…… うんちと いっしょに ぽとん！ ちゃんと あらうから だいじょうぶ。",
			"what": "ちょう（腸）で あくだまきんが ふえて、おなかの ちょうしが わるくなっていた。い（胃）は げんき だった。",
			"why": "あまい もの ばかりで、やさいが たりなかった。",
			"next": "やさいと ヨーグルトも たべよう。おなかが すごく いたい ときや ずっと いたい ときは、すぐ おとなに いおう。",
		},
		"quiz": {"q": "おなかが いたい とき、わるい ところは いつも い（胃）？", "choices": ["ちがう ところの ことも ある", "かならず い（胃）", "かならず は（歯）"], "answer": 0, "explain": "いたい ところと わるい ところは ちがう ことが あるよ。だから きめつけないで、じゅんばんに しらべるんだ。"},
	},
]


func get_episode(id: String) -> Dictionary:
	for e in EPISODES:
		if e["id"] == id:
			return e
	push_error("unknown episode: %s" % id)
	return {}


func ids() -> Array[String]:
	var out: Array[String] = []
	for e in EPISODES:
		out.append(e["id"])
	return out


func next_id(id: String) -> String:
	var a := ids()
	var i := a.find(id)
	return a[i + 1] if i >= 0 and i + 1 < a.size() else ""


func scene_count(id: String) -> int:
	for e in EPISODES:
		if e["id"] == id:
			return e["scenes"].size()
	return 0


## どれかの 話が 使う 場所（はじめて 出てくる 順）。ずかんが 使う
func used_places() -> Array[String]:
	var out: Array[String] = []
	for e in EPISODES:
		for sc in e["scenes"]:
			if not out.has(sc["place"]):
				out.append(sc["place"])
	return out


## 話す 人の 名前と 色（"pico" か PATIENTS の キー）
func speaker(who: String) -> Dictionary:
	return PICO if who == "pico" else PATIENTS.get(who, PICO)


## カルテえらびに 出す ひとこと：患者が 話す 最初の ページ（無ければ 1 ページ目）
func select_line(ep: Dictionary) -> Dictionary:
	for l in ep["consult"]:
		if l["who"] == ep["patient"]:
			return l
	return ep["consult"][0]


## パターンの 記号の 配列（"A・C" → ["A", "C"]）
func patterns(ep: Dictionary) -> PackedStringArray:
	return String(ep["pattern"]).split("・", false)


## よそうの えらびの 表示名：label が あれば それ、無ければ 場所の「なまえ（漢字）」
func place_label(choice: Dictionary) -> String:
	if choice.has("label"):
		return choice["label"]
	if StageDB.stage_ids().has(choice["place"]):
		var s := StageDB.get_stage(choice["place"])
		return "%s（%s）" % [s["name"], s["kanji"]]
	return ""


## さいしょの よそう（place）が「あたり」（hit: true の えらび）だったか
func guess_is_hit(ep: Dictionary, first_guess: String) -> bool:
	for c in ep.get("guess", {}).get("choices", []):
		if c["place"] == first_guess:
			return c.get("hit", false)
	return false


## あとの はなしの ページ：さいしょの よそうが あたりで lines_hit が あれば それ
func after_lines(ep: Dictionary, i: int, first_guess: String) -> Array:
	var a: Dictionary = ep["scenes"][i].get("after", {})
	if a.has("lines_hit") and guess_is_hit(ep, first_guess):
		return a["lines_hit"]
	return a.get("lines", [])


## 場面 i を Level.setup() に わたす 辞書に する：場所の 辞書の 写し ＋ 場面の 上書き。
## "id" は 場所の id の まま（カードの キー・挿絵の 名前・しょくどうの なみ が そのまま 動く）。
func scene_stage(ep: Dictionary, i: int) -> Dictionary:
	var sc: Dictionary = ep["scenes"][i]
	var st: Dictionary = StageDB.get_stage(sc["place"]).duplicate(true)   # const は 読み取り専用。かならず 写しに 書く
	for k in sc.keys():
		if k != "place" and k != "after":
			st[k] = sc[k]
	st["ep"] = ep["id"]
	st["scene"] = i
	return st


## ずかんで 読みかえす カルテ（CardPopup が "karte" を 見て カルテの 紙を 出す）
func karte_card(ep: Dictionary) -> Dictionary:
	return {"tag": "カルテ %d" % ep["no"], "title": ep["title"], "karte": ep["id"]}


## （ ）の 外に ある 漢字を 1 文字 返す（無ければ ""）
static func kanji_outside_paren(text: String) -> String:
	var depth := 0
	for i in text.length():
		var ch := text[i]
		if ch == "（":
			depth += 1
		elif ch == "）":
			depth = maxi(depth - 1, 0)
		elif depth == 0:
			var u := text.unicode_at(i)
			if (u >= 0x4E00 and u <= 0x9FFF) or u == 0x3005:
				return ch
	return ""


static func _is_kana(u: int) -> bool:
	return (u >= 0x3041 and u <= 0x3096) or (u >= 0x30A1 and u <= 0x30FA) or u == 0x30FC


## 文の きまりの 検査（文の まちがいを 文の 配列で 返す。空なら OK）。テストは 画面に 出た 文にも 使う
static func text_problems(text: String) -> Array[String]:
	var out: Array[String] = []
	var k := kanji_outside_paren(text)
	if k != "":
		out.append("（ ）の 外に 漢字「%s」" % k)
	# わかち書き：かなが 13 字 以上 つづいたら 空白の 入れわすれ
	var run := 0
	for i in text.length():
		run = run + 1 if _is_kana(text.unicode_at(i)) else 0
		if run == 13:
			out.append("かなが 13 字 つづく（わかち書き）：…%s" % text.substr(i - 12, 13))
	# 一文字の 臓器名（い・は・ち）は 漢字を そえる：「いが」「はを」「ちの」の ような 語を さがす
	var words := text.replace("\n", " ").replace("「", " ").replace("」", " ").replace("、", " ").replace("。", " ").replace("！", " ").replace("？", " ").split(" ", false)
	for w in words:
		if w.length() == 2 and w[0] in ["い", "は", "ち"] and w[1] in ["が", "の", "を", "に", "は", "も", "で", "へ", "と", "や"] and not OK_WORDS.has(w):
			out.append("「%s」：一文字の 臓器名は「い（胃）」の ように 書く" % w)
	return out


func _check_text(bad: Array[String], where: String, text: String, max_len: int) -> void:
	if text.strip_edges() == "":
		bad.append("%s: 文が 空" % where)
	if text.length() > max_len:
		bad.append("%s: 長すぎる（%d 字。%d 字まで）" % [where, text.length(), max_len])
	for p in text_problems(text):
		bad.append("%s: %s" % [where, p])


func _check_lines(bad: Array[String], where: String, lines: Array) -> void:
	if lines.size() < 1 or lines.size() > 3:
		bad.append("%s: 1〜3 ページに する（いま %d）" % [where, lines.size()])
	for l in lines:
		if l["who"] != "pico" and not PATIENTS.has(l["who"]):
			bad.append("%s: who「%s」が いない" % [where, l["who"]])
		_check_text(bad, where, l["text"], MAX["line"])


## データの まちがいを 文の 配列で 返す（空なら OK）。tests/smoke.gd が 呼ぶ
func validate() -> Array[String]:
	var bad: Array[String] = []
	_check_lines(bad, "OPENING", OPENING)
	_check_text(bad, "ENDING", ENDING, 200)
	for p in PATIENTS.keys():
		_check_text(bad, "PATIENTS " + p, PATIENTS[p]["name"], 12)
	for p in PATTERNS.keys():
		_check_text(bad, "PATTERNS %s name" % p, PATTERNS[p]["name"], 12)
		_check_text(bad, "PATTERNS %s msg" % p, PATTERNS[p]["msg"], 30)
	# カルテで 行く 場所の ものしりカードと まとめも、同じ 文の きまりで 見る（子どもが 読むので）
	for pid in used_places():
		var st := StageDB.get_stage(pid)
		var cards: Dictionary = st["cards"].duplicate()
		cards["summary"] = st["summary"]
		for key in cards.keys():
			for t in [cards[key]["title"], cards[key]["text"]]:
				for p in text_problems(t):
					bad.append("場所 %s の カード %s: %s" % [pid, key, p])
	var no := 0
	for ep in EPISODES:
		no += 1
		var id: String = ep["id"]
		if id != "ep%02d" % no or int(ep["no"]) != no:
			bad.append("%s: id と no は ep01 から 順番に" % id)
		if not PATIENTS.has(ep["patient"]):
			bad.append("%s: patient が PATIENTS に ない" % id)
		if patterns(ep).size() < 1 or patterns(ep).size() > 2:
			bad.append("%s: pattern は 1〜2 こ（「A・C」の ように 書く）" % id)
		for p in patterns(ep):
			if not PATTERNS.has(p):
				bad.append("%s: pattern「%s」が PATTERNS に ない" % [id, p])
		_check_text(bad, id + " title", ep["title"], MAX["title"])
		_check_lines(bad, id + " consult", ep.get("consult", []))
		if ep.has("guess"):
			var g: Dictionary = ep["guess"]
			var go := 0
			var seen_places: Array = []
			_check_text(bad, id + " guess.q", g["q"], MAX["q"])
			_check_text(bad, id + " guess.depart", g["depart"], MAX["depart"])
			if g["choices"].size() < 2 or g["choices"].size() > 3:
				bad.append("%s: guess.choices は 2〜3 こ" % id)
			for c in g["choices"]:
				if seen_places.has(c["place"]):
					bad.append("%s: guess の 場所「%s」が 2 回 ある" % [id, c["place"]])
				seen_places.append(c["place"])
				if not ORGAN_POS.has(c["place"]):
					bad.append("%s: guess の 場所「%s」が ORGAN_POS に ない" % [id, c["place"]])
				if place_label(c) == "":
					bad.append("%s: guess の 場所「%s」に label が いる" % [id, c["place"]])
				else:
					_check_text(bad, id + " guess.label", place_label(c), MAX["label"])
				_check_text(bad, id + " guess.say", c["say"], MAX["say"])
				if c.get("go", false):
					go += 1
				elif c.get("hit", false):
					bad.append("%s: guess の「%s」は hit なのに go で ない（はずれと 言った あとで あたりと 言う ことに なる）" % [id, c["place"]])
			if go == 0:
				bad.append("%s: guess に go: true の えらびが ない（行き止まりに なる）" % id)
		var n: int = ep["scenes"].size()
		if n < 1 or n > 3:
			bad.append("%s: scenes は 1〜3 こ" % id)
		for i in n:
			var sc: Dictionary = ep["scenes"][i]
			var where := "%s scene %d" % [id, i]
			if not StageDB.stage_ids().has(sc.get("place", "")):
				bad.append("%s: place「%s」が StageDB に ない" % [where, sc.get("place", "")])
				continue
			_check_text(bad, where + " intro", sc.get("intro", ""), MAX["intro"])
			for key in ["goal_say", "clear_say"]:
				if sc.has(key):
					_check_text(bad, where + " " + key, sc[key], MAX[key])
			if not (sc.get("hints") is Array):
				bad.append("%s: hints を 書く（無ければ []。場所の ヒントは 引きつがない）" % where)
			for h in sc.get("hints", []):
				_check_text(bad, where + " hints", h.get("text", ""), MAX["hint"])
				if h.has("text_touch"):
					_check_text(bad, where + " hints", h["text_touch"], MAX["hint"])
				if not h.has("at"):
					bad.append("%s: hints に at が ない" % where)
			if sc.has("arrow") and sc["arrow"] != "nearest":
				bad.append("%s: arrow は \"nearest\" だけ" % where)
			var ms: Array = sc.get("missions", [])
			if ms.is_empty() or ms[ms.size() - 1].get("type", "") != "reach":
				bad.append("%s: missions の さいごは reach に する" % where)
			for m in ms:
				if not MISSION_TYPES.has(m.get("type", "")):
					bad.append("%s: 知らない ミッション type「%s」" % [where, m.get("type", "")])
				_check_text(bad, where + " mission.text", m.get("text", ""), MAX["mission"])
				for t in m.get("each_say", []):
					_check_text(bad, where + " each_say", t, MAX["each_say"])
				if m.has("done_say"):
					_check_text(bad, where + " done_say", m["done_say"], MAX["done_say"])
			var spawn: Dictionary = sc.get("spawn", {})
			for key in spawn.keys():
				if not ["skip", "swap"].has(key):
					bad.append("%s: spawn の 知らない キー「%s」" % [where, key])
			for p in spawn.get("skip", []) + spawn.get("swap", {}).keys():
				if SPAWN_LOCKED.has(String(p).get_slice("_", 0)):
					bad.append("%s: spawn で %s は かえられない" % [where, p])
			if sc.has("after"):
				_check_text(bad, where + " after.banner", sc["after"].get("banner", "—"), MAX["banner"])
				_check_lines(bad, where + " after", sc["after"].get("lines", []))
				if sc["after"].has("lines_hit"):
					_check_lines(bad, where + " after.lines_hit", sc["after"]["lines_hit"])
		for key in ["what", "why", "next"]:
			_check_text(bad, "%s karte.%s" % [id, key], ep["karte"].get(key, ""), MAX["karte"])
		for key in ["thanks", "exit"]:
			if ep["karte"].has(key):
				_check_text(bad, "%s karte.%s" % [id, key], ep["karte"][key], MAX[key])
		var q: Dictionary = ep["quiz"]
		_check_text(bad, id + " quiz.q", q["q"], MAX["quiz_q"])
		_check_text(bad, id + " quiz.explain", q["explain"], MAX["explain"])
		if q["choices"].size() != 3 or int(q["answer"]) < 0 or int(q["answer"]) > 2:
			bad.append("%s: quiz は 3 たく、answer は 0〜2" % id)
		for c in q["choices"]:
			_check_text(bad, id + " quiz.choices", c, MAX["quiz_choice"])
	return bad
```

### 2.4 4〜10 話の スケッチ（データの 形が 足りる ことの 確認。くわしい 手順は 8 章）

| 話 | 患者 | よそうの `go`（★ ＝ `hit`） | 場面（場所：上書き → ミッション） | M1 に 無い もの |
|----|------|------------------------|----------------------------|---------------|
| ep04 ひざを すりむいた | kenta | skin★（`label`「ひざの ひふ（皮膚）」） | ① skin（新）：`collect platelet 6` → `deliver wound 6`・`defeat bacteria 3` → reach ② vessel：`hide_nodes: ["Cholesterol"]`、`skip: ["card_cholesterol", "sign_heart"]`、`swap` で rbc の 一部を wbc に → `cheer wbc 3`（はっけっきゅうを きずへ よぶ）→ reach。**ばいきんは ひふの 場面だけ**（けっかんの 中には 出さない。9.3） | 新しい 場所 `skin`、`deliver` の `item`、`hide_nodes`、kind：bacteria・platelet・wound |
| ep05 せきが とまらない | hana | nose★、lungs | ① nose：`reverse`、`flow_speed: 3.0`、`add` で virus 4 → `defeat virus 3` → reach ② lungs：`cheer wbc 3`・`boss`・reach（文は「はいほうに ひろがる まえに おいだす」。8 章） ③ nose：くしゃみで 出る | `spawn.add`、`reverse` |
| ep06 はなが むずむず | kenta | nose★ | ① nose：`flow_speed: 1.0`、`arrow: "nearest"`、`add` で pollen 5・mihari 3・exit 1 → `cheer mihari 3`（なだめる）・`collect pollen 5`・`deliver exit 5` → reach。てき なし | kind：pollen・mihari・exit、`deliver` の `item` |
| ep07 あたまが ぼんやり | papa | brain★ | ① brain：`add` で waste 6（しんけいから 4.5 m 以上 はなす）→ `sequence 3`・`collect waste 6`（そうじ）→ reach。てき なし | kind：waste、`add` の `near`、さいしょの リレーを intro の あとに |
| ep08 かいだんで いきが きれる | jiji | heart★（`label`「しんぞう（心臓）」） | ① vessel（「しんぞうの きんにくを めぐる ほそい けっかん」と 言う）：`flow_speed: 2.0` → `cheer rbc 5` → reach ② heart ③ heart2 | （つづきからは M1 で 作る） |
| ep09 なんか さいきん だるい（前編） | hana | vessel（`hit` なし：原因は まだ 分からない） | ① vessel：`hide_nodes`、`swap` で rbc の 一部を いそぐ wbc に、`add` で clue 3 → `collect clue 3`（`each_say` で 手がかりの ことば）→ reach ② heart：`add` で clue 2 → `gate 2`・`collect clue 2` → reach。さいごの `after` で「おおきな かげ」 | kind：clue・wbc_rush |
| ep10 （後編） | hana | lungs★（`consult` は ピコの おさらい 1 ページ） | ① lungs：`swap` で ボスを `boss_haien`、virus を bacteria に、`add` で medicine 2（`"after": 0` ＝ はっけっきゅうを おうえんし おわると とどく）、`bgm: "bgm_boss"` → `cheer wbc 3`（`done_say`：おくすりが とどいた）・`collect medicine 1`・`boss 1` → reach | Boss の CONFIG 化、おくすりの パワーアップ、`add` の `after`、`SEASON_COMPLETE = true` |

どの 話も「EPISODES に 1 件 ＋ Level の 小さな キー 1〜2 こ ＋ kind の 追加」で 入る。画面と 流れ（3 章）は 変えない。場面は どれも `hints` を 自分で 書く（けっかんの 場面で「きいろい かたまりは よけてね」が だまって 出たり しない）。

---

## 3. 画面と 流れ

### 3.1 状態遷移

```
タイトル ─[はじめる]→ カルテえらび(episode_select) ─[しんさつ スタート！]→ Game.start_episode(id)
   ▲ ui_cancel／← もどる        ▲  │                └[つづきから ▶]→ Game.resume_episode() ─→ after[おえた 場面]へ
   └───────────────────────────┤  └[クイズに もういちど ちょうせん]→ Game.review_karte(id) ─→ karte（紙から）
                                │ ui_cancel／← もどる（1 ページ目の とき）
        consult（talk.gd）──────┘   ※ はじめての ときだけ OPENING 1 ページが 前に つく（読みおえたら 既読）
            │ finished   ▲
            ▼            │ ui_cancel／← もどる（そうだんの さいごの ページへ。カルテえらびまで もどさない）
        guess（guess.gd）           ※ guess が 無い 話は とばす。はずれ → ヒント → えらびなおし（画面は そのまま）
            │ finished(first_guess)
   ┌──▶ scene[i]（Level）           intro（短い ひとこと）→ あそぶ → ゴール。**遊ぶ 前に カードは 出さない**
   │        │ cleared           ┌── ポーズ「カルテえらびへ」（おえた 場面までは「つづきから」で もどれる）
   │        │                   │   ポーズ「この ばめんを やりなおす」→ 同じ scene[i] を 最初から
   │        ▼ Game._on_level_cleared：ハートの 印と「つづき」を 記録 → [場所の カード（はじめて クリアした ときだけ）]
   │    after[i]（talk.gd）         ※ after が 無ければ とばす。Level は 先に 片づける。さいごの 場面の after ＝「ピコッと はっけん！」
   │        │ finished
   └────────┤ i+1 < 場面の 数
            ▼ さいごの 場面の あと
        karte（karte.gd：かいけつ → カルテの 紙 → クイズ → ほし）  ※ 入った ときに クリアを 記録し「つづき」を 消す
            ├─[カルテえらびへ]→ カルテえらび
            └─[つぎの カルテへ ▶]→ start_episode(つぎ)　／　さいごの 話 かつ SEASON_COMPLETE →［エンディングへ ▶］
```

- 流れは 一直線。よそうは 道順を 変えない（分岐の グラフは 作らない）。
- 「画面」と「Level」は 同時に 生きない：画面を 出す 前に かならず `unload_level()`（ポーズは `level != null` の ときしか 開かないので、画面の 上に ポーズは 出ない）。場所の カードだけは、クリアした Level の 上に ポップアップで 出る（いままでの ものしりカードと 同じ しくみ）。
- **はじめて 遊ぶ 子が 動きだす までの ボタン**：しんさつ スタート → OPENING 1 → そうだん 2 → よそう（えらぶ ＋ しゅっぱつ）＝ 6 回。場所の カードと 長い intro を 遊ぶ 前から 外した（第 1 版は 8 回 ＋ 9 秒の intro）。
- BGM：カルテえらび・そうだん・よそう ＝ `bgm_title`。場面 ＝ `stage.get("bgm")`、無ければ いまどおり `difficulty >= 3` で `bgm_boss`。after と karte は 鳴っている ものの まま。

### 3.2 `game.gd` の 変更（確認ずみ）

| 名前 | 新／変 | 内容 |
|------|:----:|------|
| `signal episode_finished(ep_id, stars)` | 新 | カルテ画面を 閉じた とき |
| `signal phase_changed(phase, index)` | 新 | フェーズに 入った とき（テストが 順番を 見る） |
| `signal said(text)` | 新 | HUD に 文が 出た とき（テストが `goal_say` などを 見る） |
| `signal stage_finished(stage_id, stars)` | 変 | Level を 1 つ クリアする たびに 出る（場面でも 場所モードでも）。`stars` は いつも 0 |
| `var episode`／`scene_index`／`phase`／`first_guess`／`_review` | 新 | いまの カルテ（空 ＝ 場所モード）、場面の 番号、フェーズ、さいしょの よそう、読みかえし中か |
| `show_episode_select()` | 変（改名） | 旧 `show_stage_select()`（121-124）。呼ぶ 側は `title.gd:84`、`pause.gd:41`、`shot.gd:34` |
| `start_episode(ep_id, from_phase := "consult", from_scene := 0, guess := "")` | 新 | カルテの 入口。うしろ 3 つの 引数は「つづきから」と テスト・撮影用（`start_episode("ep03", "scene", 1)`、`("ep03", "karte")`） |
| `resume_episode()` | 新 | つづきから：`SaveData.resume()` の 話を、**さいごに おえた 場面の `after`** から 始める（おさらいに なる。`after` が 無ければ 次の 場面か カルテへ） |
| `review_karte(ep_id)` | 新 | クリアずみの カルテの 紙と クイズだけ もういちど（クイズの ほしを 取りなおせる）。クリアの 記録も「つづき」も さわらない |
| `_enter(phase, back := false)` | 新 | フェーズの 切りかえは **ここ 1 か所**。データが 無い フェーズは 自分で 次へ 進む。`back` は よそうから そうだんへ もどる とき（さいごの ページを 出す） |
| `_after_done()`／`_on_karte_finished(go_next)` | 新 | つぎの 場面 or カルテへ／つぎの 話 or カルテえらびへ |
| `start_stage(place_id)` | 変 | 場所モード（名前は のこす。`--stage=`、`shot.gd` が 使う）。中身は `_start_level()` へ |
| `_start_level(stage: Dictionary)` | 新 | 旧 `start_stage` の 132-147 行。辞書を 受けとる |
| `retry_stage()` | 変 | カルテの 中なら いまの 場面だけ やりなおす（その 場面の ダメージは 数えない） |
| `_on_level_cleared(place_id, no_damage)` | 変 | 場所モード → カルテえらびへ。カルテ → ハートの 印（場面ごと）と「つづき」を 記録 → 場所の カード（はじめて クリアした ときだけ）→ `_enter("after")`。`ResultScreen` と `next_stage_id` の くさりは 消す |
| `_set_screen(c)` | 変 | タッチの ボタンを かならず かくす（OverlayLayer は 画面より 上。出た ままだと 下の ボタンを 押せない） |
| `screen()` | 新 | いまの 画面（テスト用） |
| `say(text, seconds, hold := 0.0)` | 変 | `hold` ＞ 0 は 物語の ひとこと（4.3）。HUD が 受けとったら `said` を 出す |
| `say_soft(text, seconds)` | 新 | おまけの ひとこと（チェックポイント など）：HUD が あいている ときだけ 出す（ヒントと 同じ きまり） |
| `show_ending()` | そのまま | `EpisodeDB.SEASON_COMPLETE` の ときだけ 呼ばれる（M1 では 呼ばれない） |
| `show_card()` `add_overlay()` `toggle_pause()` `hud_busy()` | そのまま | |

先頭（シグナル・preload・変数）：

```gdscript
extends Node
## ゲーム全体の進行（タイトル → カルテえらび → そうだん → よそう → 場面 1〜3 こ → カルテ）。
## 画面は src/ui/ の Control をコードで組み立てて UILayer に置く。

signal stage_started(stage_id: String)
signal stage_finished(stage_id: String, stars: int)
signal episode_finished(ep_id: String, stars: int)
signal phase_changed(phase: String, index: int)
signal said(text: String)      # HUD に 文が 出た（テストが 見る）

const UiThemeBuilder := preload("res://src/ui/ui_theme.gd")
const TitleScreen := preload("res://src/ui/title.gd")
const EpisodeSelectScreen := preload("res://src/ui/episode_select.gd")
const TalkScreen := preload("res://src/ui/talk.gd")
const GuessScreen := preload("res://src/ui/guess.gd")
const KarteScreen := preload("res://src/ui/karte.gd")
const ZukanScreen := preload("res://src/ui/zukan.gd")
const CardPopup := preload("res://src/ui/card.gd")
const PauseMenu := preload("res://src/ui/pause.gd")
const HudScene := preload("res://src/ui/hud.gd")
const TouchControlsScene := preload("res://src/ui/touch_controls.gd")
const LevelScene := preload("res://src/level/level.tscn")

var main: Node = null
var world: Node3D = null
var ui_layer: CanvasLayer = null
var overlay_layer: CanvasLayer = null

var theme: Theme
var font_regular: Font
var font_bold: Font

var current_stage_id := ""
var level: Node = null
var hud: Control = null
var touch_controls: Control = null
var _screen: Control = null
var _popup_open := false

## いまの カルテ（空なら「場所だけ」モード：テストと 撮影用）
var episode: Dictionary = {}
var scene_index := 0
var phase := ""            # "consult" / "guess" / "scene" / "after" / "karte" / ""
var first_guess := ""
var _review := false       # クリアずみの カルテを 読みかえして いる（クリアの 記録を しない）
```

画面と 流れ（旧 102-106 行の `_set_screen`、121-124 行の `show_stage_select`、131-147 行の `start_stage`、169-192 行の `retry_stage`・`_on_level_cleared`、255-258 行の `say` を 置きかえる。`unload_level()`・`_ensure_touch_controls()`・`show_ending()`・`show_card()` は いまの まま）：

```gdscript
func _set_screen(c: Control) -> void:
	_clear_screen()
	_screen = c
	c.theme = theme
	if touch_controls and is_instance_valid(touch_controls):
		touch_controls.visible = false   # OverlayLayer は 画面より 上。出た ままだと 下の ボタンを 押せない
	ui_layer.add_child(c)


func screen() -> Control:
	return _screen if _screen != null and is_instance_valid(_screen) else null


func show_episode_select() -> void:
	unload_level()
	episode = {}
	phase = ""
	Sfx.play_bgm("bgm_title")
	_set_screen(EpisodeSelectScreen.new())


# ---------------------------------------------------------------- カルテの 流れ
## カルテを 始める。from_phase / from_scene / guess は「つづきから」と テスト・撮影用（とちゅうから 入る）
func start_episode(ep_id: String, from_phase := "consult", from_scene := 0, guess := "") -> void:
	var ep := EpisodeDB.get_episode(ep_id)
	if ep.is_empty():
		show_episode_select()
		return
	unload_level()
	episode = ep
	scene_index = clampi(from_scene, 0, ep["scenes"].size() - 1)
	first_guess = guess
	_review = false
	Sfx.play_bgm("bgm_title")
	_enter(from_phase)


## 「つづきから」：さいごに おえた 場面の「あとの はなし」から 入る（おさらいに なる）。無ければ 次の 場面か カルテへ
func resume_episode() -> void:
	var r := SaveData.resume()
	if r.is_empty():
		show_episode_select()
		return
	start_episode(r["ep"], "after", int(r["cleared"]) - 1, r.get("guess", ""))


## クリアずみの カルテの 紙と クイズだけ もういちど（クイズの ほしを 取りなおせる）
func review_karte(ep_id: String) -> void:
	if not SaveData.is_cleared(ep_id):
		show_episode_select()
		return
	unload_level()
	episode = EpisodeDB.get_episode(ep_id)
	scene_index = 0
	first_guess = ""
	_review = true
	_enter("karte")


func _enter(p: String, back := false) -> void:
	phase = p
	match p:
		"consult":
			var lines: Array = episode["consult"]
			var opening: bool = not SaveData.data["opening_seen"]
			if opening:
				lines = EpisodeDB.OPENING + lines
			var t := TalkScreen.new()
			t.setup(lines, {"mood": "sick", "can_cancel": true, "start_page": lines.size() - 1 if back else 0, "last_label": "よそうする ▶" if episode.has("guess") else "しゅっぱつ！ ▶"})
			t.finished.connect(func():
				if opening:
					SaveData.data["opening_seen"] = true   # 読みおわってから 既読に（とちゅうで もどった 子には もう一度 出す）
					SaveData.save()
				_enter("guess"))
			t.cancelled.connect(show_episode_select)
			_set_screen(t)
		"guess":
			if not episode.has("guess"):
				_enter("scene")
				return
			var g := GuessScreen.new()
			g.setup(episode)
			g.finished.connect(func(first: String):
				first_guess = first
				_enter("scene"))
			g.cancelled.connect(func(): _enter("consult", true))   # もどる ＝ そうだんの さいごの ページへ
			_set_screen(g)
		"scene":
			_start_level(EpisodeDB.scene_stage(episode, scene_index))
		"after":
			var a: Dictionary = episode["scenes"][scene_index].get("after", {})
			if a.is_empty():
				_after_done()
				return
			unload_level()
			var last: bool = scene_index + 1 >= episode["scenes"].size()
			var t := TalkScreen.new()
			t.setup(EpisodeDB.after_lines(episode, scene_index, first_guess), {"mood": "sick", "banner": a.get("banner", ""), "last_label": "つぎへ ▶" if last else "つぎへ いこう ▶"})
			t.finished.connect(_after_done)
			_set_screen(t)
		"karte":
			unload_level()
			var id: String = episode["id"]
			if not _review:
				SaveData.record_clear(id)   # カルテを とちゅうで やめても クリアは のこる
				SaveData.clear_resume(id)
			var k := KarteScreen.new()
			k.setup(episode, {"guess_hit": EpisodeDB.guess_is_hit(episode, first_guess), "review": _review})
			k.answered.connect(func(correct: bool): SaveData.record_quiz(id, correct))
			k.finished.connect(_on_karte_finished)
			_set_screen(k)
	phase_changed.emit(p, scene_index)


func _after_done() -> void:
	if scene_index + 1 < episode["scenes"].size():
		scene_index += 1
		_enter("scene")
	else:
		_enter("karte")


func _on_karte_finished(go_next: bool) -> void:
	var id: String = episode["id"]
	episode_finished.emit(id, SaveData.stars(id))
	var next := EpisodeDB.next_id(id)
	if go_next and next != "":
		start_episode(next)
	elif go_next and EpisodeDB.SEASON_COMPLETE:
		show_ending()
	else:
		show_episode_select()


## 場所だけを 既定の ミッションで 開く（テスト・スクリーンショット用。子どもの 画面からは 来ない）
func start_stage(place_id: String) -> void:
	episode = {}
	phase = ""
	_start_level(StageDB.get_stage(place_id))


func _start_level(stage: Dictionary) -> void:
	unload_level()
	_clear_screen()
	current_stage_id = stage["id"]
	level = LevelScene.instantiate()
	level.setup(stage)
	world.add_child(level)
	hud = HudScene.new()
	hud.theme = theme
	ui_layer.add_child(hud)
	hud.bind_level(level)
	_ensure_touch_controls()
	Sfx.play_bgm(stage.get("bgm", "bgm_boss" if stage["difficulty"] >= 3 else "bgm_stage"))
	stage_started.emit(current_stage_id)
	level.cleared.connect(_on_level_cleared)
	level.begin()


## ポーズの「この ばめんを やりなおす」：いまの 場面だけ 最初から（そうだんへは もどらない）
func retry_stage() -> void:
	if episode.is_empty():
		start_stage(current_stage_id)
	else:
		_enter("scene")


func _on_level_cleared(place_id: String, no_damage: bool) -> void:
	stage_finished.emit(place_id, 0)
	if episode.is_empty():
		show_episode_select()
		return
	var id: String = episode["id"]
	SaveData.record_scene(id, scene_index, no_damage)          # ハートの 印は 場面ごと・回を またいで たまる
	SaveData.set_resume(id, scene_index + 1, first_guess)      # ここまでは「つづきから」で もどれる
	SaveData.mark_card(place_id, "summary")                    # 場所の「まとめ」は クリアで ずかんに 入る
	# 場所の ものしりカードは、はじめて クリアした あとに 1 回（遊ぶ 前の 文を へらす）
	var card: Dictionary = {} if SaveData.card_seen(place_id, "stage") else StageDB.card(place_id, "stage")
	show_card(card, func():
		SaveData.mark_card(place_id, "stage")
		_enter("after"), "stage", place_id)


## hold > 0 は 物語の ひとこと（出てから hold 秒は とっさの ひとことに 上書きされない）。Level.say_story() が 使う
func say(text: String, seconds := 4.0, hold := 0.0) -> void:
	if hud and is_instance_valid(hud) and hud.say(text, seconds, hold):
		said.emit(text)


## おまけの ひとこと（チェックポイント など）：ほかの 文が 出ている あいだは 出さない（ヒントと 同じ きまり）
func say_soft(text: String, seconds := 4.0) -> void:
	if not hud_busy():
		say(text, seconds)
```

注意：
- `_enter()` の 中で 次の フェーズへ 進む ときは `return` する（`phase_changed` を 2 回 出さない）。
- `OPENING` は **読みおえた とき**（そうだんの さいごの ボタン）に 既読に する。1 ページ目で「もどる」を 押した 子（B ボタンは ゲームでは ダッシュなので 押しやすい）には、次も 出る。
- よそうの「もどる」は そうだんの さいごの ページへ（`_enter("consult", true)`）。カルテえらびまで もどさない。この とき `phase_changed("consult")` が もう一度 出る。
- クリアの 記録は カルテ画面に **入った とき**（クイズを とちゅうで やめても クリアは のこる。いまの `game.gd:175` と 同じ 考え）。クイズの ほしは `answered` で 足す。
- **`_on_karte_finished()` は `episode_finished` を 出した あと、同じ 呼び出しの 中で 次の 話の `start_episode()` まで 進む**（＝ `phase_changed("consult")` が 続けて 出る）。テストは `episode_finished` の しゅんかんの フェーズ列を 写して くらべる（6.1）。
- 「つづき」は 1 つだけ（`SaveData.data["resume"]`）。場面を クリアする たびに 上書きし、その 話の カルテ画面に 入ると 消える。べつの 話を 最初から 始めても 消えない（その 話で 場面を 1 つ おえると 上書きされる）。
- 場所の ものしりカード（`cards.stage`）は、**はじめて クリアした あと**に 1 回 出す（遊ぶ 前の 文を へらす。2 話と 3 話で い（胃）の カードが 2 回 出ない）。`Level.begin()` は カードを 出さない（4.2）。場所モードでは 出ない。
- 画面は セーブを 書かない（`karte.gd` の 既読マーク 1 つを のぞく）。記録は `Game` が する。

### 3.3 画面の 共通の きまり

新しい 4 画面（カルテえらび・はなし・よそう・カルテ）は `src/ui/flow_screen.gd` を 継ぐ（確認ずみ）：

```gdscript
extends Control
## カルテの 流れの 画面（カルテえらび・はなし・よそう・カルテ）の 土台。
## - いつも どこかに フォーカスが ある ように 見はる（消えたら focus_target に もどす）
## - 押しすぎ よけ：lock() から 0.4 秒は locked() が true（ボタンは disabled に しない。フォーカスが 外れない ように）

const T := preload("res://src/ui/ui_theme.gd")

var focus_target: Control = null
var _lock := 0.0


func _process(delta: float) -> void:
	_lock = maxf(_lock - delta, 0.0)
	if focus_target != null and is_instance_valid(focus_target) and focus_target.is_visible_in_tree() \
			and get_viewport().gui_get_focus_owner() == null:
		focus_target.grab_focus()


func set_focus(c: Control) -> void:
	focus_target = c
	c.grab_focus()


func lock(seconds := 0.4) -> void:
	_lock = seconds


func locked() -> bool:
	return _lock > 0.0
```

- **フォーカス**：画面の 中身を 作りかえる たびに、子どもが 次に 押す ボタンへ `set_focus(btn)`。ヘッドレスで 確かめた こと：`disabled` に しても フォーカスは のこる／`focus_mode = FOCUS_NONE` に した 瞬間と、フォーカス中の ノードを `queue_free` した 瞬間に フォーカスは 消える。だから「押せなく する ボタン」は `disabled = true` ＋ `FOCUS_NONE` に して、**同じ 関数の 中で** 別の ボタンへ `set_focus()` する。見はり（`_process`）は 取りこぼしの 保険。
- **押しすぎ よけ**：`lock()`（0.4 秒）。ボタンの ハンドラの 先頭で `if locked(): return`。ボタンを `disabled` に しない（色が 変わって ちらつく・フォーカスの 事故の もと）。時間は `_process` の delta で 数える（`Time.get_ticks_msec()` は 使わない。テストは 実時間の 40 倍で 回るので、実時間の 0.4 秒は テストでは 16 秒に なる）。
- **入力**：キーボード・ゲームパッドは フォーカス中の ボタンに `ui_accept`（Enter／Space／Z／A ボタン。`game.gd:58`）、もどるは `ui_cancel`（Esc／X／B ボタン。`_unhandled_input` で 受ける）。タッチ・マウスは ボタンを 直接。ボタンの 高さは 76 px 以上。
- **時間で 勝手に 進まない**。読むのが おそい 子を 待つ。
- **`Game.testing` で 自動送り しない**（いまの `result.gd` の やりかたは やめる）。テストは フォーカス中の ボタンを 押して 進める（6.1）。これで「フォーカスが ある」ことが 毎回 テストされ、`shot.gd` で `Game.testing = false` に する 小細工も いらない。
- **レイアウト**：`set_anchors_and_offsets_preset(PRESET_FULL_RECT)` の 背景 ＋ 画面中央の 固定の 入れ物（anchor 0.5、offset で 大きさを 決める。`stage_select.gd:41-52`・`result.gd:27-37` と 同じ）。下の 座標は 1280×720 の ときの、入れ物の 中での 位置。
- `const T`（`ui_theme.gd`）は 土台に ある。継いだ 側で もう一度 `const T` を 書くと エラーに なる。
- テーマは `Game._set_screen()` が 付ける（CLAUDE.md の 落とし穴）。

### 3.4 各画面

#### A. カルテえらび `src/ui/episode_select.gd`（`stage_select.gd` を `git mv` して 作りかえ）

- 背景 `Color(0.93, 0.95, 1.0)`。左上「← もどる」（24, 20）→ `Game.show_title()`。見出し「きょうの カルテ」40 px（`stage_select.gd:27-38` と 同じ）。
- 中央の `HBoxContainer`（offset ±570、top 80、bottom 700、separation 40）：
  - **左**：`ScrollContainer`（540×620、`follow_focus = true`、横スクロールなし。`zukan.gd:26-34` と 同じ）＞ `VBoxContainer`（separation 12）。話ごとに 行の `Button`（520×104、`text = ""`）。中に `HBoxContainer`（`mouse_filter = IGNORE`）：患者の 顔 76×76（`T.portrait(patient, "happy" if クリアずみ else "sick", …)`）／「カルテ 1」20 px ＋ だいめい 28 px ／ 小さい ほし 3 つ（`T.star_points` r=13、`SaveData.star_flags(id)`）。
    - 色：クリアずみ ＝ `T.YELLOW`、開いている ＝ `T.SKY`、まだ ＝ 灰色（`stage_select.gd:80-86` の 3 色）。
    - まだ 開いていない 行：だいめいを「？？？」、`disabled = true` ＋ `FOCUS_NONE`、顔と ほしは 出さない。
    - 行の 下に、`not EpisodeDB.SEASON_COMPLETE` なら ラベル「つづきの カルテは じゅんびちゅう！」22 px 灰色。
  - **右**：`PanelContainer`（580×600）＞ `VBoxContainer`。`_select(id, go_to_start)` で 作りなおす：「カルテ 1」20 px 灰色 ／ だいめい 40 px（12 字以上は 32 px）／ 患者の 顔 120×120（sick）＋「かんじゃさん： はなちゃん」24 px ＋ そうだんの 1 ページ目（`consult[0]["text"]`）を ふきだしで 24 px ／「むずかしさ： かんたん」22 px ／ 大きい ほし 3 つ（r=22）／ すきま ／ ボタン「しんさつ スタート！」36 px・幅 320・`T.YELLOW` → `Game.start_episode(id)`。
  - **めぐる 場所と ミッションは 見せない**（よそうの ねたばれ）。
- フォーカス：最初は「まだ クリアして いない 最初の 開いている 話、無ければ 1 話」を `_select(id, true)` → スタートボタンに `set_focus`。行に フォーカス → `_select(id, false)`。行を 押す → `_select(id, true)`。行 → 右 ＝ スタート、スタート → 左 ＝ えらんだ 行（`stage_select.gd:160-166` の つなぎ）。上下は 行の 間。`_select()` は 右の パネルを 作りなおす たびに `focus_target = _start_btn` を 入れなおす（`go_to_start` の ときだけ `grab_focus()`。行に フォーカスが ある ときは うばわない）。
- `ui_cancel` → `Game.show_title()`。
- 解放：`SaveData.is_unlocked(id)`（1 話、または 前の 話が クリア、または `unlock_all`）。

#### B. はなし `src/ui/talk.gd`（新規。そうだん・あとの はなし の 両方）

- `setup(lines: Array, opts := {})`。`opts`：`mood`（`"sick"`／`"happy"`。患者の 顔）、`banner`（上の 大きな 見出し）、`last_label`（さいごの ページの ボタン。既定「つぎへ ▶」）、`can_cancel`（最初の ページで もどれるか）。シグナル `finished`、`cancelled`。
- 背景：`T.art("consult_bg")` が あれば 全面に、無ければ `Color(1.0, 0.96, 0.9)`。
- 入れ物 1180×640：
  - `banner`（ある とき）：(0, 0)〜(1180, 80)、48 px、中央、色 `Color(0.25, 0.5, 0.75)`（**赤に しない**。まちがいの 色に 見せない）。出る ときに ぽよん（scale 0.7 → 1.0、`card.gd:88-91` と 同じ）＋ `Sfx.play("card")`。
  - 話す 人の 絵：(30, 110) 300×400。`T.portrait(who, mood, Vector2(300, 400), color, true)`。話す 人が 変わったら 作りなおす。
  - 名前：(370, 112) 24 px、色は 話す 人の 色を `darkened(0.45)`。
  - ふきだし：`PanelContainer` (370, 150) 770×320、`T.rounded(Color.WHITE, 30, 6, 話す人の色)`。中の ラベルは 32 px、`Game.font_regular`、自動おりかえし。**ふきだしを タップしても 次へ**（`gui_input` の 左クリック → `_on_next()`）。
  - ページの まる：(370, 484) 20 px「● ○ ○」。
  - 次へ：`Button` (860, 548) 280×76、`T.YELLOW`。文は さいごの ページだけ `last_label`。
  - 「← もどる」：画面の 左上（24, 20）、`can_cancel` の ときだけ → `cancelled`。
- 動き（確認ずみの 骨組み）：

```gdscript
func _show() -> void:              # ページを 出す たびに
	…（絵・名前・ふきだし・まる・ボタンの 文を 入れかえる）
	set_focus(_next)
	lock()

func _on_next() -> void:
	if locked():
		return
	Sfx.play("click")
	if page + 1 < lines.size():
		page += 1
		_show()
	else:
		finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if page > 0:
			page -= 1          # 1 ページ もどる（読みなおせる）
			_show()
		elif opts.get("can_cancel", false):
			cancelled.emit()
		get_viewport().set_input_as_handled()
```

- `Game` からの 呼びかた：そうだん ＝ `{"mood": "sick", "can_cancel": true, "last_label": "よそうする ▶"}`（よそうが 無い 話は「しゅっぱつ！ ▶」）。あとの はなし ＝ `{"mood": "sick", "banner": …, "last_label": "つぎへ いこう ▶"}`。

#### C. よそう `src/ui/guess.gd`（新規）

- `setup(ep: Dictionary)`。シグナル `finished(first_guess: String)`、`cancelled`。`var buttons: Dictionary`（place → えらぶ ボタン。テストが 見る）。
- 背景 `Color(0.93, 0.95, 1.0)`。見出し「よそうして みよう！」40 px。左上「← もどる」→ `cancelled`。
- 入れ物 1180×640：
  - **からだの地図** (10, 10) 440×620。絵は `bodymap_<患者>.png` → `bodymap_hana.png` → `body_map.svg` の 順（`stage_select.gd:58-69` を 移す）。どれも 無ければ `_draw_body`（`stage_select.gd:172-184` を 移す）。
  - **しるし**：えらび i ごとに 丸い `Button` 76×76（`EpisodeDB.ORGAN_POS[place] * 地図の大きさ − 38`）、文字「Ａ」「Ｂ」「Ｃ」30 px、色 `[T.PINK, T.MINT, T.YELLOW][i]`、`FOCUS_NONE`（ゲームパッドの 順番を 右の 縦 1 列だけに する）。タップ → `choose(place)`。
  - **ピコの ふきだし** (480, 10) 690×210：ピコの 顔 90×90 ＋「ドクター・ピコ」18 px ＋ 本文 26 px（`font_regular`、自動おりかえし）。最初は `guess.q`。
  - **えらぶ ボタン** (480, 240 + i × 98) 690×84：「Ａ　くち（口）」32 px 左よせ（名前は `EpisodeDB.place_label(choice)`）。色は しるしと 同じ（`T.colored_button(b, 色, 色.darkened(0.25))`）。フォーカスが 来たら その しるしを 1.25 倍に。
  - **しゅっぱつ** (830, 552) 340×80「しゅっぱつ！ ▶」34 px `T.YELLOW`。はじめは 見えない。
- フォーカス：最初は 1 つめの えらぶ ボタン。上下で 動く。
- 動き（確認ずみ。見た目の 行を 足す）：

```gdscript
func choose(place: String) -> void:
	if locked() or _go.visible:
		return
	var g: Dictionary = ep["guess"]
	var c: Dictionary = {}
	for x in g["choices"]:
		if x["place"] == place:
			c = x
	if c.is_empty() or buttons[place].disabled:
		return
	if first == "":
		first = place                    # さいしょの よそう（カルテで 原因と くらべる）
	lock()
	if c.get("go", false):
		Sfx.play("quiz_ok")
		_say.text = c["say"] + "\n" + g["depart"]
		for k in buttons.keys():         # もう えらべない。えらんだ ボタンは 色を のこす
			buttons[k].disabled = true
			buttons[k].focus_mode = Control.FOCUS_NONE
		_go.visible = true
		set_focus(_go)
	else:
		Sfx.play("card")                 # 「wrong」の 音は 使わない
		_say.text = c["say"]
		buttons[place].text += "（しらべたよ）"
		buttons[place].disabled = true
		buttons[place].focus_mode = Control.FOCUS_NONE
		for x in g["choices"]:           # のこりの 上から 1 つめへ フォーカス
			if not buttons[x["place"]].disabled:
				set_focus(buttons[x["place"]])
				break
```

- 「しゅっぱつ！ ▶」→ `if not locked(): finished.emit(first)`。`ui_cancel` → `cancelled`。
- **行き止まりに ならない 理由**：`go` の えらびは `disabled` に ならない。はずれは 多くて 2 回。`validate()` が「`go` が 1 つ 以上」を 保証する。
- 画面は「せいかい／ざんねん」と 言わない。はずれの ボタンは 灰色の「しらべたよ」に なるだけ。ほしにも 入れない。

#### D. カルテ `src/ui/karte.gd`（`result.gd` を `git mv` して 作りかえ）

- `setup(ep, no_damage: bool, guess_hit: bool)`。シグナル `answered(correct: bool)`、`finished(go_next: bool)`。
- 背景 `Color(1.0, 0.92, 0.8)`、中央の `PanelContainer` 940×600 ＋ `_vb`（`result.gd:22-44` の まま）。段ごとに `_clear()` → 作りなおし → `lock()` → 主ボタンに `set_focus()`。ボタンの ハンドラは みな `if locked(): return` から。

| 段 | 中身 | 主ボタン |
|----|------|---------|
| 0 かいけつ | 「かいけつ！」48 px ピンク・中央 ／「カルテ 1　は（歯）が ズキズキ」26 px ／ 患者の 顔 170×170（`happy`）＋ 名前 22 px ＋ `karte.thanks` 28 px ／ `karte.exit` 24 px（`font_regular`）。`Sfx.play("clear")`。`thanks`・`exit` が 無ければ その 行を 出さない | 「カルテを かく ▶」 |
| 1 カルテ | `SaveData.mark_card(ep["id"], "karte")`。見出し 3 つ（24 px、色つき）＋ 本文（26 px、`font_regular`、自動おりかえし）：「なにが おきていた？」`Color(0.9, 0.35, 0.5)`、「どうして？」`Color(0.3, 0.5, 0.75)`、「これからは？」`Color(0.25, 0.6, 0.45)`。`guess_hit` なら 下に「★ きみの さいしょの よそう、あたっていたね！」24 px `Color(0.75, 0.55, 0.2)`。挿絵 `cards/card_<ep>_karte`（220×250）が あれば 左に（`result.gd:103-112` と 同じ） | 「クイズに ちょうせん！」 |
| 2 クイズ | `result.gd:122-145` の まま（`ep["quiz"]`、えらびは まぜる）。`Game.testing` の 分岐は 消す | 1 つめの えらび |
| 3 ほし | まず `answered.emit(correct)`（`Game` が 記録する）→ `var f := SaveData.star_flags(ep["id"])`。「せいかい！」／「おしい！」48 px、`explain`、ほし 3 つ（`f`）、「● カルテ かんせい！」「● ハートを へらさずに」「● クイズに せいかい」（まだの 行は「○ …（また こんど！）」灰色）、「ほし 2 こ！」 | 「つぎの カルテへ ▶」（`EpisodeDB.next_id(id) != ""` の とき）→ `finished(true)`。さいごの 話で `SEASON_COMPLETE` なら「エンディングへ ▶」。どちらも 無ければ「カルテえらびへ」が 主ボタン |

- 段 3 には いつも「カルテえらびへ」→ `finished(false)` を 出す。
- クイズの はずれは「おしい！」（`Sfx.play("wrong")` は いまの まま）。ほしは 回を またいで たまる（5.2）ので、つぎの 回で 取れる。
- `ui_cancel` は 何も しない（もどる 先が 無い）。

#### E. そのほかの 画面

| ファイル | 変更 |
|---------|------|
| `pause.gd:37-42` | 「さいしょから やりなおす」→「この ばめんを やりなおす」（`Game.retry_stage()` の まま）。「ステージえらびへ」→「カルテえらびへ」（`Game.show_episode_select()`） |
| `title.gd` | 84 行「はじめる」→ `Game.show_episode_select()`。54・104 行の 分母 → `EpisodeDB.EPISODES.size() * 3`。50 行 → `EpisodeDB.ENDING` |
| `hud.gd:112` | `"%s（%s）" % [l.stage["name"], l.stage["kanji"]]`（番号を 出さない。場面の「1 / 2」も 出さない：3 話の「ちがった！」の ねたばれに なる） |
| `hud.gd:95,170-180` | `_draw_pico` を `ui_theme.gd` の `T.draw_pico(ci, center, r)` へ 移し、HUD は `T.draw_pico(face, Vector2(45, 48), 34.0)` を 呼ぶ |
| `card.gd:72` | `T.label(card.get("tag", "ものしりカード"), …)`（ずかんの カルテは「カルテ 1」と 出る） |
| `card.gd:98` | `if kind in ["stage", "goal", "karte", ""]: model_name = "pico"` |
| `zukan.gd` | 5.3 |

子どもに 見える 決まり文句（そのまま 使う）：
「きょうの カルテ」「← もどる」「カルテ 1」「？？？」「つづきの カルテは じゅんびちゅう！」「かんじゃさん： 」「むずかしさ： かんたん／ふつう／むずかしい」「しんさつ スタート！」「つぎへ ▶」「よそうする ▶」「しゅっぱつ！ ▶」「つぎへ いこう ▶」「よそうして みよう！」「（しらべたよ）」「ドクター・ピコ」「かいけつ！」「カルテを かく ▶」「なにが おきていた？」「どうして？」「これからは？」「★ きみの さいしょの よそう、あたっていたね！」「クイズに ちょうせん！」「せいかい！」「おしい！」「● カルテ かんせい！」「● ハートを へらさずに」「● クイズに せいかい」「（また こんど！）」「ほし 2 こ！」「カルテえらびへ」「つぎの カルテへ ▶」「エンディングへ ▶」「この ばめんを やりなおす」「クリア！」

### 3.5 仮の 見た目と 差しかえ口

`ui_theme.gd` に 足す（どれも static）：

```gdscript
## 患者・ピコの 絵。<who>_face_<mood>.png（prefer_full なら 先に <who>_fullbody_<mood>.png）が あれば それ。
## 無ければ コードで 描く 仮の 顔（ピコは いまの HUD の 顔）。
static func portrait(who: String, mood: String, size: Vector2, color: Color, prefer_full := false) -> Control:
	var names: Array[String] = []
	if prefer_full:
		names.append("%s_fullbody_%s" % [who, mood])
	names.append("%s_face_%s" % [who, mood])
	if who == "pico":
		names.append("pico_face_normal")
	for n in names:
		var tr := art_rect(n, size)
		if tr:
			return tr
	var c := Control.new()
	c.custom_minimum_size = size
	c.size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var r := minf(c.size.x, c.size.y) * 0.38
		if who == "pico":
			draw_pico(c, c.size * 0.5, r)
		else:
			draw_face(c, c.size * 0.5, r, color, mood))
	return c

static func draw_pico(ci: CanvasItem, c: Vector2, r: float) -> void   # hud.gd:170-180 を r=34 基準の 比で 書きなおす
static func draw_face(ci: CanvasItem, c: Vector2, r: float, color: Color, mood: String) -> void
	# はだ色 Color(1.0, 0.9, 0.8) の 丸 ＋ 上半分に 患者の 色の かみ ＋ 目 2 つ ＋ 口（happy：にっこりの 弧／sick：への字の 弧 ＋ 水色の あせ 1 つぶ）
```

呼ぶ 側は `EpisodeDB.speaker(who)["color"]` を 渡す。

絵が 届いたら 置くだけで 差しかわる もの（M1 で 口を 作る。`docs/dashboard.md` 4 章の 表に 足す）：

| 絵 | 置き場所（`godot/assets/ui/`） | 使う 画面 |
|----|---------------------------|----------|
| 患者の 顔 | `<who>_face_sick.png`、`<who>_face_happy.png`（who ＝ hana／kenta／papa／jiji） | カルテえらび・はなし・カルテ |
| 患者の 全身 | `<who>_fullbody_sick.png`、`<who>_fullbody_happy.png` | はなし（顔より 先に さがす） |
| ピコの 顔 | `pico_face_normal.png`（いまの 口） | はなし・よそう |
| からだの地図 | `bodymap_<who>.png`（無ければ `bodymap_hana.png` → SVG） | よそう |
| そうだんの 背景 | `consult_bg.png` | はなし |
| カルテの 挿絵 | `cards/card_<ep>_karte.png`（`card_ep01_karte.png`） | カルテ・ずかん |

同時に 発注書へ 追記する（CLAUDE.md の 約束。文面は 7 章の 手順 6）。

---

## 4. Level の 変更

Level は 話を 知らない。`stage` 辞書（場所の 写し ＋ 場面の 上書き）を 読むだけ。

### 4.1 一覧

| # | 場所（いまの 行） | 変更 |
|---|----------------|------|
| 1 | `begin()` 102-117 | 物語カード（`STORY_INTRO`・`story_seen`）を 消す。場所の カードは **まだ 見て いない ときだけ**（2 話と 3 話で い（胃）の カードが 2 回 出ない） |
| 2 | `_collect_markers()` 227-236 | `spawn` の `skip`／`swap` を マーカー名に かける。合う マーカーが 無い ルールは `data_warnings` へ |
| 3 | `_build_missions()` 458-468 | さいごに `_fit_missions()`。`progressed` を `_on_mission_progressed` に つなぐ |
| 4 | `_on_mission_completed()` 478-483 | `done_say` |
| 5 | `_update_goal_lock()` 498 | `stage.get("goal_say", いまの文)` |
| 6 | `finish()` 565 | `stage.get("clear_say", "クリア！")` |
| 7 | 変数 | `var data_warnings: Array[String] = []` |
| 8 | `mission.gd` 7-21 | `done_say`・`each_say` |
| 9 | `hud.gd:112` | 3.4 E |

### 4.2 はじまりと マーカー（確認ずみ）

```gdscript
func begin() -> void:
	# 場所の カードは はじめての ときだけ（同じ 場所に 何度も 行くので）
	var card: Dictionary = {} if SaveData.card_seen(stage_id, "stage") else stage["cards"].get("stage", {})
	var intro: String = stage.get("intro", "")
	Game.show_card(card, func():
		SaveData.mark_card(stage_id, "stage")
		started = true
		if intro != "":
			Game.say(intro, 9.0), "stage", stage_id)
```

```gdscript
func _collect_markers() -> void:
	markers.clear()
	var rules: Dictionary = stage.get("spawn", {})
	var used := {}
	for n in env.find_children("MK_*", "Node3D", true, false):
		(n as Node3D).visible = false
		var mk_name := _apply_spawn_rules(String(n.name), rules, used)
		if mk_name == "":
			continue
		var parts: PackedStringArray = mk_name.split("_")
		if parts.size() < 2:
			continue
		var kind := String(parts[1])
		var rest: Array = Array(parts.slice(2))
		markers.append({"node": n, "kind": kind, "rest": rest, "name": mk_name, "position": (n as Node3D).global_position, "basis": (n as Node3D).global_transform.basis})
	for p in rules.get("skip", []) + rules.get("swap", {}).keys():
		if not used.has(p):
			data_warnings.append("%s: spawn の「%s」に 合う マーカーが ない" % [stage_id, p])


## 場面の spawn ルールを マーカー名に かける。"" を 返したら その マーカーは 出さない。
##   "skip": ["enemy_pylori"]                       名前が この 語で 始まる マーカーを 出さない
##   "swap": {"friend_rbc_2": "friend_wbc"}        種類を 読みかえる（のこりの 番号は そのまま）
## 合わせかた：「MK_」を 取った 名前が p と 同じ、または p + "_" で 始まる。
static func _apply_spawn_rules(mk_name: String, rules: Dictionary, used: Dictionary) -> String:
	var key := mk_name.substr(3)
	if rules.is_empty() or key.get_slice("_", 0) in ["player", "goal", "path", "checkpoint"]:
		return mk_name
	for p in rules.get("skip", []):
		if key == p or key.begins_with(String(p) + "_"):
			used[p] = true
			return ""
	var swap: Dictionary = rules.get("swap", {})
	for p in swap.keys():
		if key == p or key.begins_with(String(p) + "_"):
			used[p] = true
			return "MK_" + String(swap[p]) + key.substr(String(p).length())
	return mk_name
```

- ルールは「マーカーの 名前を 読みかえる」だけ。`_spawn_all()`・`_markers_of()`・`_fallback_env()` は 変えない。
- `swap` の 例：`{"friend_rbc_2": "friend_wbc"}` → `MK_friend_rbc_2` は `MK_friend_wbc_2` として 読まれる。
- あとで 足す `spawn.add`（8 章 ep5）も、この `markers` 配列に 辞書を 足すだけで 入る（`_spawn_all()` は 配列しか 見ない）。

### 4.3 ミッションの 守りと 文（確認ずみ）

```gdscript
func _build_missions() -> void:
	missions.clear()
	for d in stage.get("missions", []):
		var m := MissionScript.from_dict(d)
		if m.type == "sequence":
			m.count = int(d.get("count", 3))
		m.progressed.connect(_on_mission_progressed)
		m.completed.connect(_on_mission_completed)
		missions.append(m)
	_fit_missions()
	missions_changed.emit()
	_update_goal_lock()


func _count_markers(kind: String, sub := "") -> int:
	var n := 0
	for m in markers:
		if m["kind"] == kind and (sub == "" or _kind_and_index(m["rest"], "")["kind"] == sub):
			n += 1
	return n


## 出てこない ものを 数える ミッションが あると ゴールが 開かない。出る 数に 合わせ、0 なら 外す。
func _fit_missions() -> void:
	var keep: Array[Mission] = []
	for m in missions:
		var have := m.count
		match m.type:
			"defeat": have = _count_markers("enemy", m.target)
			"boss": have = _count_markers("boss")
			"cheer": have = _count_markers("friend", m.target)
			"collect": have = _count_markers("pickup", m.target)
			"deliver": have = _count_markers("pickup", "nutrient") if _count_markers("deliver") > 0 else 0
			"gate": have = gates.size()
			"sequence": have = m.count if neurons.size() >= 2 else 0
		if have < m.count:
			data_warnings.append("%s: ミッション「%s」は %d こ いるが、出るのは %d こ" % [stage_id, m.text, m.count, have])
			m.count = have
		if m.count > 0 or m.is_reach():
			keep.append(m)
	missions = keep
```

```gdscript
func _on_mission_progressed(m: Mission) -> void:
	missions_changed.emit()
	if m.current < m.count and m.current >= 1 and m.current <= m.each_say.size():
		Game.say(m.each_say[m.current - 1], 3.0)


func _on_mission_completed(m: Mission) -> void:
	Sfx.play("mission")
	if not m.is_reach() and not _non_reach_done():
		Game.say(m.done_say if m.done_say != "" else "やったね！「%s」クリア！" % m.text, 3.5)
	_update_goal_lock()
	missions_changed.emit()
```

`_update_goal_lock()`（498 行）と `finish()`（565 行）：

```gdscript
			Game.say(stage.get("goal_say", "やったね！ ぜんぶ できた！ きいろい わっかの ゴールへ いこう！"), 5.0)
	…
	Game.say(stage.get("clear_say", "クリア！"), 3.0)
```

`mission.gd`：

```gdscript
var done_say := ""          # この ミッションが おわった ときの ピコの ひとこと（無ければ 決まり文句）
var each_say: Array = []    # 1 つ すすむ たびの ひとこと（i ばんめ）
	…（from_dict の 中）
	m.done_say = d.get("done_say", "")
	m.each_say = d.get("each_say", [])
```

- 数は **マーカーの 配列から** 数える（グループから 数えない。前の Level は `queue_free` で フレームの 終わりまで グループに のこる）。
- わざと こわした データ（3 話の い（胃）に `defeat pylori 4` を 足し、`cheer` を 5 に、`skip` に つづりちがいを 1 つ）で 確かめた 結果：ゴールは 開いて 話は 最後まで 進み、テストは 3 件の 警告で 失敗に なる。
- `Mission.add()` は `progressed` → `done = true` → `completed` の 順（`mission.gd:24-31`）。だから `each_say` の 条件は `m.current < m.count`（`not m.done` では さいごの 1 つも 出てしまう）。
- 文が 出る 順：すすむ たびに `each_say[i]` → ミッションが おわると `done_say`（まだ ほかに 残っている とき）→ ぜんぶ おわると `goal_say` → ゴールで `clear_say`。ヒントは いまどおり `Game.hud_busy()` を 見るので、これらを 上書きしない。

### 4.4 カード

- ものしりカードは 場所の もの（`stage["cards"]`、既読キー `場所id/key`、挿絵 `card_<場所id>_<key>.png`）。変更なし。
- 出さなかった 生き物の カードは 出ない（`_add_card_point()` は スポーンの ときに 呼ばれる）。`MK_card_acid` の ような 点は のこる（いえきの いけは 3 話でも ある ので 正しい）。点ごと 消したければ `skip: ["card_acid"]`。
- 場所の「きょうの まとめ」（`summary`）は、いままで けっか画面で 既読に していた（`result.gd:94`）。これからは **場面を クリアした ときに 既読に する**（`Game._on_level_cleared`。ポップアップは 出さない。ずかんで 読める）。

### 4.5 変えない もの

`_spawn_all()`、`current_target_position()`、しんけいパズル、なみ（`stage_id == "esophagus"`）、`_on_delivered()` の 文、プレイヤー、てき、なかま、`autopilot.gd`、`probe.gd`、GLB。

---

## 5. セーブ・ほし・ずかん

### 5.1 `save_data.gd`（version 2。全文・確認ずみ）

```gdscript
extends Node
## セーブデータ（user://save.json）。カルテごとの ほし・つづき・見た カード・設定。version 2。

var path := "user://save.json"
var data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()


func _defaults() -> Dictionary:
	return {
		"version": 2,
		"episodes": {},        # ep_id -> {"clear": bool, "quiz": bool, "nd": [bool, …]}（nd[i] ＝ 場面 i を ハートを へらさずに クリアした ことが ある）
		"resume": {},          # とちゅうの カルテ：{"ep": id, "cleared": おえた 場面の 数（1〜）, "guess": さいしょの よそう}。無ければ 空
		"cards_seen": [],      # "場所id/key" と "epNN/karte"
		"opening_seen": false,
		"settings": {"volume": 0.8, "touch": "auto", "unlock_all": false},
	}


## テスト・撮影用：べつの ファイルを 使う（本物の セーブを さわらない）
func use_path(p: String) -> void:
	path = p
	load_data()


func load_data() -> void:
	data = _defaults()
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK or not (json.data is Dictionary):
		return   # こわれた ファイル：既定値で 始める（つぎの save() で 上書き）
	var parsed: Dictionary = json.data
	var ver := int(parsed["version"]) if typeof(parsed.get("version")) in [TYPE_INT, TYPE_FLOAT] else 1
	# どの 版でも 引きつぐ：設定と 見た カード（カードの キーは v1 から「場所id/key」の まま）
	if parsed.get("settings") is Dictionary:
		for k in data["settings"].keys():
			if typeof(parsed["settings"].get(k)) == typeof(data["settings"][k]):
				data["settings"][k] = parsed["settings"][k]
	if parsed.get("cards_seen") is Array:
		for c in parsed["cards_seen"]:
			if c is String and not data["cards_seen"].has(c):
				data["cards_seen"].append(c)
	if ver != 2:
		# v1（ステージごとの ほし）や 知らない 版：ほしと クリアは 引きつがない。元の ファイルは 写して のこす
		DirAccess.copy_absolute(path, "%s.v%d.json" % [path.get_basename(), ver])
		save()
		return
	if parsed.get("opening_seen") is bool:
		data["opening_seen"] = parsed["opening_seen"]
	if parsed.get("episodes") is Dictionary:
		for id in parsed["episodes"].keys():
			var e = parsed["episodes"][id]
			if e is Dictionary:
				var nd: Array = []
				if e.get("nd") is Array:
					for v in e["nd"]:
						nd.append(_yes(v))
				data["episodes"][String(id)] = {"clear": _yes(e.get("clear")), "quiz": _yes(e.get("quiz")), "nd": nd}
	var r = parsed.get("resume")
	if r is Dictionary and r.get("ep") is String and typeof(r.get("cleared")) in [TYPE_INT, TYPE_FLOAT]:
		var n := EpisodeDB.scene_count(r["ep"])   # 知らない 話なら 0
		if int(r["cleared"]) >= 1 and int(r["cleared"]) <= n:
			data["resume"] = {"ep": r["ep"], "cleared": int(r["cleared"]), "guess": r["guess"] if r.get("guess") is String else ""}


## true の ときだけ true（JSON の 数や 文字と「== true」で くらべると 型の エラーに なる）
static func _yes(v) -> bool:
	return v is bool and v


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func reset() -> void:
	data = _defaults()
	save()


func _entry(ep_id: String) -> Dictionary:
	if not data["episodes"].has(ep_id):
		data["episodes"][ep_id] = {"clear": false, "quiz": false, "nd": []}
	var e: Dictionary = data["episodes"][ep_id]
	e["nd"].resize(EpisodeDB.scene_count(ep_id))
	for i in e["nd"].size():
		e["nd"][i] = _yes(e["nd"][i])
	return e


## 場面ごと：ハートを へらさずに クリアした ことが あるか
func scene_flags(ep_id: String) -> Array[bool]:
	var out: Array[bool] = []
	var nd: Array = data["episodes"].get(ep_id, {}).get("nd", [])
	for i in EpisodeDB.scene_count(ep_id):
		out.append(i < nd.size() and _yes(nd[i]))
	return out


## [カルテ かんせい, 全部の 場面で ハートを へらさずに, クイズ せいかい]。2 つめ・3 つめは クリアして はじめて つく
func star_flags(ep_id: String) -> Array[bool]:
	var e: Dictionary = data["episodes"].get(ep_id, {})
	var clear: bool = e.get("clear", false)
	var sf := scene_flags(ep_id)
	return [clear, clear and not sf.is_empty() and not sf.has(false), clear and e.get("quiz", false)]


func stars(ep_id: String) -> int:
	return star_flags(ep_id).count(true)


func is_cleared(ep_id: String) -> bool:
	return data["episodes"].get(ep_id, {}).get("clear", false)


## 場面を クリアした（ほしの 印は 回を またいで たまる。1 回 とった 印は 消えない）
func record_scene(ep_id: String, scene: int, no_damage: bool) -> void:
	var e := _entry(ep_id)
	if scene >= 0 and scene < e["nd"].size():
		e["nd"][scene] = e["nd"][scene] or no_damage
	save()


func record_clear(ep_id: String) -> void:
	_entry(ep_id)["clear"] = true
	save()


func record_quiz(ep_id: String, correct: bool) -> void:
	var e := _entry(ep_id)
	e["quiz"] = e["quiz"] or correct
	save()


## とちゅうの カルテ（無ければ 空の 辞書）
func resume() -> Dictionary:
	return data["resume"]


func set_resume(ep_id: String, cleared: int, guess: String) -> void:
	data["resume"] = {"ep": ep_id, "cleared": cleared, "guess": guess}
	save()


## ep_id の つづきを 消す（"" なら どの 話でも）
func clear_resume(ep_id := "") -> void:
	if not data["resume"].is_empty() and (ep_id == "" or data["resume"].get("ep", "") == ep_id):
		data["resume"] = {}
		save()


func is_unlocked(ep_id: String) -> bool:
	if data["settings"].get("unlock_all", false):
		return true
	var ids: Array[String] = EpisodeDB.ids()
	var i := ids.find(ep_id)
	return i <= 0 or is_cleared(ids[i - 1])


func total_stars() -> int:
	var t := 0
	for id in EpisodeDB.ids():
		t += stars(id)
	return t


func card_key(owner_id: String, key: String) -> String:
	return owner_id + "/" + key


func card_seen(owner_id: String, key: String) -> bool:
	return data["cards_seen"].has(card_key(owner_id, key))


func mark_card(owner_id: String, key: String) -> void:
	var k := card_key(owner_id, key)
	if not data["cards_seen"].has(k):
		data["cards_seen"].append(k)
		save()


func setting(key: String, default = null):
	return data["settings"].get(key, default)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	save()
```

- **移行**：version 1（ステージごとの ほし）からは **見た カードと 設定だけ** 引きつぐ。ほし・クリア・`story_seen` は 引きつがない（ステージの ほしは カルテの ほしに 直せない。まだ 配布前なので こまる 子は いない）。元の ファイルは `save.v1.json` に 写して のこす。カードの キーは `場所id/key` の ままなので、ずかんは そのまま 生きる。
- **こわれた ファイル**：JSON で ない／辞書で ない → 既定値。キーごとに 型を 見て、合わない ものは 既定値（いまの `load_data()` は `"stars": []` で `save_data.gd:52` が 落ちる）。`JSON.parse_string()` は 失敗すると ERROR を 出すので、`JSON.new().parse()` を 使う。JSON の 数は 小数で 来るので `int()` で くらべる。
- **テストと 撮影は 別の ファイル**：`SaveData.use_path("user://save_test.json")`。いまは `smoke.gd:29,33` が 本物の セーブを 消し、`shot.gd:28-30` が 音量 0・全解放を 書きこんで しまう。
- `record_clear()` は 無くなる（`record_episode()` に）。`stars()`・`is_cleared()`・`is_unlocked()`・`total_stars()` の 名前は 同じで、引数が カルテの id に なる。

### 5.2 ほし

- カルテごとに 3 つ：① カルテ かんせい ② **全部の 場面で** ハートを へらさずに ③ クイズに せいかい。
- **よそうは ほしに 入れない**（まちがえても しかられない）。さいしょの よそうが `culprit` と 同じなら、カルテに「★ きみの さいしょの よそう、あたっていたね！」が 出るだけ。
- **ほしは 回を またいで たまる**（`record_episode()` は OR）。1 話は 10〜15 分 かかるので、「ハート」と「クイズ」を 別の 回で 取れる ように した（いままでは 1 回で そろえる 必要が あった）。
- 「この ばめんを やりなおす」と、その 場面の ダメージは 数えない（子どもに 甘い 側）。
- 合計の 分母は `EpisodeDB.EPISODES.size() * 3`（M1 は 9）。

### 5.3 ずかん（`zukan.gd:42-66` の ループを 作りかえ）

1. **「カルテ」の 段**（いちばん 上）：話ごとに ボタン 1 つ。`SaveData.card_seen(ep_id, "karte")` なら「カルテ 1　は（歯）が ズキズキ」、まだなら「？？？」（押せない）。押すと `_open(EpisodeDB.karte_card(ep), "karte", ep_id)`（`CardPopup`。挿絵は `cards/card_ep01_karte.png` が あれば それ、無ければ ピコ）。
2. **場所の 段**：`EpisodeDB.used_places()` の 順に、その 場所の カード ＋「きょうの まとめ」（いまの 48-63 行の まま）。見出しは「くち（口）」（番号なし）。**まだ どの 話にも 出ない 場所は 出さない**（行けない 場所の「？？？」で 分母が ふくらまない）。M1 は くち・しょくどう・い（胃）・しょうちょう。
3. 見出しの「（見た 数 / 全部）」は カルテの 段も 数える。

story.md 9 章の「ずかんは カルテごと」は、この「カルテの 段 ＋ 場所の 段」と 読んだ（9 章の 決定 12）。

---

## 6. テスト・CI・ダッシュボード

### 6.1 `godot/tests/smoke.gd`（全文・確認ずみ）

順番：① スクリプトの 読みこみ ② データ（`EpisodeDB.validate()`）③ セーブの 移行 ④ **全カルテ**を 最初から カルテ画面の 終わりまで ⑤ **全部の 場所**を 場所モードで。

- ④ の 画面は「フォーカス中の ボタンを `pressed.emit()` で 押す」。フォーカスが 画面の 中の 押せる ボタンに 無い まま 30 フレーム たつと 失敗。よそうは **まず はずれを 1 回** えらぶ（画面が のこる・ボタンが 押せなく なる ことを 見る）。場面は `Autopilot.drive()`。
- ④ の 検査：フェーズの 列が データから 作った 列と 同じ／場面の クリア数／`data_warnings` が 空／`skip` が きいている／クリアと `epNN/karte` の 記録／おわった あとに Level と ポーズが のこって いない。
- ⑤ は 10 場所 全部（カルテで 使う 場所も）。「まだ カルテで 使わない 場所」（M1 は けっかん・しんぞう 2 つ・はい・のう・はな）が ここで 守られ、`tools/run_tests.sh --stage=mouth`（CLAUDE.md の 例）も そのまま 動く。全部で 実時間 15 秒ほど。
- 引数：`--stage=<場所id>`（その 場所だけ）、`--episode=<epNN>`（その 話だけ）。
- ログ：`cleared ep03 in 60.5s (sim) …` と `cleared mouth in 19.1s (sim) …`（`build_dashboard.py` の 正規表現 `cleared (\w+) in ([\d.]+)s \(sim\)` に 両方 当たる。場面は `  scene 0 (stomach) done` で、この 正規表現には 当たらない）。
- 自動操縦は クイズを 当てる とは かぎらない（えらびは まぜて ある）し、いえきの いけも よけない。だから ほしは「1 以上」しか 見ない。

```gdscript
extends Node
## 自動テスト（ヘッドレス）。
##   godot --headless --fixed-fps 60 --path godot res://tests/smoke.tscn [-- --episode=ep03 | --stage=mouth]
## 1. src/ の 全スクリプトを 読みこむ　2. カルテの データを 調べる（EpisodeDB.validate ＋ 文が 箱に 入るか）　3. セーブを 調べる
## 4. 全カルテを カルテえらび → そうだん → よそう → 場面 → カルテ まで 通す（画面は フォーカス中の ボタンを 押す。場面は 自動操縦）
## 5. つづきから　6. ずかん（カルテを 開いて 閉じる）
## 7. 全部の 場所を 既定の ミッションで 自動操縦（カルテで まだ 使わない 場所も ここで 守る）
const MAX_SCENE_SECONDS := 420.0
const MAX_UI_SECONDS := 30.0
const Autopilot := preload("res://tests/autopilot.gd")
const SelectScreen := preload("res://src/ui/episode_select.gd")
const TalkScreen := preload("res://src/ui/talk.gd")
const GuessScreen := preload("res://src/ui/guess.gd")
const ZukanScreen := preload("res://src/ui/zukan.gd")
const KarteSheet := preload("res://src/ui/karte_sheet.gd")

var _failures: Array[String] = []
var _log: Array[String] = []
var _only_place := ""
var _only_ep := ""
var _finished := false
var _ep_done := false
var _phases: Array[String] = []
var _phases_at_end: Array[String] = []
var _scene_clears := 0
var _said: Array = []          # いまの 場面で HUD に 出た 文：[物理フレーム, 文]
var _text_seen: Dictionary = {}


func _ready() -> void:
	Game.testing = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			_only_place = a.substr(8)
		if a.begins_with("--episode="):
			_only_ep = a.substr(10)
	SaveData.use_path("user://save_test.json")
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	_check_scripts()
	_check_data()
	await _check_sheets()
	_check_save()
	SaveData.reset()
	SaveData.set_setting("volume", 0.0)
	Game.phase_changed.connect(func(p: String, i: int): _phases.append("%s%s" % [p, str(i) if p in ["scene", "after"] else ""]))
	Game.stage_started.connect(func(_sid): _said.clear())
	Game.said.connect(func(t: String): _said.append([Engine.get_physics_frames(), t]))
	Game.stage_finished.connect(func(sid: String, _stars):
		_scene_clears += 1
		if not Game.episode.is_empty():
			_info("  scene %d (%s) done" % [Game.scene_index, sid])
			_check_says())
	if _only_place == "":
		for id in EpisodeDB.ids():
			if _only_ep == "" or id == _only_ep:
				await _run_episode(id)
	if _only_place == "" and _only_ep == "":
		await _check_back()
		await _check_resume()
		await _check_zukan()
	if _only_ep == "":
		for id in StageDB.stage_ids():
			if _only_place == "" or id == _only_place:
				await _run_place(id)
	SaveData.reset()
	print("")
	print("==================== SMOKE SUMMARY ====================")
	for l in _log:
		print(l)
	if _failures.is_empty():
		print("RESULT: OK")
	else:
		for f in _failures:
			print("FAIL: " + f)
		print("RESULT: %d FAILURE(S)" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr("[SMOKE FAIL] " + msg)


func _info(msg: String) -> void:
	_log.append(msg)
	print("[smoke] " + msg)


func _check_scripts() -> void:
	var count := 0
	for path in _list_scripts("res://src"):
		var s = load(path)
		if s == null or not (s is GDScript):
			_fail("script failed to load: " + path)
		else:
			count += 1
	_info("scripts loaded: %d" % count)


func _list_scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir.path_join(f)
		if d.current_is_dir():
			out.append_array(_list_scripts(p))
		elif f.ends_with(".gd"):
			out.append(p)
		f = d.get_next()
	return out


func _check_data() -> void:
	for b in EpisodeDB.validate():
		_fail("data: " + b)
	# 文が 箱に 入るか（本物の フォントで はかる）。画面に 出ない えらびの 返事も ここで 見る
	for ep in EpisodeDB.EPISODES:
		var id: String = ep["id"]
		var pages: Array = EpisodeDB.OPENING + ep["consult"]
		for sc in ep["scenes"]:
			pages += sc.get("after", {}).get("lines", []) + sc.get("after", {}).get("lines_hit", [])
		for l in pages:
			if not TalkScreen.text_fits(l["text"]):
				_fail("%s: はなしの 文が ふきだしに 入らない：%s" % [id, l["text"]])
		if ep.has("guess"):
			for t in [ep["guess"]["q"]] + ep["guess"]["choices"].map(func(c): return c["say"]):
				if not GuessScreen.say_fits(t):
					_fail("%s: よそうの 文が ふきだしに 入らない（%d 行）：%s" % [id, GuessScreen.lines_of(t, GuessScreen.SAY_SIZE, GuessScreen.SAY_WIDTH), t])
			if not GuessScreen.depart_fits(ep["guess"]["depart"]):
				_fail("%s: depart が 箱に 入らない" % id)
		# あたりの よそうには lines_hit が 出る
		for i in ep["scenes"].size():
			var a: Dictionary = ep["scenes"][i].get("after", {})
			if a.has("lines_hit"):
				for c in ep["guess"]["choices"]:
					var want: Array = a["lines_hit"] if c.get("hit", false) else a["lines"]
					if EpisodeDB.after_lines(ep, i, c["place"]) != want:
						_fail("%s: after_lines が ちがう（%s）" % [id, c["place"]])
	_info("episodes: %d, places: %d" % [EpisodeDB.EPISODES.size(), StageDB.STAGES.size()])


## カルテの 紙が 入るか（カルテ画面と ずかんの ポップアップが 同じ 紙を 使う）
func _check_sheets() -> void:
	for ep in EpisodeDB.EPISODES:
		var sh := KarteSheet.build(ep)
		sh.theme = Game.theme
		add_child(sh)
		await get_tree().process_frame
		await get_tree().process_frame
		var h := sh.get_combined_minimum_size().y
		_info("karte sheet %s: %.0f px" % [ep["id"], h])
		if h > KarteSheet.MAX_HEIGHT:
			_fail("%s: カルテの 紙が 高すぎる（%.0f px。%.0f まで）" % [ep["id"], h, KarteSheet.MAX_HEIGHT])
		sh.queue_free()


func _write(text: String) -> void:
	var f := FileAccess.open(SaveData.path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _check_save() -> void:
	var ep2 := ""      # 場面が 2 つ 以上 ある 最初の 話
	for e in EpisodeDB.EPISODES:
		if ep2 == "" and e["scenes"].size() >= 2:
			ep2 = e["id"]
	# v1（ステージごとの ほし）→ カードと 設定だけ 引きつぐ
	_write('{"version":1,"stars":{"mouth":3},"cleared":["mouth"],"cards_seen":["mouth/stage","mouth/mushiba",5],"story_seen":true,"settings":{"volume":0.5,"touch":"on","unlock_all":false}}')
	SaveData.load_data()
	if SaveData.data["version"] != 2 or SaveData.total_stars() != 0 or SaveData.is_cleared("ep01") or not SaveData.card_seen("mouth", "stage") or SaveData.setting("volume") != 0.5 or SaveData.setting("touch") != "on" or SaveData.data["cards_seen"].size() != 2:
		_fail("save: v1 migration: %s" % SaveData.data)
	if not FileAccess.file_exists("user://save_test.v1.json"):
		_fail("save: v1 backup not written")
	# こわれた ファイル・型ちがい
	for text in ["{{{", "[1,2]", '{"version":2,"episodes":[],"cards_seen":{},"settings":"x","opening_seen":3,"resume":[1]}', '{"version":"x","episodes":{"ep01":5,"ep02":{"clear":"yes"}}}', '{"version":9,"stars":[]}', '{"version":2,"episodes":{"ep01":{"clear":1,"nd":"x"},"ep02":{"nd":[1,"a",null]}},"resume":{"ep":"ep99","cleared":1}}', '{"version":2,"resume":{"ep":"ep01","cleared":7}}']:
		_write(text)
		SaveData.load_data()
		if SaveData.total_stars() != 0 or not (SaveData.data["episodes"] is Dictionary) or not (SaveData.data["cards_seen"] is Array) or SaveData.setting("volume") != 0.8 or SaveData.data["opening_seen"] != false or not SaveData.resume().is_empty():
			_fail("save: broken file not handled: %s -> %s" % [text, SaveData.data])
		for id in EpisodeDB.ids():
			if SaveData.star_flags(id) != [false, false, false] or SaveData.scene_flags(id).has(true):
				_fail("save: broken file gives stars: %s" % text)
	# v2 の 往復。ほしの 印は 場面ごと・回を またいで たまる。クリア前は ほしに ならない
	SaveData.reset()
	SaveData.record_scene("ep01", 0, true)
	if SaveData.stars("ep01") != 0:
		_fail("save: クリア前に ほしが ついた")
	SaveData.record_clear("ep01")
	SaveData.record_quiz("ep01", false)
	SaveData.record_quiz("ep01", true)
	SaveData.record_quiz("ep01", false)
	SaveData.record_scene("ep01", 0, false)
	SaveData.load_data()
	if SaveData.stars("ep01") != 3 or not SaveData.is_unlocked("ep02") or SaveData.is_unlocked("ep03"):
		_fail("save: v2 roundtrip: %s" % SaveData.data)
	if ep2 != "":
		SaveData.record_clear(ep2)
		SaveData.record_scene(ep2, 1, true)
		if SaveData.star_flags(ep2) != [true, false, false]:
			_fail("save: 場面が 1 つ まだなのに ハートの ほし")
		SaveData.record_scene(ep2, 0, true)
		SaveData.set_resume(ep2, 1, "stomach")
		SaveData.load_data()
		if SaveData.star_flags(ep2) != [true, true, false] or SaveData.resume().get("ep", "") != ep2 or int(SaveData.resume().get("cleared", 0)) != 1:
			_fail("save: scene flags／resume roundtrip: %s" % SaveData.data)
		SaveData.clear_resume("ep01")     # ほかの 話の つづきは 消さない
		if SaveData.resume().is_empty():
			_fail("save: clear_resume が ほかの 話を 消した")
		SaveData.clear_resume(ep2)
		if not SaveData.resume().is_empty():
			_fail("save: clear_resume が きかない")
	_info("save checks done")


func _expected_phases(ep: Dictionary) -> Array[String]:
	var out: Array[String] = ["consult"]
	if ep.has("guess"):
		out.append("guess")
	for i in ep["scenes"].size():
		out.append("scene%d" % i)
		if ep["scenes"][i].has("after"):
			out.append("after%d" % i)
	out.append("karte")
	return out


## いまの 画面で、押せる ボタンに フォーカスが あれば それを 返す（まだなら null）
func _focused_button(scr: Control) -> BaseButton:
	if scr == null or not scr.has_method("locked") or scr.locked():
		return null
	var fo := get_viewport().gui_get_focus_owner()
	if fo == null or not scr.is_ancestor_of(fo) or not (fo is BaseButton) or fo.disabled:
		return null
	return fo


## 画面に 出ている 文（ラベルと ボタン）を 文の きまりで 調べる。はみ出しも 見る
func _check_screen(scr: Control, where: String) -> void:
	for n in scr.find_children("*", "Control", true, false):
		if (n is Label or n is Button) and n.is_visible_in_tree() and n.text != "" and not _text_seen.has(n.text):
			_text_seen[n.text] = true
			for p in EpisodeDB.text_problems(n.text):
				_fail("%s: 画面の 文「%s」: %s" % [where, n.text, p])
	if scr.has_method("fits") and not scr.fits():
		_fail("%s: 文が 箱から はみ出して いる" % where)


## 場面が おわった とき：intro・goal_say・clear_say が HUD に 出たか。goal_say が 同じ フレームで 上書きされて いないか
func _check_says() -> void:
	var sc: Dictionary = Game.episode["scenes"][Game.scene_index]
	var where := "%s scene %d" % [Game.episode["id"], Game.scene_index]
	var texts: Array = _said.map(func(e): return e[1])
	var want: Array = [sc["intro"]]
	var has_work: bool = sc["missions"].size() > 1
	if has_work and sc.has("goal_say"):
		want.append(sc["goal_say"])
	if sc.has("clear_say"):
		want.append(sc["clear_say"])
	for t in want:
		if not texts.has(t):
			_fail("%s: HUD に 出なかった：%s" % [where, t])
	if has_work and sc.has("goal_say"):
		var i := texts.find(sc["goal_say"])
		if i >= 0 and i + 1 < _said.size() and _said[i + 1][0] == _said[i][0] and _said[i + 1][1] != sc.get("clear_say", "クリア！"):
			_fail("%s: goal_say が すぐ 上書きされた：%s" % [where, _said[i + 1][1]])


func _run_episode(id: String) -> void:
	_info("=== episode %s ===" % id)
	var ep := EpisodeDB.get_episode(id)
	var t0 := Time.get_ticks_msec()
	_ep_done = false
	_phases.clear()
	_scene_clears = 0
	# id だけを 回す とき（--episode=）は、前の 話を クリアずみに して おく（カルテえらびが id を えらぶ ように）
	for prev in EpisodeDB.ids():
		if prev == id:
			break
		if not SaveData.is_cleared(prev):
			SaveData.record_clear(prev)
	# episode_finished の しゅんかんの フェーズ列を 写す（「つぎの カルテへ」は すぐ 次の 話の consult を 出すので）
	Game.episode_finished.connect(func(_id, _s):
		_ep_done = true
		_phases_at_end = _phases.duplicate(), CONNECT_ONE_SHOT)
	Game.show_episode_select()
	var total := 0.0
	var idle := 0.0          # いまの フェーズに 入ってからの 時間
	var seen_phases := 0
	var nofocus := 0
	var select_done := false
	var wrong_done := false
	var checked_level = null
	while not _ep_done:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		total += dt
		idle += dt
		if _phases.size() != seen_phases:
			seen_phases = _phases.size()
			idle = 0.0
		var lvl = Game.level
		if lvl != null and is_instance_valid(lvl):
			if lvl != checked_level and lvl.started:
				checked_level = lvl
				for w in lvl.data_warnings:
					_fail("%s scene %d: %s" % [id, Game.scene_index, w])
				for p in lvl.stage.get("spawn", {}).get("skip", []):
					for m in lvl.markers:
						if m["node"] != null and Level.spawn_rule_matches(String(m["node"].name).substr(3), p):
							_fail("%s: skip が きいていない: %s" % [id, m["node"].name])
			if lvl.started and not lvl.finished:
				Autopilot.drive(lvl, get_tree())
			if idle > MAX_SCENE_SECONDS:
				_fail("%s: scene %d (%s) did not finish in %.0fs" % [id, Game.scene_index, lvl.stage_id, MAX_SCENE_SECONDS])
				break
			continue
		var scr := Game.screen()
		if idle > MAX_UI_SECONDS:
			_fail("%s: stuck on %s for %.0fs" % [id, Game.phase, MAX_UI_SECONDS])
			break
		if scr == null or not scr.has_method("locked") or scr.locked():
			continue
		var fo := _focused_button(scr)
		if fo == null:
			nofocus += 1
			if nofocus == 30:
				_fail("%s: %s の 画面で フォーカスが ボタンに ない" % [id, Game.phase if Game.phase != "" else "カルテえらび"])
			continue
		nofocus = 0
		_check_screen(scr, "%s %s" % [id, Game.phase if Game.phase != "" else "select"])
		if scr is SelectScreen and not select_done:
			# カルテえらび：最初から この 話が えらばれ、スタートの ボタンに フォーカスが ある こと
			select_done = true
			if scr.selected_id != id or fo != scr.main_btn or scr.main_is_resume:
				_fail("%s: カルテえらびの 最初の えらびが ちがう（%s）" % [id, scr.selected_id])
				Game.start_episode(id)
				continue
		if scr is GuessScreen and not wrong_done:
			wrong_done = true
			for c in ep["guess"]["choices"]:
				if not c.get("go", false):
					scr.choose(c["place"])   # わざと はずれを 1 回
					if Game.screen() != scr or not scr.buttons[c["place"]].disabled:
						_fail("%s: はずれの よそうで 画面が 残らない／ボタンが 消えない" % id)
					break
			continue
		fo.pressed.emit()
	var expect := _expected_phases(ep)
	if _ep_done:
		_info("cleared %s in %.1fs (sim) / %.1fs (real); scenes=%d stars=%d" % [id, total, (Time.get_ticks_msec() - t0) / 1000.0, _scene_clears, SaveData.stars(id)])
		if _phases_at_end != expect:
			_fail("%s: phases %s != %s" % [id, _phases_at_end, expect])
		if _scene_clears != ep["scenes"].size():
			_fail("%s: %d scenes cleared, expected %d" % [id, _scene_clears, ep["scenes"].size()])
		if not SaveData.is_cleared(id) or not SaveData.card_seen(id, "karte") or not SaveData.resume().is_empty():
			_fail("%s: clear／karte が 記録されていない、または つづきが 残っている" % id)
		for sc in ep["scenes"]:
			if not SaveData.card_seen(sc["place"], "stage") or not SaveData.card_seen(sc["place"], "summary"):
				_fail("%s: 場所 %s の カード（stage／summary）が ずかんに 入って いない" % [id, sc["place"]])
		if Game.level != null or get_tree().paused:
			_fail("%s: おわった あとに level／pause が のこっている" % id)
		# 主ボタンは「つぎの カルテへ ▶」（次が ある とき）。押した あと 次の 話の そうだんに いる こと
		var next := EpisodeDB.next_id(id)
		await get_tree().process_frame
		if next != "" and (Game.episode.get("id", "") != next or Game.phase != "consult"):
			_fail("%s: 「つぎの カルテへ」で %s が 始まらない（%s %s）" % [id, next, Game.episode.get("id", ""), Game.phase])
		if next == "" and (not Game.episode.is_empty() or not (Game.screen() is SelectScreen)):
			_fail("%s: さいごの 話の あと カルテえらびに もどらない" % id)
	await get_tree().process_frame


## 画面の フォーカス中の ボタンを 押しつづける（cond が true に なる まで）。場面は 自動操縦
func _play_until(cond: Callable, max_seconds: float) -> bool:
	var t := 0.0
	while t < max_seconds:
		if cond.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var lvl = Game.level
		if lvl != null and is_instance_valid(lvl):
			if lvl.started and not lvl.finished:
				Autopilot.drive(lvl, get_tree())
			continue
		var fo := _focused_button(Game.screen())
		if fo != null:
			fo.pressed.emit()
	return cond.call()


## よそうで「もどる」→ そうだんの さいごの ページ → 進むと また よそう（カルテえらびまで もどされない）
func _check_back() -> void:
	var id: String = EpisodeDB.ids()[0]
	Game.start_episode(id, "guess")
	for i in 60:
		if _focused_button(Game.screen()) == null:
			await get_tree().physics_frame
	if not (Game.screen() is GuessScreen):
		_fail("back: よそうの 画面が 出ない")
		return
	Game.screen().cancelled.emit()
	var t := Game.screen()
	if Game.phase != "consult" or not (t is TalkScreen) or t.page != t.lines.size() - 1:
		_fail("back: よそうから そうだんの さいごの ページに もどらない")
		return
	if not await _play_until(func(): return Game.phase == "guess", MAX_UI_SECONDS):
		_fail("back: そうだんから よそうへ 進めない")
	Game.show_episode_select()
	await get_tree().process_frame


## 場面 1 を おえて やめる → カルテえらびに「つづきから」が 出て、押すと 場面 2 に 入る
func _check_resume() -> void:
	var id := ""
	for e in EpisodeDB.EPISODES:
		if id == "" and e["scenes"].size() >= 2:
			id = e["id"]
	if id == "":
		return
	_info("=== resume %s ===" % id)
	var ep := EpisodeDB.get_episode(id)
	Game.start_episode(id, "scene", 0)
	if not await _play_until(func(): return Game.phase != "scene" or Game.scene_index != 0, MAX_SCENE_SECONDS):
		_fail("resume: 場面 1 が おわらない")
		return
	var r := SaveData.resume()
	if r.get("ep", "") != id or int(r.get("cleared", 0)) != 1:
		_fail("resume: つづきが 記録されて いない: %s" % r)
	Game.show_episode_select()      # ポーズの「カルテえらびへ」と 同じ
	for i in 60:
		if _focused_button(Game.screen()) == null:
			await get_tree().physics_frame
	var scr := Game.screen()
	if not (scr is SelectScreen) or scr.selected_id != id or not scr.main_is_resume or _focused_button(scr) != scr.main_btn or scr.restart_btn == null:
		_fail("resume: カルテえらびに「つづきから」が 出ない")
		return
	if not await _play_until(func(): return Game.phase == "scene" and Game.level != null and Game.level.started, MAX_UI_SECONDS):
		_fail("resume: つづきから 場面に 入れない（%s）" % Game.phase)
		return
	if Game.scene_index != 1 or Game.level.stage_id != ep["scenes"][1]["place"]:
		_fail("resume: 場面 2 では ない（scene %d %s）" % [Game.scene_index, Game.level.stage_id])
	else:
		_info("resumed %s at scene 1 (%s)" % [id, Game.level.stage_id])
	# クリアずみの 話の クイズだけ もういちど：クリアの 記録も つづきも 変わらない
	SaveData.record_clear(id)
	Game.review_karte(id)
	if Game.phase != "karte" or SaveData.resume().get("ep", "") != id:
		_fail("resume: review_karte が つづきを 消した")
	if not await _play_until(func(): return Game.screen() is SelectScreen, MAX_UI_SECONDS):
		_fail("resume: クイズの やりなおしから カルテえらびに もどらない")
	SaveData.clear_resume()
	await get_tree().process_frame


## ずかん：最初の フォーカスが カルテの ボタン。開く → 高さ → 閉じる → フォーカスが もどる
func _check_zukan() -> void:
	_info("=== zukan ===")
	Game.show_zukan()
	for i in 10:
		await get_tree().process_frame
	var scr := Game.screen()
	if not (scr is ZukanScreen):
		_fail("zukan: 画面が 出ない")
		return
	_check_screen(scr, "zukan")
	var first := true
	for id in EpisodeDB.ids():
		if not SaveData.card_seen(id, "karte"):
			continue
		var b: Button = scr.karte_buttons[id]
		if first and get_viewport().gui_get_focus_owner() != b:
			_fail("zukan: 最初の フォーカスが カルテの ボタンに ない")
		first = false
		b.grab_focus()
		b.pressed.emit()
		var t := 0.0
		while t < 5.0 and (scr.popup == null or scr.popup.button().disabled):
			await get_tree().process_frame
			t += get_process_delta_time()
		if scr.popup == null or scr.popup.button().disabled:
			_fail("zukan: カルテ %s の カードが 開かない" % id)
			continue
		var h: float = scr.popup.panel_height()
		_info("  karte card %s: panel %.0f px" % [id, h])
		if h > 680.0:
			_fail("zukan: カルテ %s の カードが 高すぎる（%.0f px）" % [id, h])
		if get_viewport().gui_get_focus_owner() != scr.popup.button():
			_fail("zukan: カードの ボタンに フォーカスが ない")
		_check_screen(scr.popup, "zukan card " + id)
		scr.popup.button().pressed.emit()
		t = 0.0
		while t < 5.0 and scr.popup != null:
			await get_tree().process_frame
			t += get_process_delta_time()
		if get_viewport().gui_get_focus_owner() != b:
			_fail("zukan: カードを 閉じた あと フォーカスが もどらない（%s）" % id)
	if first:
		_fail("zukan: 見た カルテが 1 つも ない")


func _run_place(id: String) -> void:
	_info("=== place %s ===" % id)
	var t0 := Time.get_ticks_msec()
	Game.start_stage(id)
	var lvl = Game.level
	var waited := 0.0
	while not lvl.started and waited < 10.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not lvl.started:
		_fail("place never started: " + id)
		return
	for w in lvl.data_warnings:
		_fail("place %s: %s" % [id, w])
	_finished = false
	Game.stage_finished.connect(func(_sid, _stars): _finished = true, CONNECT_ONE_SHOT)
	var t := 0.0
	while not _finished and t < MAX_SCENE_SECONDS:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if is_instance_valid(lvl) and not lvl.finished:
			Autopilot.drive(lvl, get_tree())
	if not _finished:
		_fail("place %s did not finish in %.0fs" % [id, MAX_SCENE_SECONDS])
	else:
		_info("cleared %s in %.1fs (sim) / %.1fs (real)" % [id, t, (Time.get_ticks_msec() - t0) / 1000.0])
	await get_tree().process_frame
```

いまの `smoke.gd` の `--debug`（110-116 行の 2 秒ごとの 出力）は、`_run_place()` の ループに 同じ 形で 残す（上の 全文では 省いた）。

### 6.2 `autopilot.gd`・`probe.gd`

変更なし。`probe.gd` は `StageDB.STAGES` の GLB を 全部 調べつづける。ミッションの 型を 足さない かぎり `autopilot.gd` は 変えなくて よい。

### 6.3 `godot/tests/shot.gd` の モード

最初に `SaveData.use_path("user://save_shot.json")` ＋ `SaveData.reset()`（本物の セーブを さわらない）。新しい 画面は 自分で 進まないので、`Game.testing = false` の 小細工は `card` だけに 残る。

| `--stage=` | 写る もの | 入りかた |
|-----------|---------|---------|
| `title`、`zukan`、`card`、`model:<id>`、`<場所id>`（＋`--play=秒`） | いまの まま（`zukan` は ep01 を クリアずみに して カルテの 段も 写す） | — |
| `select` | カルテえらび（ep01 クリアずみ・ep02 開いた 状態） | `Game.show_episode_select()` |
| `opening` | はじめての そうだん（OPENING の 1 ページ目） | `Game.start_episode("ep01")` |
| `consult:ep03` | そうだん | `opening_seen = true` に して `Game.start_episode(ep)` |
| `guess:ep03` | よそう | `Game.start_episode(ep, "guess")` |
| `guess_wrong:ep01` | はずれを 1 回 えらんだ あと | 上の あと 30 フレーム 待って `Game.screen().choose(<go で ない 最初の place>)` |
| `after:ep03:0` | 「ここは げんき。ちがった！」 | `Game.start_episode(ep, "after", 0)` |
| `karte:ep03`（`karte:ep03:1`、`:2`、`:3`） | カルテ画面の 段 0（1 ＝ 3 行、2 ＝ クイズ、3 ＝ ほし） | `Game.start_episode(ep, "karte")` の あと、30 フレームおきに フォーカス中の ボタンを n 回 押す |
| `ep03:1`（＋`--play=秒`） | 3 話の 2 つめの 場面 | `Game.start_episode(ep, "scene", 1)` |
| ~~`result`~~ | 消す（`karte:ep01:3` が 代わり） | |

`tools/make_screenshots.sh` の 一覧（8-13 行）：`title select consult:ep01 guess:ep01 guess_wrong:ep01 after:ep03:0 karte:ep03:1 card zukan`（ファイル名は `:` を `_` に）。場所の 一覧に ぬけている `heart2` を 足す。`tools/screenshot.sh` は 使いかたの コメントだけ 直す。

### 6.4 `tools/run_tests.sh`・CI

- `run_tests.sh`：smoke の あとに ダッシュボードを 試しに 作る。パーサが こわれたら その 場で 落ちる（いまは main に push する まで 気づけない）。

```bash
echo "== dashboard =="
if python3 "$ROOT/tools/build_dashboard.py" --html "$LOG.dash.html" --test-log "$LOG" >"$LOG.dash" 2>&1; then
  echo "DASHBOARD: OK"
else
  echo "DASHBOARD: FAILED"; tail -5 "$LOG.dash"; code=1
fi
```

（`sed -n '/SMOKE SUMMARY/,$p' "$LOG"` の 次、`exit` の 前に 入れる。使いかたの コメントに `[--stage=mouth | --episode=ep03]`。）
- `.github/workflows/test.yml`：20 行の ステップ名を「Import, floor probe and autopilot smoke test (all episodes and places)」に。ほかは そのまま（ログの artifact は `/tmp/inside-body-seek-test.log*` なので 試し作りの HTML も 入る）。
- 合格の 条件は いままでと 同じ：`PROBE RESULT: OK`、`RESULT: OK`、`SCRIPT ERROR` なし。それに `DASHBOARD: OK`。

### 6.5 `tools/build_dashboard.py`

`stages()`（54-75 行）は `stage_db.gd` の `STAGES` が 変わらないので **そのまま 動く**。足す もの（確認ずみ：カルテ 3 / 3、場所 10 / 10 と 出る）：

```python
def episodes(ep_gd: str, gd: str, test_log: str) -> list:
    """godot/src/autoload/episode_db.gd から カルテの 表を 作る（書きかたの きまりは その ファイルの 先頭）。"""
    cleared = {m.group(1): float(m.group(2))
               for m in re.finditer(r"cleared (\w+) in ([\d.]+)s \(sim\)", test_log)}
    patients = dict(re.findall(r'"(\w+)": \{"name": "([^"]+)"', ep_gd))
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
            "場所": " → ".join(place_names.get(p, p) for p in places), "パターン": g("pattern"),
            "むずかしさ": "★" * int(g("difficulty")), "自動テスト": test,
        })
    return sorted(out, key=lambda e: e["話"])
```

| 場所（いまの 行） | 変更 |
|----------------|------|
| 先頭の 説明（4 行） | 元に する ものに `episode_db.gd` を 足す |
| `NARROW_HIDE`（134） | `"パターン"`、`"場所"` を 足す |
| `table()`（157） | `c == "順"` → `c in ("順", "話")` |
| `render()`（169-172） | `eps = data["episodes"]`。`test_line` を「自動テスト：カルテ a / b、場所 c / d がクリアまで通る」に |
| `render()` の `TEMPLATE.format(…)` | `episodes=table(eps, ["話", "だいめい", "患者", "場所", "パターン", "むずかしさ", "自動テスト"])`、`episode_count=len(eps)`、`stage_count=len(st)` |
| `TEMPLATE` | `<section id="stages">` の 前に `<section id="episodes">`（見出し「カルテ（{episode_count} 話まで実装）」＋ 説明 ＋ `{episodes}`）。場所の 見出しを「場所（{stage_count}）」に、説明を「カルテが めぐる 場所。ミッションは 場所の 既定で、カルテの 場面が 上書きする」に。`nav` の「ステージ」を「カルテ」「場所」の 2 つに |
| `main()`（370-383） | `ep_gd = (ROOT / "godot/src/autoload/episode_db.gd").read_text(encoding="utf-8")`、`data["episodes"] = episodes(ep_gd, gd, log)`（空なら 止める 検査に 自動で 入る） |

正規表現が たよる 書きかたは `episode_db.gd` の 先頭の コメントに 書いて ある（1 行目の キーの 順、場面の `"place"` は 4 タブで 単独）。

---

## 7. マイルストーン 1 の 作業手順

各 手順の 終わりで `tools/run_tests.sh` を 回す（`PROBE RESULT: OK`・`RESULT: OK`・`SCRIPT ERROR` なし）。手順 3 の 途中だけは 通らなくて よい。

**0. 準備**
- `export GODOT=…`、`tools/run_tests.sh` を 回して いまの 秒数を 控える（くち 18.7／しょくどう 26.3／い 17.8／しょうちょう 38.6／けっかん 17.7／しんぞう 9.3／はい 34.3／しんぞう ひだり 9.1／のう 39.3／はな 8.9。はい と のう は 乱数で ±10 秒 ゆれる）。
- 完了：`RESULT: OK`。

**1. Level の 上書きと 守り**（ふるまいは まだ 変わらない）
- `godot/src/level/level.gd`：4.1 の 1〜7（4.2・4.3 の コード）。
- `godot/src/level/mission.gd`：`done_say`・`each_say`。
- `godot/src/ui/hud.gd:112`：番号なしの 題。
- `godot/tests/smoke.gd`：いまの `_run_stage()` に「`lvl.data_warnings` が 空で なければ 失敗」を 足す（手順 3 で 全文に 置きかえる まで の つなぎ）。
- 注意：`begin()` から `StageDB.STORY_INTRO` の 参照が 消える（定数 自体は 手順 3 で 消す）。
- 完了：10 場所が 0. と 同じくらいの 秒数で 通る。警告 0 件。

**2. データ**
- `godot/src/autoload/episode_db.gd`：2.3 の 全文。
- `godot/project.godot`：`[autoload]` の `StageDB` の 次に `EpisodeDB`。
- `godot/tests/smoke.gd`：`_check_data()`（`EpisodeDB.validate()` の 結果を 1 件ずつ 失敗に）。
- `tools/run_tests.sh` の import で `episode_db.gd.uid` が できる（コミットする）。
- 完了：`validate()` が 0 件。テストが 通る（まだ だれも `EpisodeDB` を 使わない）。

**3. セーブ v2 と 流れ**（ここで 遊びが 切りかわる。画面は 動けば よく、見た目は 手順 4）
- `godot/src/autoload/save_data.gd`：5.1 の 全文。
- `godot/src/autoload/game.gd`：3.2。
- `godot/src/ui/flow_screen.gd`（新規）：3.3。
- `godot/src/ui/talk.gd`・`guess.gd`（新規）：3.4 B・C の 動き（ラベルと ボタンだけの 形で よい）。
- `git mv godot/src/ui/result.gd godot/src/ui/karte.gd`、`git mv godot/src/ui/stage_select.gd godot/src/ui/episode_select.gd`（`.uid` も いっしょに `git mv`）。3.4 A・D の 動き（シグナルと 段の 進みかた）に 作りかえる。
- `godot/src/ui/pause.gd`・`title.gd`：3.4 E。
- `godot/src/autoload/stage_db.gd`：`STORY_INTRO`・`STORY_ENDING`・`next_stage_id()`・`all_cards()` を 消す。先頭の コメントを「場所の 定義」に。
- `godot/tests/smoke.gd`：6.1 の 全文に 置きかえ。`godot/tests/shot.gd`：`use_path`、`show_stage_select` → `show_episode_select`、`result` モードを いったん 消す。
- 完了：`cleared ep01`・`ep02`・`ep03` と 10 場所が 出て `RESULT: OK`。`tools/run_tests.sh --episode=ep03` と `--stage=mouth` も 通る。手元の `user://save.json` が テストで 変わらない。

**4. 画面の 仕上げ**
- `godot/src/ui/ui_theme.gd`：`portrait()`・`draw_pico()`・`draw_face()`（3.5）。`hud.gd` は `T.draw_pico` を 呼ぶ。
- `talk.gd`・`guess.gd`・`karte.gd`・`episode_select.gd`：3.4 の レイアウト。`guess.gd` に `stage_select.gd` から 地図の 読みこみと `_draw_body` を 移す（`ORGAN_POS` は `EpisodeDB` に ある）。
- `godot/src/ui/card.gd`（72・98 行）、`godot/src/ui/zukan.gd`（5.3）。
- `godot/tests/shot.gd`：6.3 の モード。`tools/make_screenshots.sh`・`tools/screenshot.sh`。
- 完了：テストが 通る。`tools/screenshot.sh` で `select`・`opening`・`consult:ep02`・`guess:ep03`・`guess_wrong:ep01`・`after:ep03:0`・`karte:ep03`〜`:3`・`zukan` を 1280×720 と `--touch` で 撮り、文の はみ出し・重なりが 無い。手で 1 話を、キーボードだけ／ゲームパッドだけ（Xvfb では 無理なら キーボードの Z・X で 代用）／マウスだけ で 最後まで 進める。

**5. 道具**
- `tools/build_dashboard.py`（6.5）、`tools/run_tests.sh`（6.4）、`.github/workflows/test.yml`（ステップ名）。
- 完了：`tools/run_tests.sh` の さいごに `DASHBOARD: OK`。`$LOG.dash.html` を 開いて「カルテ」の 表に 3 話、「場所」の 表に 10 行。

**6. 文書と 発注書**（仮の 見た目を 作ったのと 同じ コミットで）
- `CLAUDE.md`：「ステージの文章・ミッション・カード・クイズはすべて `stage_db.gd`」→「場所（既定の ミッション・ものしりカード）は `stage_db.gd`、カルテ（そうだん・よそう・場面の 上書き・カルテ・クイズ）は `episode_db.gd`。設計は `docs/episodes.md`」。テストの 例に `tools/run_tests.sh --episode=ep03`、スクリーンショットの 例に `guess:ep03`。
- `README.md`：6-9 行（あそびかた）、39-44・52-53 行（ファイルの 表に `episode_db.gd`・新しい 画面）、96-102 行（「場所を 増やすには」：`ORGAN_POS` は `episode_db.gd`。「カルテを 増やすには」を 足す）、119-123 行（テスト）。
- `docs/design.md`：先頭に「2026-11 から カルテ形式。構成は `docs/episodes.md`、物語は `docs/story.md`。4 章の 表は『場所』の 一覧として 読む」。「星」「ものしりカード・ずかん」の 段を 5 章に 合わせる。
- `docs/story.md`：3 行目の 状態を「**OK**（2026-11-12。大きな病気は はいえん。1〜3 話を 実装）」に。
- `docs/dashboard.md`：1 章（仕組み・ステージの 行）、2 章（やること）、4 章「納品 PNG の 差しかえ先」に 3.5 の 表の 行、6 章（記録）、8 章（`episode_db.gd` からも 作る）。`docs/progress.md` に 1 項目。
- `docs/art_orders/W1_01_主人公たち.md`：4 章の 表に「けんたくん・おとうさん・おじいちゃん：`<who>_face_sick.png`・`<who>_face_happy.png`（256×256）、`<who>_fullbody_sick.png`・`<who>_fullbody_happy.png`（1200×1800）。who ＝ kenta／papa／jiji。人物の メモは story.md 4 章」。
- `docs/art_orders/W4_01_UI.md`：「`bodymap_kenta.png`・`bodymap_papa.png`・`bodymap_jiji.png`（880×1240。臓器の 位置は `bodymap_hana.png` と 同じ 表。ひざ（0.43, 0.86）に しるしが 乗る 予定）」「`consult_bg.png`（1920×1080。ミクロしんりょうじょの へや。左に 人物、右に ふきだしが 乗るので 落ち着いた 色に）」。
- `docs/art_orders/W4_02_ものしりカードの挿絵.md`：「`card_ep01_karte.png`・`card_ep02_karte.png`・`card_ep03_karte.png`（512×600。その 話の『これからは？』の 絵：はみがき／よく かんで 食べる おとうさん／やさいと ヨーグルト）」。
- 完了：`python3 tools/build_dashboard.py --html /tmp/…/index.html` が 通る（dashboard.md の 表の 形を こわして いない）。

**7. 仕上げ**
- `tools/run_tests.sh`（全部）。`git status` で GLB・WAV に 差分が 無い こと、新しい `.gd.uid` が 入っている ことを 見る。
- コミット、push（CLAUDE.md「ブランチとダッシュボード」の とおり）。

M1 で 触る ファイル：新規 5（`episode_db.gd`、`flow_screen.gd`、`talk.gd`、`guess.gd`、`docs/episodes.md`）／改名して 作りかえ 2（`karte.gd`、`episode_select.gd`）／変更 `game.gd`、`save_data.gd`、`stage_db.gd`、`level.gd`、`mission.gd`、`hud.gd`、`card.gd`、`pause.gd`、`title.gd`、`zukan.gd`、`ui_theme.gd`、`project.godot`、`tests/smoke.gd`、`tests/shot.gd`、`tools/run_tests.sh`、`tools/screenshot.sh`、`tools/make_screenshots.sh`、`tools/build_dashboard.py`、`.github/workflows/test.yml`、文書 9 つ。**変えない**：`blender/`、GLB、`autopilot.gd`、`probe.gd`、`entities/`、`player/`。

---

## 8. 4〜10 話の 追加手順

作る 順は story.md 9 章と 同じ：**ep5 → ep8 → ep7 → ep6 → ep4 → ep9 → ep10**（前の 話で 作った しくみを 次が 使う）。どの 話も 共通で：`EPISODES` に 1 件 足す → `validate()` → `tools/run_tests.sh --episode=epNN` → 全テスト → `card_epNN_karte.png` を W4_02 に 追記 → dashboard.md・progress.md。テストは `EpisodeDB.ids()` を 回るので、足した 話は 自動で 対象に なる。

### ep05「せきが とまらない」（はな → はい → はな）

- **データ**：① `{"place": "nose", "reverse": true, "flow_speed": 3.0, "spawn": {"skip": ["card_sneeze"], "add": [{"mk": "enemy_virus", "path": 0.35, "side": 1.5}, … 4 つ]}, missions: defeat virus 3 → reach}` ② lungs（ミッションは 既定と 同じ ものを 書く）③ nose（既定と 同じ：くしゃみで 出る）。`after` で「くうきの みちを たどって はい（肺）へ」「さいごは くしゃみで だっしゅつ」。よそう：nose と lungs が `go`。
- **コード**（`level.gd`）：
  - `spawn.add`：`_ready()` の `_build_path()` と `_spawn_all()` の 間に `_add_spawns()`。1 件ごとに `markers.append({"node": null, "kind": …, "rest": […], "name": "MK_<mk>_a<i>", "position": pos, "basis": Basis.IDENTITY})`。`pos` は `"path": 0.35`（道の 割合。`path.sample(path.total * f)` ＋ 右へ `side` m）か、`"near": "neuron_2", "offset": Vector3(3, 0, 2)`（いまある マーカーの そば。ep7 で 使う）。`mk` の 1 語目は `enemy`／`friend`／`pickup`／`deliver` だけ。`_fit_missions()` は `markers` を 数えるので そのまま 効く。
  - 床の 検査：GLB に 無い 点は `probe.gd` が 見ない。代わりに Level が 始まって 0.5 秒後、`add` した 点の 真下に ゆかが あるか（`ModelLib.snap_to_floor` と 同じ レイ）を 調べ、無ければ `data_warnings`。てきは `hover_step()`、なかまは `_stick_to_floor()`、ひろいものは `snap_to_floor()` で ゆかへ 付くので、高さは 道の 中心線の ままで よい。
  - `reverse`：`_collect_markers()` の さいごで `MK_player` と `MK_goal` の `position` を 入れかえ、`_build_path()` で 点の 順を 逆に、`_spawn_player()`（431-439 行）で `reverse` の ときは マーカーの 向きを 使わず `path.direction_at(spawn_point)`。チェックポイントは 道の 進み（285 行）で 判定して いるので そのまま。
  - `episode_db.gd` の `validate()`：`spawn` の キーに `add`、場面の キーに `reverse` を 通す。
- **仮モデル・発注書**：なし（virus・boss_virus は ある）。

### ep08「かいだんで いきが きれる」（けっかん → しんぞう みぎ → しんぞう ひだり）

- **データ**：① vessel（`flow_speed: 2.0`、`cheer rbc 5`「せっけっきゅうを とおしてあげよう」→ reach。あぶらの かたまりは GLB の `Cholesterol` と `MK_card_cholesterol` が そのまま 使える）② heart ③ heart2（`gate 2` → reach）。よそうは `{"place": "heart", "label": "しんぞう（心臓）", "go": true}`。カルテの `next` で「なおすのは おいしゃさんと、まいにちの しょくじと うんどう」と はっきり 言う（story.md 8 章）。
- **コード**：**つづきから**（3 場面で 長いので ここで 足す）。`save_data.gd` の 既定値に `"resume": {}`（`{"ep", "scene", "damaged", "guess"}`。キーを 足すだけ なので version は 上げない。読みこみで 話 id と 場面の 範囲を 検査）。`Game._enter("scene")` で `scene_index >= 1` なら 書き、`_enter("karte")` で 消す。カルテえらびの 右の パネルに「つづきから ▶（ばめん 2 から）」（フォーカス）と「さいしょから」。入りかたは いまある `start_episode(id, "scene", n)`。smoke に「場面 1 を 終えて カルテえらびへ もどり、つづきから 入ると 場面 2 の 場所に なる」を 1 件。
- **仮モデル・発注書**：なし（おじいちゃんの 顔と `bodymap_jiji.png` は M1 で 追記ずみ）。

### ep07「あたまが ぼんやり」（のう。てき なし・そうじ）

- **データ**：① brain：`"spawn": {"add": [{"mk": "pickup_waste", "near": "neuron_1", "offset": Vector3(3, 0, 2)}, … 6 つ]}`、`sequence 3`「しんけいの リレーを てつだおう」・`collect waste 6`「のうの ごみを かたづけよう」→ reach。`goal_say` で「ばいきんは いなかったね。ねぶそくで そうじが おわっていなかったんだ」。
- **コード**：`pickup.gd:54-66` を 種類ごとの `CONFIG` に（`"nutrient": {"pocket": true}`、`"heart_item": {"heal": 1}`、`"waste": {}` ＝ ひろうと 消えるだけ。ポケットに 入れない）。`StageDB.KIND_NAMES` と `ModelLib.PLACEHOLDER_COLORS` に `waste`。`STAGES` の brain の `cards` に `"waste"`（「ねている あいだに、のうは いらなく なった ものを ながして かたづける」）。自動操縦は 変更なし（`collect` は いちばん 近い ひろいものへ 行く）。
- **仮モデル**：`blender/characters.py` の `BUILDERS` に `waste`（灰色の もやもや玉）→ `godot/assets/models/characters/waste.glb`。
- **発注書**：`W2_03_アイテムと小物.md` に waste、`W4_02` に `card_brain_waste.png`。

### ep06「はなが むずむず、でも かぜじゃない」（はな。てき なし・なだめる）

- **データ**：① nose：`flow_speed: 1.0`、`add` で `pickup_pollen` 5・`friend_mihari` 3・`deliver_exit` 1（`"path": 0.93`）。`cheer mihari 3`「みはりの さいぼうを なだめよう」（`each_say`：「かふんは てきじゃ ないよ。おちついて！」）・`collect pollen 5`・`{"type": "deliver", "target": "exit", "item": "pollen", "count": 5, "text": "かふんを そとへ はこぼう"}` → reach。
- **コード**：`deliver` の 一般化 ― ミッションに `item`（既定 `"nutrient"`）、`deliver_zone.gd:54-64` の `"nutrient"` 固定を `accepts` に（Level が ミッションの `item` を 入れる）、`level.gd:533` の「えいようを とどけた！…」を ミッションの `each_say`／`done_say` に まかせる、`hud.gd:136-141` の ポケット表示と `level.gd:451-454` の 文を `StageDB.kind_name()` で、`_fit_missions()` の `deliver` を `item` で 数える。`Friend.CONFIG`（`friend.gd:11-16`）に `"mihari": {"radius": 0.9, "move": "static", "panic": true}`（さわる 前は 赤く ふるえ、`cheer()` で おちつく）。`pickup.gd` の CONFIG に `"pollen": {"pocket": true}`。`STAGES` の nose の `cards` に `pollen`・`mihari`（「かふんは てきでは ないのに、みはりの さいぼうが けいほうを ならしすぎる」。細かい 名前は 出さない）。
- **仮モデル**：`pollen`（きいろい つぶ）、`mihari`（目の ついた みはり役。おおさわぎ／おちついた）、`exit` は いまの ゴールの わっかの 色ちがいで 代用。
- **発注書**：`W2_02_なかま.md` に mihari（2 表情）、`W2_03` に pollen、`W4_02` に `card_nose_pollen.png`・`card_nose_mihari.png`。

### ep04「ひざを すりむいた」（ひふ（新）→ けっかん）

- **データ**：`StageDB.STAGES` に 場所 `skin`（`"id": "skin", "order": 11, "name": "ひふ", "kanji": "皮膚", "env": "stage_skin", "kind": "arena"`、色、既定の ミッション ＝ 下の ①、`cards`：stage・platelet・bacteria・scab、`summary`、`quiz`）。`EpisodeDB.ORGAN_POS["skin"] = Vector2(0.43, 0.86)`（ひざ）。① skin：`collect platelet 6` → `{"type": "deliver", "target": "wound", "item": "platelet", "count": 6}`・`cheer wbc 3`・`defeat bacteria 3` → reach ② vessel：`"hide_nodes": ["Cholesterol"]`、`"spawn": {"skip": ["card_cholesterol"], "swap": {"friend_rbc_2": "friend_wbc", "friend_rbc_4": "friend_wbc", "friend_rbc_6": "friend_wbc"}, "add": [bacteria 3]}`、`cheer wbc 3`・`defeat bacteria 3` → reach。
- **コード**：`blender/stages.py` に `build_skin()` と `BUILDERS["stage_skin"]`（マーカー：`MK_player`、`MK_goal`、`MK_path_00N`、`MK_pickup_platelet_1..6`、`MK_deliver_wound_1`、`MK_enemy_bacteria_1..4`、`MK_friend_wbc_1..3`、`MK_pickup_heart_item_1`）。`Enemy.CONFIG`（`enemy.gd:8-13`）に `bacteria`、`pickup.gd` の CONFIG に `"platelet": {"pocket": true}`。`hide_nodes`：`level.gd` の `_load_env()`（145-152 行）で `_ensure_collisions()` の 前に `env.find_child(name)` を `free()`（けんたくんの けっかんに あぶらの かたまりは 無い）。`probe.gd` と smoke の 場所の 回は `STAGES` を 回るので 自動で 対象に なる。README「場所を 増やすには」。
- **仮モデル**：`stage_skin.glb`、`bacteria`、`platelet`、`wound`（とどける たびに ふさがって かさぶたに なる）。
- **発注書**：`W3_01_からだのぶたい.md` に ひふ、`W2_01_てき.md` に bacteria、`W2_03` に platelet・きず／かさぶた、`W4_01` に `stage_icon_skin.png`、`W4_02` に `card_skin_*.png`。

### ep09「なんか さいきん だるい（前編）」（けっかん → しんぞう みぎ。手がかりあつめ）

- **データ**：`culprit` を 書かない。① vessel：`hide_nodes`、`swap` で rbc の 一部を `friend_wbc_rush` に、`add` で `pickup_clue` 3。`{"type": "collect", "target": "clue", "count": 3, "text": "てがかりを さがそう", "each_say": ["はっけっきゅうが いそいでいるね。どこへ いくんだろう？", …]}` → reach ② heart：`add` で clue 2、`gate 2`・`collect clue 2` → reach。さいごの `after`：`banner`「つづく……」＋「はい（肺）の ほうに おおきな かげが……」。カルテは「まだ わからない。てがかりは はい（肺）を さしている」「ねつが つづく ときは がまんしないで おとなに いおう」。
- **コード**：`pickup.gd` の CONFIG に `"clue": {}`、`Friend.CONFIG` に `"wbc_rush": {"radius": 0.9, "move": "flow", "model": "wbc"}`（`friend.gd:46` の モデル名を CONFIG から 取る）。新しい ミッション型は いらない（手がかりの ことばは `each_say`）。
- **仮モデル**：`clue`（ひかる むしめがね）。**発注書**：`W2_03` に clue。

### ep10「（後編）」（はい。はいえんの ボス）

- **データ**：`consult` は ピコの おさらい（`who: "pico"`）。よそう：lungs が `go`（「てがかりは どこを さしていた？」）。① lungs：`"bgm": "bgm_boss"`、`"spawn": {"swap": {"boss_boss_virus": "boss_boss_haien", "enemy_virus": "enemy_bacteria"}, "add": [medicine 2]}`、`cheer wbc 3`（`done_say`：「びょういんの おくすり（てんてき）が とどいたよ！ ひかる カプセルを とって パワーアップ！」）・`collect medicine 1`・`boss 1` → reach。`SEASON_COMPLETE = true`、`ENDING` の 文を 仕上げる。
- **コード**：`boss.gd` の 固定値（17-23 行：種類・HP・速さ・半径、64-67 行：ひらく／とじる、77-91 行：手下）を `Boss.CONFIG[kind]`（HP、速さ、ひらく／とじる 秒、手下の 種類と 数、`needs_power`）に。`level.gd:290-296` で 種類を マーカーから 取り、`level.gd:511,584` と `friend.gd:136` の `"boss_virus"` 固定を `is Boss` に。おくすり：`pickup.gd` の CONFIG に `"medicine": {"power": true}`、`player.gd` に `powered`（**その 場面の あいだ ずっと**。時間切れを 作らない ＝ 取りなおしで 詰まらない）、`projectile.gd:43` の ダメージを `2 if powered else 1` に。`needs_power` の ボスは `powered` で ない 弾を はじき、ピコが「まだ きかない！ おくすりの カプセルを とろう！」（5 秒に 1 回）。5 話の ボスと 見た目・しくみを はっきり 変える（story.md 7 章）。`STAGES` の lungs の `cards` に `haien`・`medicine`（「ばいきんの はいえんには こうせいぶっしつが きく。ウイルスには きかない」）。
- **仮モデル**：`boss_haien`、`medicine`。**発注書**：`W2_01` に はいえんの ボス、`W2_03` に てんてきの おくすり、`W4_02` に `card_lungs_haien.png`・`card_lungs_medicine.png`。

---

## 9. リスクと 決めたこと

### 9.1 決めたこと（4 つの 案が 分かれた 点）

| # | 決めたこと | とらなかった 案 | 理由 |
|---|-----------|--------------|------|
| 1 | 話は 新しい autoload `EpisodeDB`（別ファイル）。`STAGES` は 変えない | （全案 一致） | ダッシュボードの パーサ、挿絵・既読の キーが そのまま |
| 2 | よそうは「`go` を えらぶ まで えらびなおし」。えらびごとに `go`、道順は 変えない、ほしに 入れない | どれを えらんでも 進んで ヒントを 場面に 足す（案 2）／場面ごとに 2 回目の よそう（案 3）／`sharp` の 印（案 4） | story.md の「まちがえても ヒントが ふえるだけ」に いちばん 近く、症状から 場所を 考える 意味が のこる。3 たくなので 多くて 3 回で 進む。3 話は い（胃）と しょうちょうの 両方を `go` に して、当たっている 子を「ちがう」と 言わない。2 回目の よそうは 10 話の `guess` で 足りる |
| 3 | 場面の あいだは `talk.gd`（Level を 片づけてから 全画面）。そうだんと 同じ 画面 | 止まった Level の 上に カード（案 1）／半透明で 重ねる（案 3）／専用の Interlude 画面（案 4） | 画面が 1 つで 済む。話す 人の 顔と 複数ページが 使える。「画面か Level の どちらか 1 つだけ」に すると、タッチの ボタン・HUD・ポーズの 重なりを 考えなくて よい |
| 4 | 画面は `Game.testing` で 自動送り しない。テストが フォーカス中の ボタンを 押す | 画面が `call_deferred` で 自分で 進む（案 1・2） | 「いつも フォーカスが ある」を 毎回 自動で 検査できる。`shot.gd` の 小細工も 消える。ヘッドレスで フォーカスと `pressed.emit()` が 動く ことは 確認ずみ |
| 5 | スポーンの 上書きは `skip`／`swap`（マーカー名の 前方一致）。M1 は これだけ | `kind:sub` の 記法と `off/remap/add/env_off/limit`（案 2）／「種類 → 出す 数」の 辞書（案 4） | 12 行で 書け、名前を 読みかえる だけなので `_spawn_all()` を 触らない。数の 指定は `skip: ["enemy_pylori_4", …]` で 書ける |
| 6 | GLB に 無い 点へ 出す `spawn.add` は **ep5 で** 作る（M1 では 作らない） | M1 で `add` と「たたかう ぜんだまきん」（案 2）／ずっと 作らず GLB に マーカーを 足して 既定で 0（案 4） | M1 の 3 話は いまの マーカーで 足りる。あとの 話は 場所ごとに GLB を 作りなおすより データで 置く ほうが 軽い（床は 実行時の 吸着 ＋ `data_warnings` の 検査で 守る）。新しい 場所（ひふ）は GLB に マーカーを 入れる |
| 7 | ミッションの 型は ふやさない（しらべる・なだめる ＝ `cheer`、そうじ ＝ `collect`）。`each_say`／`done_say`／`goal_say`／`clear_say` で 言いかえる | `check`・`calm`・`clue` 型（案 2）、`find` 型（案 1・3） | 型を ふやすと 矢印・守り・自動操縦の 3 か所を 直す。文と kind で 同じ 体験に なる |
| 8 | ほしは 3 つの 印を **回を またいで ためる** | いままでどおり 1 回の 最大値（案 1〜3） | 1 話が 10〜15 分。クイズを まちがえた だけで やりなおしは きびしい。やめたければ `record_episode()` の 1 行 |
| 9 | 「つづきから」は **ep8 で** 足す（M1 は 無し） | M1 から 場面ごとに セーブ（案 2〜4） | M1 は 多くて 2 場面。やりなおしは 場面単位で できる。セーブの キー・カルテえらびの 分岐・テストが 増えるので、3 場面の 話と いっしょに |
| 10 | テストは 全カルテ ＋ **全 10 場所**（場所モード） | カルテで 使わない 場所だけ（案 1〜3） | 規則が 1 つで、`--stage=mouth` が そのまま 生きる。実時間は 全部で 15 秒ほど |
| 11 | ダッシュボードは `episode_db.gd` を 正規表現で 読む ＋ `run_tests.sh` で 毎回 試しに 作る | smoke が `[db] {JSON}` を ログに 出す（案 4） | テストログが 無くても 表が 出る。書きかたの きまりは ファイルの 先頭に 書き、こわれたら テストで 分かる |
| 12 | ずかんは「カルテの 段 ＋ 使った 場所の 段」 | 話ごとの 段に カードを 振りわける（案 2） | 知識カードは 場所の もの（2 話と 3 話が 同じ い（胃）の カードを 使う）。振りわけは 規則が 不自然に なる |
| 13 | 矢印は いまの「リストの 上から」の まま。ミッションの **順番で** 調整する | `"arrow": "nearest"`（案 1） | しょうちょうは `collect → deliver → cheer` の 順で 38.6 秒（いまと 同じ）。コードを 足さなくて よい |
| 14 | `stage_select.gd` → `episode_select.gd`、`result.gd` → `karte.gd` に 改名。`Game.show_stage_select()` → `show_episode_select()` | 名前を のこす（案 1） | 中身と 名前を 合わせる。呼ぶ 所は 3 か所だけ |
| 15 | HUD の 題は 場所の 名前だけ | 「カルテ 3　い（胃）　1 / 2」（案 2・3） | 場面の 数は 3 話の「ちがった！」の ねたばれ。長い 題は はみ出す |
| 16 | 場所の カードは はじめての ときだけ。場所の「まとめ」は 場面クリアで 既読に（ポップアップなし） | 毎回 出す（いま）／まとめを ずかんから 外す（案 1） | そうだん ＋ よそう ＋ カード で 遊ぶ 前の ボタンが 多すぎない ように。内容は ずかんで 読める |
| 17 | はじめての 1 回だけ `OPENING`（2 ページ）を そうだんの 前に | 物語カードを のこす（案 1）／無し（案 2〜4） | 「ミクロしんりょうじょの 見習い」の 設定を 伝える 場所が 要る。`talk.gd` を 使うので コードは 3 行 |
| 18 | CI で スクリーンショットを 撮らない | 撮って artifact に（案 4） | 入れるなら ユーザーに 聞いてから。M1 の 範囲外 |

### 9.2 リスク

| リスク | 対策 |
|-------|------|
| 場面の データの まちがいで ゴールが 開かない | `_fit_missions()`（実行時に 数を 合わせる）＋ `data_warnings` を テストで 失敗に ＋ `validate()`。確認ずみ（4.3） |
| よそうで 行き止まり | `go` の ボタンは 押せなく ならない。`validate()` が `go` を 1 つ 以上 求める |
| 画面で フォーカスが 消えて ゲームパッドの 子が 止まる | 作りかえの たびに `set_focus()`、`flow_screen.gd` の 見はり、テストの 検査（30 フレーム） |
| 古い セーブで 落ちる・合計が 狂う | version 2 への 移行 ＋ 型の 検査 ＋ smoke の `_check_save()`（v1・こわれた JSON・型ちがい・知らない 版）。**いまの ほしは 0 に もどる。ずかんは のこる** |
| テスト・撮影が 本物の セーブを 書きかえる | `SaveData.use_path()` |
| 1 話が 長い。とちゅうで やめると そうだんから | M1 は 多くて 2 場面（自動操縦で 計 1 分、子どもで 6〜10 分）。やりなおしは 場面単位。「つづきから」は ep8 で |
| 遊ぶ 前の 文が 多い（6 さい） | そうだん 2 ページ、1 ページ 2〜3 行、時間で 進めない、場所の カードは 初回だけ。`validate()` が 長さを 見る |
| タッチの ボタンが 画面の 上に のこる | `_set_screen()` で かならず かくす |
| 前の Level の ノードが 同じ フレームに グループへ のこる | 数は マーカーから 数える。場面の 間には かならず 画面か、少なくとも 場所の カード／`started` 待ちが 入る |
| ダッシュボードの 正規表現が 書きかたに 弱い | きまりを `episode_db.gd` の 先頭に 書く。`run_tests.sh` が 毎回 試しに 作る |
| `const` の 辞書に 書きこんで エラー | `scene_stage()` は かならず `duplicate(true)` の 写しに 書く。`Game.episode` には 書かない |
| 継いだ 画面で `const T` を もう一度 書いて エラー | 土台（`flow_screen.gd`）だけに 置く（3.3） |
| 仮の 顔が さびしい | コードで 描く 顔 ＋ 置くだけで 差しかわる 口（3.5）。同じ コミットで 発注書に 追記 |
| 体の 事実 | 下の 9.3。レビュー（タスク #16）で もう一度 見る |

### 9.3 体の 事実で 気を つけた 点

- **1 話**：あなの あいた むしばは 自分では なおらない。患者の おれいは「らくに なった。はいしゃさんにも いってくる」、カルテは「はいしゃさんに なおしてもらおう」。
- **2 話**：はやぐいが ピロリきんを よぶ とは 言わない。カルテの「どうして？」は 2 つを 分けて 書いた。「ピロリきんは びょういんで しらべて、おくすりで なおせる」。患者は おとうさん（子どもの 腹痛の 原因としては まれ。story.md 8 章）。
- **3 話**：入口は「おみずと いっしょに ごくん」。おなかの きんが 多いのは 本当は だいちょう。story.md と いまの カード（`stage_db.gd:97-98`「おなかの なかに すむ」）に 合わせて「しょうちょう（小腸）で あくだまきんが ふえていた」と した。**気に なる なら カルテの 文だけ「ちょう（腸）で」に 丸める**（場面は しょうちょうの まま）。

### 9.4 ユーザーに 伝える・確かめる 点

1. いまの セーブの ほしは 0 に もどる（ずかんは のこる）。
2. ほしを「別々の 回で 取れる」に 変えた（決定 8）。
3. ずかんは「カルテの 段 ＋ 場所の 段」に した（決定 12）。
4. 3 話の「しょうちょうで あくだまきん」の 言いかた（9.3）。
5. 第2弾の 発注（W1-01）は、患者 3 人の 追記（手順 6）の あとに 出すと 二度手間に ならない（story.md 9 章）。
