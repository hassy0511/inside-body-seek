# 音楽（BGM と ジングル）

ゲームの 音楽は 全部 `tools/music/`（Python）で 楽譜から 作る。人が 聞いて 確かめる 前に、
つなぎ目・音量・ピーク・長さ・ファイルの 大きさを 機械で はかり、楽譜も 読んで 確かめる。

- 置き場所：`godot/assets/audio/bgm_<名前>.ogg`（ループ）、`jingle_<名前>.ogg`（1 回だけ）、
  `clear.wav`（場面クリア。モノラル 16 bit）。それぞれ Godot の `.import` も 作る。
- 楽譜：`tools/music/tracks/<名前>.py`（1 曲 1 ファイル）。お手本は `tracks/bgm_title.py`
  （先頭の コメントに 形式・調・和音・モチーフの 場所）。6/8 の 小さな 例は `tracks/_demo_68.py`、
  ループしない 短い 曲の 例は `tracks/_demo_jingle.py`（`_` で 始まる 名前は 例。ゲームには 入らない）。
- 共通の モチーフ：`tools/music/motif.py`（2 小節・7 音。ハ長調で C G F E | D E G）。
- 作業用の ファイル（WAV・パートごとの 音・MIDI・図・報告）は `tools/music/out/<名前>/`。
  コミットしない（`.gitignore` 済み）。

## 作りなおす

必要な もの（Ubuntu / Debian）：

```bash
sudo apt install fluidsynth musescore-general-soundfont fluid-soundfont-gm ffmpeg
python3 -m venv ~/music-venv
~/music-venv/bin/pip install mido numpy scipy soundfile pyloudnorm matplotlib
```

リポジトリの 一番上で：

```bash
~/music-venv/bin/python -m tools.music build bgm_title     # 1 曲（書き出して すぐ 確認も する）
~/music-venv/bin/python -m tools.music build               # 全部
~/music-venv/bin/python -m tools.music check [名前...]      # 確認だけ（MUSIC: OK か 失敗の 一覧）
~/music-venv/bin/python -m tools.music seamtest bgm_title   # つなぎ目の 確認が 壊れた ループを 見ぬく ことを 示す
GODOT=/path/to/Godot_v4.7 ~/music-venv/bin/python -m tools.music godot   # Godot で ループ再生を 確かめる
~/music-venv/bin/python -m tools.music table               # この 文書の 表を 書きなおす
```

同じ 入力からは いつも 同じ 音が できる（人間らしい ゆれも 曲名と パート名から 決まる 乱数。
`bgm_title` を 2 回 作って WAV・OGG・パートの 音が バイト単位で 同じ ことを 確かめた）。

### 音色（サウンドフォント）

`/usr/share/sounds/sf3/MuseScore_General_Full.sf3`（apt の `musescore-general-soundfont`）。
ライセンスは MIT（一部 パブリックドメイン・CC0。全文は
`/usr/share/doc/musescore-general-soundfont/copyright`）。86 MB あるので コミットしない。
別の 場所に ある ときは 環境変数 `MUSIC_SOUNDFONT` で 指す。音は 書き出した OGG / WAV を コミットする。

## しくみ

1. `score.py` で 曲を 書く（小節・拍・和音記号・音階の 度数・パターン・アルペジオ・ドラムの 譜・
   強弱の 曲線・CC 11 の ふくらみ）。
2. `render.py` が スウィング・ゆれ（タイミング ±数 ms、強さ ±4。ドラムは 時間を ずらさない）・
   アーティキュレーションを 付けて MIDI に し、FluidSynth で **パートごとに** 44.1 kHz ステレオで 鳴らす
   （FluidSynth の リバーブと コーラスは 切る）。
3. パートごとに 部屋の 響き（seed つきで 作った 小さな 部屋の インパルス応答。200 Hz 以下は 響かせない）を
   送りの 量だけ 足して 混ぜる。
4. **ループの つなぎ目**：1 周 ぶん と その あとの 響き（4 秒）を 鳴らし、最後の 小節の あとの 響きを
   曲の 頭に 重ねる。2 周 続けて 鳴らして 2 周目を 切り出すのと 同じ 中身だが、サンプル単位で ぴったり 合う。
   - 2 周目を 切り出す やりかたも 試した（`MUSIC_LOOP_METHOD=twopass`）。FluidSynth の MIDI プレーヤーは
     音の 出だしを 64 サンプルの 区切りに、ミリ秒単位の 時計で 合わせるので、2 周目が 1 周目より 最大 63 サンプル
     ずれ、つなぎ目で 響きの 位相が 合わない。はかると「つなぎ目の 予測誤差」が 7.2（上限 3）で 失敗した。
     重ねる やりかたでは 0.5。
   - ループは 1 拍目の 32 サンプル 前から 始まる（つなぎ目が 打楽器の 最初の 1 サンプルに かからないように）。
5. マスター：30 Hz の ハイパス、ゆるい リミッター（先読み、60 ms で 戻る）、音量を そろえる
   （ループ −18 LUFS、短い 曲 −16 LUFS）、トゥルーピークは −2.0 dBTP を ねらう（確認の 上限は −1.5）。
   ループは 輪のまま 処理する（ハイパスも リミッターも つなぎ目を またいで 続く）。
6. 書き出し：作業用 WAV（16 bit）、コミットする OGG（Vorbis `-q:a 2`。ビットが 毎回 同じに なる 設定）、
   Godot の `.import`（ループは `loop=true`、短い 曲は `false`）。`clear.wav` は モノラル 16 bit で、
   今の `.import` を そのまま 使う。

1 曲の build は **その 曲の ファイルだけ** 書く（OGG・`.import`・`tools/music/out/<名前>/`）。一時ファイルも
曲名つきで `tools/music/out/<名前>/tmp/` に 置く。この 文書の 表は `table` だけが 書く。何人かが 同時に
別の 曲を build しても ぶつからない。

## 確認（`python -m tools.music check`）

**失敗に なる もの**（プレイヤーが 聞く ものを 守る）

| 項目 | 内容 |
|---|---|
| つなぎ目 | 終わりの 50 ms で 線形予測（24 次）を 作り、つなぎ目の あとの 4 サンプルの 予測誤差を、前の 誤差の 99.5 % 点と くらべる（3 倍まで）。前後 2 ms の 音量が 10 dB 以上 落ちない こと（頭に 響きが ない＝1 周目を 使った）。`seamtest` で、正しい ループは 通り、1 周目を 1000 サンプル 短く 切った もの・1000 サンプル 短い もの・頭を 20 ms 削った ものは 落ちる ことを 示す |
| ピーク | トゥルーピーク（4 倍 オーバーサンプル）−1.5 dBTP 以下 |
| 音量 | 目標 ±0.5 LU（ループ −18、短い 曲 −16。モノラルは 両方の スピーカーで 鳴らした ものとして はかる） |
| 無音 | ループの 中に 0.4 秒より 長い デジタル無音が ない |
| 長さ | 小節数 × 拍 × テンポ（MIDI の 整数テンポ）から 決まる サンプル数と ぴったり 同じ |
| OGG | OGG を 戻した 長さが WAV と サンプル単位で 同じ |
| ステレオ | 左右の 差が 中央より 40 dB 以上 小さく ない（clear.wav は モノラルで よい） |
| 直流 | 平均値 0.002 以下 |
| 帯域 | 250 Hz 未満 ≤ 85 %、250 Hz〜4 kHz ≥ 8 %、4 kHz 以上 0.2〜35 % |
| 大きさ | ループ 1 秒 あたり 12,000 バイト まで、短い OGG 90,000、clear.wav 330,000、全部で 8,000,000 バイト まで |
| 作りなおし | 楽譜が 前の build の あとで 変わって いたら 失敗（もう一度 build する） |

**注意（報告に 出る もの。わざと なら そのまま で よい）**：音階にも 和音にも ない 音（`*` で 「わざと」）、
強拍の メロディーが 和音の 音で ない、メロディーと 短 2 度・短 9 度で 8 分音符 以上 重なる、
強拍の ベースが 和音の 外、楽器の 実際の 音域の 外、メロディーの 音域（19 半音 まで・C7 まで）、
前の 小節と 全く 同じ 小節、部分ごとの 1 小節 あたりの 音の 数（うすい・あつい の 交代）、
強さの ばらつき、メロディーより 大きい 伴奏パート（部分ごと、LUFS）、2〜5 kHz・250 Hz 以下・60 Hz 以下の 割合。

図（`tools/music/out/<名前>/`）：`roll.png`（ピアノロール。パートごとの 色、小節線、部分の 名前、和音記号。
メロディーは 黒い ふち）、`spectrogram.png`、`seam.png`（つなぎ目の 前後 15 ms・60 サンプル・3 秒の 音量）。

## ゲームの 中で（Godot）

`godot/src/autoload/sfx.gd`（`Sfx`）が 鳴らす。

| どこ | 曲 | 決める ところ |
|---|---|---|
| タイトル・カルテえらび・ずかん・エンディング | `bgm_title` | `game.gd`（`show_title` など。前からの `Sfx.play_bgm("bgm_title")`） |
| そうだん・よそう・あとの はなし・体に はいる／でる 画面 | `bgm_clinic` | フェーズ（`Sfx.PHASE_MUSIC`） |
| カルテと クイズ | `bgm_karte` | フェーズ `karte` |
| 場面（場所） | 場所の `"bgm"`（`stage_db.gd`） | `Game._start_level()` → `Sfx.stage_music()` |
| ボスの いる 場面（ミッションに `"type": "boss"`） | `bgm_boss` | `Sfx.stage_music()` |
| みちの ちず（フェーズ `hop`） | 通って きた 場所の 曲の まま | `PHASE_MUSIC` に 書かない |
| 体に はいる／でる 画面 | `jingle_enter`／`jingle_exit`（音楽の 上に） | `Sfx.PHASE_JINGLE` |
| カルテ「かいけつ！」 | `jingle_karte` | `karte.gd` の `_show_solved()` |
| 場面クリア・エンディング | `clear.wav` | `Sfx.play("clear")`（短い 曲として 鳴らす） |

場所の 曲：くち `bgm_mouth`、しょくどう・けっかん `bgm_tube`、い（胃）・しょうちょう `bgm_tummy`、しんぞう（みぎ・ひだり）`bgm_pump`、
はい（肺。ボスが いない とき）・はな `bgm_air`、のう `bgm_spark`。とおりみち（`"pass": true`）も 場所の 曲。

- フェーズは `Game.phase_changed` → `Sfx.on_phase()`（`game.gd` の `_ready` で つなぐ）。`PHASE_MUSIC` に ない フェーズ
  （`scene`・`hop`・しらない 名前）は 今の 曲の まま で、エラーに しない。
- 曲の 切りかえ：2 つの プレーヤーで 0.6 秒の 等パワーの クロスフェード。同じ 曲なら 何も しない（はじめから に もどらない）。
- 短い 曲（`jingle_*`・`clear`）：`Sfx.play_short()`（`Sfx.play()` で 呼んでも ここへ 来る）。鳴って いる あいだ
  音楽を 24 dB 下げる（0.12 秒で 下げ、0.6 秒で もどす。短い 曲は ハ長調で、場所の 曲とは 調が ちがう。
  少し 下げるだけだと 2 つの 曲が 同時に 聞こえて にごるので、ほとんど 聞こえない ところまで 下げる）。
- 音量：音楽 −5 dB（`MUSIC_DB`）、短い 曲 0 dB。はかった 値：曲は −18 LUFS（短い 曲 −16）、効果音 23 個の
  0.4 秒ごとの 大きさの 山は −19〜−2 LUFS（中央 −8）。−5 dB で 音楽は 平均 −23 LUFS（いちばん 大きい 所で −18）に なり、
  ふつうの 効果音は 音楽の 平均より 15 dB ほど、いちばん 大きい 所より 10 dB ほど 上に 出る（いちばん 小さい `hit` −19 でも 音楽の 平均より 上）。
  前の BGM（`bgm_stage.wav` を −8 dB）と ほぼ 同じ 大きさ。
- 音楽は 覚えておかない：鳴らして いる 曲と 消えて いく とちゅうの 曲だけを 持ち、消えきったら `stream = null` で 手ばなす。
  効果音（小さい WAV）は 覚えておく。
- テスト（`godot/tests/smoke.gd` の `_check_music`・`_check_phase_music`）：ゲームが 呼ぶ 曲の 名前を 全部 あつめ
  （場所の `"bgm"`・ボス・全カルテの 全場面・`PHASE_MUSIC`・`PHASE_JINGLE`・`src` の 中に 文字で 書いた `play_bgm("…")`／`Sfx.play("jingle_…")`）、
  ファイルが ある・ループは `loop=true`・短い 曲は ループしない・古い `bgm_*.wav` が ない・しらない フェーズで 曲が 変わらない、を 見る。
  全カルテを 通す とき、フェーズごとと 場所ごとに 鳴って いる 曲も 見る（はい（肺）は `bgm_boss`）。

## ブラウザ版（Web）での 鳴らし方

Godot 4.7 の 文書（Exporting for the Web → Audio playback）と ソース（`servers/audio/audio_server.cpp`、
`platform/web/audio_driver_web.cpp`、`platform/web/js/libs/library_godot_audio.js`、`scene/audio/audio_stream_player_internal.cpp`）で 調べた こと：

- 4.3 から ブラウザ版の 既定は **Sample** 再生（Web Audio の AudioBuffer で 鳴らす）。スレッドなしの 書き出しでも 遅れが 小さいが、
  バスの エフェクトなどは 使えない。プレーヤーの `playback_type` か 設定 `audio/general/default_playback_type.web` で **Stream**
  （Godot 自身が 混ぜる）に できる。スレッドなしでは Stream の 遅れが 大きく なる。
- Sample 再生では、ストリームを はじめて 鳴らす ときに `AudioDriverWeb::register_sample()` が **曲を 丸ごと ほどいて**
  （`mix()` で 全部の サンプルを 作る。メインスレッド）、float の 配列で JavaScript に わたす。60 秒の ステレオで 約 21 MB。
  この 登録を はずす `unregister_stream_as_sample()` は エンジンの どこからも 呼ばれず、GDScript からも 呼べない。
  登録の キーは ストリームの インスタンス ID なので、手ばなして 読みなおすと もう 1 つ 登録される。
- Stream 再生（スレッドなし）は、AudioWorklet が 読んだ ぶんだけ メインスレッドが 混ぜて 送る。リングバッファの 長さは
  `audio/driver/output_latency`（ミリ秒）× 44.1 kHz の 2 の べき。メインスレッドが その 長さより 長く 止まると とぎれる。

そこで：**音楽（ループと 短い 曲）の プレーヤーだけ `PLAYBACK_TYPE_STREAM`**、効果音は 既定の Sample（遅れが 小さい）。
`project.godot` の `audio/driver/output_latency.web=500`（バッファ 16384 フレーム ＝ 約 370 ms。音楽は 遅れても こまらない。
Sample の 効果音は この 設定を 通らない）。

はかった 結果（headless Chromium ＋ SwiftShader。ふだんの 1 フレームが 83〜117 ms と 遅い 環境。destination の 前に
AudioWorklet を はさんで 128 フレームごとの 音の 大きさを 記録。くわしい 数字は 2026-11-24 の 記録）：

| | Sample 再生（既定の まま） | Stream、latency 250 | **Stream、latency 500（採用）** |
|---|---|---|---|
| ループの つなぎ目（`bgm_title` 68.57 秒） | **140 ms の 無音** | すきま なし（前後 1 秒の 10 ms ごとの 最小 −32 dBFS） | すきま なし（最小 −32.5 dBFS） |
| 1 周 71.6 秒の 間の とぎれ（10 ms ごと −60 dBFS 未満。楽譜の 休み 57.0 秒を 除く） | 52.6 秒に 130 ms | 10 ms が 3 回 | **なし** |
| 曲を 変えた あと 1.5 秒の いちばん 長い フレーム | 233〜433 ms（毎回 ほどく） | 83〜117 ms | 83〜133 ms（ふだんと 同じ） |
| メモリ（Chromium 全体の PSS） | 830 → 990 MB（3 周で +160 MB） | 574 → 621 MB（3 周） | 10 周 50 回 切りかえて 540〜694 MB を 上下（ふえつづけない）。wasm 67 MB の まま、JS ヒープ 14〜20 MB |

ブラウザの 確かめは `URL?musictest` の ときだけ 使える `window.godotMusic(name)`（`sfx.gd` の `_web_test_hook`）で 曲を 回す。

## 聞く ページ（ダッシュボードの「おとを きく」）

CI が `tools/music_site.sh _site/music` で 曲を 写し（ffmpeg が あれば MP3 も 作る。無ければ OGG だけ）、
`tools/build_dashboard.py --music-dir _site/music` が 1 曲 1 つの プレーヤー（名前・どこで 鳴るか・調・テンポ・秒）を 出す。
ループの 曲には「つなぎ目の 前から」（おわりの 4 秒 前から 鳴らす）。どこで 鳴るかの 文は `build_dashboard.py` の
`MUSIC_SCREENS`／`MUSIC_AFTER` と `stage_db.gd` の `"bgm"`。手元で 見る ときは Range に こたえる サーバーで 出す
（`python3 -m http.server` は Range に こたえないので、シークと「つなぎ目の 前から」が 効かない）。

## 曲の 一覧

<!-- music-table:start (python -m tools.music table) -->

| name | where | tempo | metre | key | bars | seconds | LUFS | true peak (dBTP) | bytes |
|---|---|---|---|---|---|---|---|---|---|
| bgm_air | lungs (no boss), nose | 66 | 6/8 | E major | 32 | 58.18 | -18.0 | -1.9 | 634,305 |
| bgm_boss | scenes with a boss | 138 | 4/4 | D minor | 32 | 55.65 | -18.1 | -4.1 | 575,755 |
| bgm_clinic | consult, guess, the talk after a scene | 84 | 4/4 | F major | 24 | 68.57 | -18.0 | -1.9 | 744,861 |
| bgm_karte | karte and quiz | 92 | 4/4 | G major | 24 | 62.61 | -18.0 | -4.2 | 641,085 |
| bgm_mouth | mouth | 120 | 4/4 | D major | 32 | 64.00 | -18.1 | -2.0 | 712,437 |
| bgm_pump | heart (right and left) | 116 | 4/4 | Eb major | 32 | 66.21 | -18.0 | -3.7 | 718,470 |
| bgm_spark | brain | 108 | 4/4 | Bb lydian | 28 | 62.22 | -18.0 | -2.0 | 671,908 |
| bgm_title | title, episode select, picture book, ending | 112 | 4/4 | C major | 32 | 68.57 | -18.0 | -3.8 | 735,527 |
| bgm_tube | esophagus, blood vessel | 132 | 4/4 | A major | 32 | 58.18 | -18.0 | -4.6 | 650,053 |
| bgm_tummy | stomach, small intestine | 100 | 4/4 | G dorian | 24 | 57.60 | -18.0 | -2.8 | 660,278 |
| clear | scene clear | 160 | 4/4 | C major | 2 | 3.40 | -16.0 | -5.5 | 299,924 |
| jingle_enter | enter-the-body screen | 138 | 4/4 | C major | 2 | 3.98 | -16.0 | -5.2 | 46,596 |
| jingle_exit | leave-the-body screen | 138 | 4/4 | C major | 2 | 3.98 | -16.0 | -5.0 | 43,460 |
| jingle_karte | karte complete | 92 | 4/4 | G major | 1 | 3.31 | -16.0 | -5.5 | 36,776 |

All music files in godot/assets/audio: 7,171,435 bytes (budget 8,000,000).

<!-- music-table:end -->
