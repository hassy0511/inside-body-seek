extends Node
## 自動テスト（ヘッドレス）。
##   godot --headless --fixed-fps 60 --path godot res://tests/smoke.tscn [-- --episode=ep03 | --stage=mouth] [--debug]
## 1. src/ の 全スクリプトを 読みこむ
## 2. データを 調べる（EpisodeDB.validate ＋ 文が 箱に 入るか ＋ spawn の ルール）
## 3. セーブを 調べる（v1 からの 移行・こわれた ファイル・ほし・つづき）
## 4. 全カルテを カルテえらび → そうだん → よそう → からだに はいる → 場面（とおりみちも）→ みちの ちず → … → からだから でる → カルテ まで 通す
##    （画面は フォーカス中の ボタンを 押す ＝「いつも フォーカスが ある」ことも 見る。場面は 自動操縦）。
##    とおりみちは てき・あぶない もの なし、ゴールは はじめから 開く、かかった 時間（シミュレーションの 秒）を ログに 書く
## 5. タイトル、よそうの「もどる」、あたりの よそう、つづきから（場面の やりなおし・ポーズから やめる）、クイズの やりなおし、ずかん、
##    本物の 入力（矢印・決定・もどる の アクション）で 4 つの 画面を 動かす
## 6. 全部の 場所を 既定の ミッションで 自動操縦（カルテで まだ 使わない 場所も ここで 守る）
## 7. そうじゅう：ひろい 場所（口・心ぞう）で ← を 1 びょう 押すと 船と カメラが まわる・↑ で まえへ・↓ で うしろへ。
##    はじめての そうじゅうの てびきが 出て、まわる・すすむ を やると 消える（キーボード・タッチ）
## ほかに：みちの きまり（とちゅうの 場所を とばした 話は validate で 止まる）、遊びなおしの「とおりみちを とばす」、
##   v2 の セーブ（とおりみちを 入れる 前）の 読みかえ、音楽（ゲームが 呼ぶ 曲の ファイルが ある・ループの 設定・フェーズと 場所の 曲）
## ものしりカード：場面の とちゅうで ゲームが 止まらない・カードが ひらかない（4・6 の あいだ ずっと 見る）。みつけた しらせが HUD の
##   部品に 重ならない。「みつけた ものしりカード」の 画面は ふつうの 場面で 新しい カードが あった ときだけ 出る。
##   その 画面の 形・矢印・タイルを 開いて もどる・そこで やめた ときの つづきから・古い セーブ（_check_cards_screen）
## --episode= は 4 を その 話だけ、--stage= は 6 を その 場所だけ 回す（5 は 全部 回す ときだけ）。
## セーブは user://save_test.json を 使う（本物の セーブを さわらない）。

const MAX_SCENE_SECONDS := 420.0
## とおりみち（とおるだけの 場面）の 長さ（自動操縦の シミュレーションの 秒）。上限は 子どもが 40 秒で ぬける ように。
## 下限は「何も 見ずに おわる」ほど みじかく しない ため（くちは まっすぐ 走って 6.3 秒。子どもの 時間は まだ はかって いない）
const MAX_PASS_SECONDS := 40.0
const MIN_PASS_SECONDS := 5.0
## 7. の そうじゅうを 見る 場所（arena と rooms から 1 つずつ）
const STEER_PLACES := ["mouth", "heart"]
## ↓ を 押しつづけても へやの 外へ 出ないかを 見る 場所（作りなおした ひろい 場所と、くだの 場所。
## ちの くだ・はなは はじめが ひらいて いる：player.gd の TUBE_START_GUARD が おちない ように する）
const BACK_PLACES := ["mouth", "stomach", "intestine", "vessel", "nose"]
const MAX_UI_SECONDS := 30.0
## 物語の ひとことは 出てから 2 秒 上書きされない（level.gd の say_story）。その 間を フレームで 数える（少し 短めに 見る）
const HOLD_FRAMES := 110
const Autopilot := preload("res://tests/autopilot.gd")
const SelectScreen := preload("res://src/ui/episode_select.gd")
const TalkScreen := preload("res://src/ui/talk.gd")
const GuessScreen := preload("res://src/ui/guess.gd")
const KarteScreen := preload("res://src/ui/karte.gd")
const JourneyScreen := preload("res://src/ui/journey.gd")
const HopScreen := preload("res://src/ui/hop.gd")
const SteerGuide := preload("res://src/ui/steer_guide.gd")
const HudScreen := preload("res://src/ui/hud.gd")
const TitleScreen := preload("res://src/ui/title.gd")
const ZukanScreen := preload("res://src/ui/zukan.gd")
const CardsScreen := preload("res://src/ui/cards_found.gd")
const CardPopup := preload("res://src/ui/card.gd")
const KarteSheet := preload("res://src/ui/karte_sheet.gd")
const T := preload("res://src/ui/ui_theme.gd")

var _failures: Array[String] = []
var _log: Array[String] = []
var _only_place := ""
var _only_ep := ""
var _debug := false
var _finished := false
var _ep_done := false
var _phases: Array[String] = []
var _phases_at_end: Array[String] = []
var _scene_clears := 0
var _said: Array = []          # いまの 場面で HUD に 出た 文：[物理フレーム, 文]
var _text_seen: Dictionary = {}
var _pass_times: Dictionary = {}   # "ep02 scene 0 (mouth)" -> 秒
var _found_now: Array[String] = []   # いまの 場面で みつけた カード（Game.card_found）
var _cards_pending := false          # 場面が おわった：つぎは「みつけた ものしりカード」の 画面の はず
var _cards_want: Array[String] = []  # その 画面に ならぶ はずの カード
var _cards_screens := 0
var _card_stop_seen := {}            # 同じ 場面の ゲームが 止まった しらせを 1 回だけ 書く
var _chips_checked := {}             # 重なりを 見た しらせ（Control の id）
var _chips_seen := 0


func _ready() -> void:
	Game.testing = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			_only_place = a.substr(8)
		if a.begins_with("--episode="):
			_only_ep = a.substr(10)
		if a == "--debug":
			_debug = true
	var args_ok := true
	if _only_place != "" and not StageDB.stage_ids().has(_only_place):
		args_ok = false
		_fail("--stage=%s: そんな 場所は ない（%s）" % [_only_place, ", ".join(PackedStringArray(StageDB.stage_ids()))])
	if _only_ep != "" and not EpisodeDB.ids().has(_only_ep):
		args_ok = false
		_fail("--episode=%s: そんな カルテは ない（%s）" % [_only_ep, ", ".join(PackedStringArray(EpisodeDB.ids()))])
	SaveData.use_path("user://save_test.json")
	# 画面を いちばん せまい 形（1280×720）に する。ヘッドレスの 窓は 64×64 で、そのままだと
	# 「expand」の 設定で 1280×1280 に 広がり、たての はみ出しが 見えない
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	if get_viewport().get_visible_rect().size != Vector2(1280, 720):
		_fail("テストの 画面が 1280×720 で ない（%s）" % get_viewport().get_visible_rect().size)
	# 書き出した 版（ブラウザ版）は、この 設定が 無いと 行の 折りかたの データを 持たない：空白でしか 折れず、
	# テスト（エディタは データ入り）と ちがう 行で 折れて、はかった 箱から 文が はみ出す
	if not bool(ProjectSettings.get_setting("internationalization/locale/include_text_server_data", false)):
		_fail("project.godot の internationalization/locale/include_text_server_data が true で ない（ブラウザ版の 折りかえしが テストと ちがって しまう）")
	_check_scripts()
	_check_data()
	_check_spawn_rules()
	_check_journey_rules()
	_check_route_rules()
	await _check_sheets()
	_check_portraits()
	_check_music()
	_check_save()
	SaveData.reset()
	SaveData.set_setting("volume", 0.0)
	Game.phase_changed.connect(func(p: String, i: int): _phases.append("%s%s" % [p, str(i) if p in ["scene", "after"] else (str(Game.hop_from) if p == "hop" else "")]))
	# episode_finished の しゅんかんの フェーズ列を 写す（「つぎの カルテへ」は すぐ 次の 話の consult を 出すので）
	Game.episode_finished.connect(func(_id, _stars):
		_ep_done = true
		_phases_at_end = _phases.duplicate())
	Game.stage_started.connect(func(_sid): _said.clear())
	Game.card_found.connect(func(_sid, key): _found_now.append(key))
	Game.phase_changed.connect(_check_cards_phase)
	Game.phase_changed.connect(_check_phase_music)
	Game.said.connect(_on_said)
	Game.stage_finished.connect(func(sid: String, _stars):
		_scene_clears += 1
		_finished = true
		# ふつうの 場面で 新しい カードを みつけたら、つぎは「みつけた ものしりカード」（とおりみち・新しい カード なしは 出ない）
		_cards_pending = not Game.episode.is_empty() and not EpisodeDB.is_pass(Game.episode, Game.scene_index) and not _found_now.is_empty()
		_cards_want = _found_now.duplicate()
		_found_now.clear()
		if not Game.episode.is_empty():
			_info("  scene %d (%s) done" % [Game.scene_index, sid])
			_check_says())
	if args_ok and _only_place == "" and _only_ep == "":
		await _check_music_changes()
		SaveData.reset()
		SaveData.set_setting("volume", 0.0)
	# データに まちがいが あっても 先へ 進む（まちがった データでも 子どもが 詰まらない ことを 見る）
	if args_ok:
		if _only_place == "":
			for id in EpisodeDB.ids():
				if _only_ep == "" or id == _only_ep:
					await _run_episode(id)
		if _only_place == "" and _only_ep == "":
			await _check_skip()
			await _check_title()
			await _check_back()
			await _check_hit()
			await _check_resume()
			await _check_zukan()
			await _check_keys()
			await _check_cards_screen()
		if _only_ep == "":
			for id in StageDB.stage_ids():
				if _only_place == "" or id == _only_place:
					await _run_place(id)
			for id in STEER_PLACES:
				if _only_place == "" or id == _only_place:
					await _check_steering(id)
			if _only_place == "" or _only_place == "esophagus":
				await _check_esophagus()
			if _only_place == "" or _only_place == "stomach":
				await _check_pools()
			for id in BACK_PLACES:
				if _only_place == "" or id == _only_place:
					await _check_back_hold(id)
	_remove_test_saves()
	for k in _pass_times.keys():
		_info("pass scene %s: %.1fs (sim)" % [k, _pass_times[k]])
	_info("card chips checked: %d, cards screens: %d" % [_chips_seen, _cards_screens])
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


## テストが 作った セーブ（save_test*.json）を 消す
func _remove_test_saves() -> void:
	var d := DirAccess.open("user://")
	if d == null:
		return
	for f in d.get_files():
		if f.begins_with("save_test"):
			d.remove(f)


# ---------------------------------------------------------------- 1. スクリプト
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


# ---------------------------------------------------------------- 音楽
## ゲームが 呼ぶ 曲の 名前を 全部 あつめて、ファイルが ある・ループの 設定が 合う ことを 見る
## （場所の "bgm"・ボス・フェーズの 曲と ジングル・src の 中に 文字で 書いた play_bgm("…")／Sfx.play("jingle_…")）
func _check_music() -> void:
	var loops := {"bgm_boss": "boss", "bgm_title": "title"}
	var shorts := {"clear": "scene clear"}
	for st in StageDB.STAGES:
		if String(st.get("bgm", "")) == "":
			_fail("music: 場所 %s に \"bgm\" が ない" % st["id"])
		loops[Sfx.stage_music(st)] = "stage " + st["id"]
	for ep_id in EpisodeDB.ids():
		var ep := EpisodeDB.get_episode(ep_id)
		for i in ep["scenes"].size():
			loops[Sfx.stage_music(EpisodeDB.scene_stage(ep, i))] = "%s scene %d" % [ep_id, i]
	for ph in Sfx.PHASE_MUSIC:
		loops[Sfx.PHASE_MUSIC[ph]] = "phase " + ph
	for ph in Sfx.PHASE_JINGLE:
		shorts[Sfx.PHASE_JINGLE[ph]] = "phase " + ph
	var re := RegEx.create_from_string("(?:play_bgm|Sfx\\.play|play_short)\\(\"((?:bgm_|jingle_)\\w+|clear)\"")
	for path in _list_scripts("res://src"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			var n := m.get_string(1)
			if n.begins_with("bgm_"):
				loops[n] = path.get_file()
			else:
				shorts[n] = path.get_file()
	for n in loops:
		var path := Sfx.path_of(n)
		if not path.ends_with(".ogg"):
			_fail("music: %s（%s）の ファイル %s%s.ogg が ない" % [n, loops[n], Sfx.DIR, n])
			continue
		var s = load(path)
		if not (s is AudioStreamOggVorbis) or not s.loop:
			_fail("music: %s が ループに なって いない（.import の loop=true）" % path)
	for n in shorts:
		var path := Sfx.path_of(n)
		if path == "":
			_fail("music: 短い 曲 %s（%s）の ファイルが ない" % [n, shorts[n]])
			continue
		var s = load(path)
		if (s is AudioStreamOggVorbis and s.loop) or (s is AudioStreamWAV and s.loop_mode != AudioStreamWAV.LOOP_DISABLED):
			_fail("music: 短い 曲 %s が ループする" % path)
	# 古い BGM（.wav）は もう 使わない
	for f in DirAccess.get_files_at(Sfx.DIR):
		if f.begins_with("bgm_") and f.ends_with(".wav"):
			_fail("music: 古い %s が のこって いる" % f)
	# しらない フェーズは 曲を 変えない（エラーも 出さない）
	Sfx.play_bgm("bgm_title")
	Sfx.on_phase("no_such_phase", 0)
	if Sfx.bgm_name() != "bgm_title":
		_fail("music: しらない フェーズで 曲が 変わった（%s）" % Sfx.bgm_name())
	_info("music: loops %d, short pieces %d" % [loops.size(), shorts.size()])


## フェーズの 曲（sfx.gd の PHASE_MUSIC を 写さず、ここに 書く。表が まちがっても 気づく ように）
const PHASE_WANT := {
	"consult": "bgm_clinic", "guess": "bgm_clinic", "enter": "bgm_clinic",
	"exit": "bgm_clinic", "after": "bgm_clinic", "karte": "bgm_karte",
}


## フェーズに 入った ときの 曲（Sfx.on_phase の あと）。名前だけで なく、その ファイルが 本当に 鳴って いるかも 見る。
## 場面は 場所の 曲（ボスの いる 場面は bgm_boss）。みちの ちず（hop）は 鳴って いる 曲の まま（タイトルの 曲では ない）
func _check_phase_music(p: String, i: int) -> void:
	var where := "%s %s%d" % [Game.episode.get("id", "?"), p, i]
	var want: String = PHASE_WANT.get(p, "")
	if p == "scene" and not Game.episode.is_empty():
		var st := EpisodeDB.scene_stage(Game.episode, i)
		want = "bgm_boss" if _has_boss(st) else String(st.get("bgm", ""))
		if want == "":
			_fail("music: %s の 場所 %s に \"bgm\" が ない" % [where, st.get("id", "?")])
			return
	if p == "hop" and Sfx.bgm_name() in ["", "bgm_title"]:
		_fail("music: %s（みちの ちず）で 曲が「%s」" % [where, Sfx.bgm_name()])
	if want == "" and p != "hop":
		return
	if want != "" and Sfx.bgm_name() != want:
		_fail("music: %s で 曲が %s（%s の はず）" % [where, Sfx.bgm_name(), want])
	_check_playing(want if want != "" else Sfx.bgm_name(), where)


## いまの 音楽の プレーヤーが name の ファイルを 鳴らして いる こと
func _check_playing(name: String, where: String) -> void:
	var m: AudioStreamPlayer = Sfx._music[Sfx._cur]
	var path := Sfx.path_of(name)
	if path == "" or not m.playing or m.stream == null or m.stream.resource_path != path or Sfx._target[Sfx._cur] < 1.0:
		_fail("music: %s で %s が 鳴って いない（%s %s）" % [where, name, m.stream.resource_path if m.stream != null else "なし", "playing" if m.playing else "stopped"])


static func _has_boss(stage: Dictionary) -> bool:
	for m in stage.get("missions", []):
		if m is Dictionary and m.get("type", "") == "boss":
			return true
	return false


## 曲の 切りかえ：消えて いく 曲を また 呼ぶ・カルテから つぎの カルテへ・つづきから みちの ちずへ
func _check_music_changes() -> void:
	var frames := func(n: int):
		for k in n:
			await get_tree().process_frame
	# A → B → A（クロスフェードの とちゅう）：A は 止めて はじめから では なく、消えかけの 位置から もどる
	Sfx.play_bgm("bgm_title")
	await frames.call(40)
	Sfx.play_bgm("bgm_clinic")
	await frames.call(5)
	var a: AudioStreamPlayer = Sfx._music[1 - Sfx._cur]
	var ga: float = Sfx._gain[1 - Sfx._cur]
	Sfx.play_bgm("bgm_title")
	if Sfx._music[Sfx._cur] != a or not a.playing or Sfx._gain[Sfx._cur] != ga or ga <= 0.0:
		_fail("music: A→B→A で 消えかけの A が はじめから に なった（gain %.2f → %.2f）" % [ga, Sfx._gain[Sfx._cur]])
	await frames.call(40)
	_check_playing("bgm_title", "A→B→A")
	# 止めて すぐ 同じ 曲：消えかけの 曲が もどる
	Sfx.stop_bgm()
	await frames.call(5)
	var b: AudioStreamPlayer = Sfx._music[Sfx._cur]
	Sfx.play_bgm("bgm_title")
	if Sfx._music[Sfx._cur] != b or Sfx._gain[Sfx._cur] <= 0.0:
		_fail("music: stop_bgm の あと 同じ 曲で はじめから に なった")
	await frames.call(40)
	# カルテ →「つぎの カルテへ」：カルテの 曲は 止まらず 消えて いく（同じ フレームに 2 回 変えない）
	var ids := EpisodeDB.ids()
	if ids.size() >= 2:
		Game.start_episode(ids[0], "karte")
		await frames.call(40)
		_check_playing("bgm_karte", "karte")
		Game.start_episode(ids[1])
		var out: AudioStreamPlayer = Sfx._music[1 - Sfx._cur]
		if out.stream == null or out.stream.resource_path != Sfx.path_of("bgm_karte") or not out.playing or Sfx._gain[1 - Sfx._cur] < 0.99:
			_fail("music: つぎの カルテへ で カルテの 曲が 止まった（%s）" % (out.stream.resource_path if out.stream != null else "なし"))
		_check_playing("bgm_clinic", "%s consult" % ids[1])
		await frames.call(40)
	# つづきから：あとの はなしが 無い 場面の あとは すぐ みちの ちず。タイトルの 曲に しない
	var n := 0
	for ep in EpisodeDB.EPISODES:
		for i in ep["scenes"].size() - 1:
			if EpisodeDB.after_lines(ep, i, "").is_empty():
				Sfx.play_bgm("bgm_title")    # タイトルや カルテえらびから 入る
				await frames.call(40)
				Game.start_episode(ep["id"], "after", i)
				await frames.call(3)
				n += 1
				if Game.phase != "hop":
					_fail("music: つづきから %s after%d が みちの ちずに ならない（%s）" % [ep["id"], i, Game.phase])
				# 曲の 名前・鳴って いるかは _check_phase_music（hop）が 見る
	_info("music: changes ok, resume to hop %d" % n)
	Game.show_episode_select()
	await frames.call(2)


# ---------------------------------------------------------------- 2. データ
func _check_data() -> void:
	for b in EpisodeDB.validate():
		_fail("data: " + b)
	if Level.SPAWN_LOCKED != EpisodeDB.SPAWN_LOCKED:
		_fail("data: Level.SPAWN_LOCKED と EpisodeDB.SPAWN_LOCKED が ちがう")
	# 文が 箱に 入るか（本物の フォントで はかる）。画面に 出ない えらびの 返事も ここで 見る
	for l in EpisodeDB.OPENING:
		if not TalkScreen.text_fits(l["text"]):
			_fail("OPENING: はなしの 文が ふきだしに 入らない：%s" % l["text"])
	for ep in EpisodeDB.EPISODES:
		var id: String = ep["id"]
		var pages: Array = ep["consult"].duplicate()
		for sc in ep["scenes"]:
			pages += sc.get("after", {}).get("lines", []) + sc.get("after", {}).get("lines_hit", [])
		for l in pages:
			if not TalkScreen.text_fits(l["text"]):
				_fail("%s: はなしの 文が ふきだしに 入らない：%s" % [id, l["text"]])
		if ep.has("guess"):
			for t in [ep["guess"]["q"]] + ep["guess"]["choices"].map(func(c): return c["say"]):
				if not GuessScreen.say_fits(t):
					_fail("%s: よそうの 文が ふきだしに 入らない（%d 行）：%s" % [id, GuessScreen.lines_of(t, GuessScreen.SAY_SIZE, GuessScreen.SAY_WIDTH), t])
			if not GuessScreen.depart_fits(GuessScreen.depart_line(ep)):
				_fail("%s: しゅっぱつの 箱の 文が 入らない" % id)
		# たびの 画面（入口・出口）：ピコの ひとことが ふきだしに 入る。地図の 下の ひとことも 文の きまりを 守る。
		# 道は 入口の 点から さいしょの 場所へ（exit は 出口の 点から さいごの 場所へ）
		for mode in ["enter", "exit"]:
			var jd: Dictionary = EpisodeDB.journey(ep, mode)
			if not JourneyScreen.say_fits(jd["say"]):
				_fail("%s: %s.say が たびの 画面の ふきだしに 入らない（%d 行）：%s" % [id, mode, JourneyScreen.lines_of(jd["say"], JourneyScreen.SAY_SIZE, JourneyScreen.SAY_WIDTH), jd["say"]])
			var want_place: String = ep["scenes"][0 if mode == "enter" else ep["scenes"].size() - 1]["place"]
			var inside: PackedVector2Array = jd["inside"]
			if jd["place"] != want_place or inside.is_empty() or inside[0] != EpisodeDB.map_point(jd["way"].get("at", "")) or inside[inside.size() - 1] != EpisodeDB.ORGAN_POS[want_place]:
				_fail("%s: %s の 道が 入口／出口と 場所「%s」を むすんで いない" % [id, mode, want_place])
			var js := JourneyScreen.new()
			js.setup(ep, mode)
			for c in js.captions():
				for p in EpisodeDB.text_problems(c):
					_fail("%s: たびの 画面の ひとこと「%s」: %s" % [id, c, p])
			js.free()
		# みちの ちず：どの 場面の あいだでも、4 人 どの 患者の 地図でも 入る（はみ出し・ピコの ひとこと・文の きまり）
		for i in range(-1, ep["scenes"].size()):
			var to := EpisodeDB.next_scene(ep, i, i < 0)
			if to < 0 or (i < 0 and not EpisodeDB.has_pass(ep)):
				continue
			for who in EpisodeDB.PATIENTS.keys():
				var e: Dictionary = ep.duplicate(true)
				e["patient"] = who
				var hs := HopScreen.new()
				hs.setup(e, i, to)
				hs.theme = Game.theme
				add_child(hs)
				if not hs.fits():
					_fail("%s hop%d（%s の 地図）: %s" % [id, i, who, hs.overflow()])
				for p in EpisodeDB.text_problems(hs.say_text):
					_fail("%s hop%d: ピコの ひとこと「%s」: %s" % [id, i, hs.say_text, p])
				if not HopScreen.say_fits(hs.say_text):
					_fail("%s hop%d: ピコの ひとことが ふきだしに 入らない：%s" % [id, i, hs.say_text])
				hs.free()
		# HUD の 題：だれの からだか（患者の 名前 ＋ 場所）。1 行で 入る
		for i in ep["scenes"].size():
			var title := HudScreen.title_text(EpisodeDB.scene_stage(ep, i))
			if not title.begins_with(EpisodeDB.speaker(ep["patient"])["name"] + "の "):
				_fail("%s scene %d: HUD の 題に 患者の 名前が ない：%s" % [id, i, title])
			if not HudScreen.title_fits(title):
				_fail("%s scene %d: HUD の 題が 入らない：%s" % [id, i, title])
			for p in EpisodeDB.text_problems(title):
				_fail("%s scene %d: HUD の 題「%s」: %s" % [id, i, title, p])
		# あたりの よそう（hit）には lines_hit、それ以外には lines が 出る
		for i in ep["scenes"].size():
			var a: Dictionary = ep["scenes"][i].get("after", {})
			if a.has("lines_hit"):
				for c in ep.get("guess", {}).get("choices", []):
					var want: Array = a["lines_hit"] if c.get("hit", false) else a["lines"]
					if EpisodeDB.after_lines(ep, i, c["place"]) != want:
						_fail("%s: after_lines が ちがう（%s）" % [id, c["place"]])
				if EpisodeDB.after_lines(ep, i, "") != a["lines"]:
					_fail("%s: よそうが 無い ときの after_lines が lines で ない" % id)
	# どの 患者 × どの 場所でも 題が 入る（あとで 足す 話の ため）。場所だけの とき（テスト）は 名前だけ
	for who in EpisodeDB.PATIENTS.keys():
		for pid in StageDB.stage_ids():
			var st := StageDB.get_stage(pid)
			var t := "%sの %s（%s）" % [EpisodeDB.PATIENTS[who]["name"], st["name"], st["kanji"]]
			if not HudScreen.title_fits(t):
				_fail("HUD の 題が 入らない：%s" % t)
	var plain := StageDB.get_stage("mouth")
	if HudScreen.title_text(plain) != "%s（%s）" % [plain["name"], plain["kanji"]]:
		_fail("HUD の 題：場所だけの ときは 場所の 名前だけ（%s）" % HudScreen.title_text(plain))
	_info("episodes: %d, places: %d" % [EpisodeDB.EPISODES.size(), StageDB.STAGES.size()])


## 入口・出口の データが 無い／知らない／古い 書きかたの 話を、validate_episode() が わかる 文で 止める
## （こわした 写しで 見る。本物の データは _check_data の validate() が 見る）
func _check_journey_rules() -> void:
	var ep: Dictionary = EpisodeDB.EPISODES[0]
	var cases := [
		["enter", "erase", "enter が ない"],
		["exit", "erase", "exit が ない"],
		["enter", "rocket", "enter.way「rocket」を 知らない"],
		["exit", "rocket", "exit.way「rocket」を 知らない"],
	]
	for c in cases:
		var bad_ep: Dictionary = ep.duplicate(true)
		if c[1] == "erase":
			bad_ep.erase(c[0])
		else:
			bad_ep[c[0]]["way"] = c[1]
		var msgs := EpisodeDB.validate_episode(bad_ep, 1)
		if not msgs.any(func(m: String): return m.contains(c[2])):
			_fail("journey rules: %s を こわしても「%s」と 言わない：%s" % [c[0], c[2], msgs])
	# 前の 書きかた（guess.depart・karte.exit）は 2 回 出る もとに なるので 止める
	var old: Dictionary = ep.duplicate(true)
	old["guess"]["depart"] = "はっしん！"
	old["karte"]["exit"] = "ぽーん！"
	var msgs := EpisodeDB.validate_episode(old, 1)
	if not msgs.any(func(m: String): return m.contains("guess.depart")) or not msgs.any(func(m: String): return m.contains("karte.exit")):
		_fail("journey rules: guess.depart／karte.exit を 止めない：%s" % [msgs])
	if not EpisodeDB.validate_episode(ep, 1).is_empty():
		_fail("journey rules: 本物の ep01 で まちがいが 出る")


## みちの きまり と とおりみちの 書きかた（こわした 写しで 見る）
func _check_route_rules() -> void:
	var ep2: Dictionary = EpisodeDB.get_episode("ep02")
	var ep3: Dictionary = EpisodeDB.get_episode("ep03")
	# 入口から しょくどうへ とぶ（くちを とばす）
	var no_mouth: Dictionary = ep2.duplicate(true)
	no_mouth["scenes"].remove_at(0)
	var msgs := EpisodeDB.validate_episode(no_mouth, 2)
	if not msgs.has("ep02: みちの とちゅうの「mouth」が scenes に ない"):
		_fail("route rules: ep02 から くちを ぬいても「mouth」と 言わない：%s" % [msgs])
	# くちから い（胃）へ とぶ（しょくどうを とばす）
	var no_eso: Dictionary = ep3.duplicate(true)
	no_eso["scenes"].remove_at(1)
	msgs = EpisodeDB.validate_episode(no_eso, 3)
	if not msgs.has("ep03: みちの とちゅうの「esophagus」が scenes に ない"):
		_fail("route rules: ep03 から しょくどうを ぬいても「esophagus」と 言わない：%s" % [msgs])
	# じゅんばんが ちがう（くち・い・しょくどう・ちょう）：「ない」では なく「じゅんばんが ちがう」
	var swapped: Dictionary = ep3.duplicate(true)
	var eso = swapped["scenes"][1]
	swapped["scenes"].remove_at(1)
	swapped["scenes"].insert(2, eso)
	msgs = EpisodeDB.validate_episode(swapped, 3)
	if not msgs.any(func(m: String): return m.contains("「esophagus」の じゅんばんが ちがう")) or msgs.any(func(m: String): return m.contains("scenes に ない")):
		_fail("route rules: じゅんばんちがいを「じゅんばんが ちがう」と 言わない：%s" % [msgs])
	# かたまり（lumps）を なみの ない 場所（い（胃））に 書いた：まちがいと 言う
	var lumps_sto: Dictionary = ep2.duplicate(true)
	lumps_sto["scenes"][2]["lumps"] = 3
	msgs = EpisodeDB.validate_episode(lumps_sto, 2)
	if not msgs.any(func(m: String): return m.contains("lumps は なみ")):
		_fail("route rules: なみの ない 場所の lumps を 言わない：%s" % [msgs])
	# pass が bool で ない：型の エラーに ならず、きまりの 文だけ（ふつうの 場面と みなす）
	var str_pass: Dictionary = ep2.duplicate(true)
	str_pass["scenes"][0]["pass"] = "yes"
	if EpisodeDB.is_pass(str_pass, 0):
		_fail("route rules: pass が \"yes\" で とおりみちに なった")
	msgs = EpisodeDB.validate_episode(str_pass, 2)
	if not msgs.any(func(m: String): return m.contains("pass は true か false")):
		_fail("route rules: pass が bool で ないのを 言わない：%s" % [msgs])
	# とおりみちに missions／after、さいごの 場面が とおりみち、say が ない
	var bad: Dictionary = ep2.duplicate(true)
	bad["scenes"][0]["missions"] = [{"type": "reach", "text": "ゴールへ いこう"}]
	bad["scenes"][0]["after"] = {"banner": "はっけん", "lines": [{"who": "pico", "text": "くちだよ。"}]}
	bad["scenes"][0].erase("say")
	bad["scenes"][2]["pass"] = true
	msgs = EpisodeDB.validate_episode(bad, 2)
	for want in ["pass）には missions を 書かない", "pass）には after を 書かない", "scene 0 say: 文が 空", "さいごの 場面は とおりみち"]:
		if not msgs.any(func(m: String): return m.contains(want)):
			_fail("route rules: 「%s」と 言わない：%s" % [want, msgs])
	# 場面の 数：ぜんぶで 5 こ、とおりみちで ない 場面は 3 こまで
	var many: Dictionary = ep3.duplicate(true)
	many["scenes"][0].erase("pass")
	many["scenes"][1].erase("pass")
	msgs = EpisodeDB.validate_episode(many, 3)
	if not msgs.any(func(m: String): return m.contains("とおりみちで ない 場面は 3 こまで")):
		_fail("route rules: ふつうの 場面が 4 こでも 止めない：%s" % [msgs])
	for e in [ep2, ep3]:
		if not EpisodeDB.validate_episode(e, int(e["no"])).is_empty():
			_fail("route rules: 本物の %s で まちがいが 出る" % e["id"])
	# 道の 名前の 列
	if EpisodeDB.route_keys("mouth", "stomach") != ["mouth", "throat", "esophagus", "stomach"]:
		_fail("route rules: route_keys(mouth, stomach) が ちがう：%s" % [EpisodeDB.route_keys("mouth", "stomach")])
	# 話の とおる 場所
	if EpisodeDB.stops(ep2) != ["mouth", "esophagus", "stomach"] or EpisodeDB.stops(ep3) != ["mouth", "esophagus", "stomach", "intestine"] or EpisodeDB.stops(EpisodeDB.get_episode("ep01")) != ["mouth"]:
		_fail("route rules: 1〜3 話の とおる 場所が ちがう")


## spawn の ルール（skip／swap）の 読みかえ。番号は のこる。かえられない マーカーは そのまま
func _check_spawn_rules() -> void:
	var rules := {
		"skip": ["enemy_pylori_4", "card_acid", "pickup_nutrient_1", "goal"],
		"swap": {"friend_rbc_2": "friend_wbc", "friend_zendama": "friend_wbc", "boss_boss_virus": "boss_boss_haien", "player": "enemy_virus"},
	}
	var cases := {
		"MK_enemy_pylori_4": "",                         # ぴったり 同じ
		"MK_enemy_pylori_40": "MK_enemy_pylori_40",      # 「_」の さかいを 見る（4 は 40 に 合わない）
		"MK_enemy_pylori_1": "MK_enemy_pylori_1",
		"MK_card_acid": "",
		"MK_pickup_nutrient_1_2": "",                    # えいようは「しゅるい_通し番号」。しゅるい 1 が 消える
		"MK_pickup_nutrient_0_1": "MK_pickup_nutrient_0_1",
		"MK_friend_rbc_2": "MK_friend_wbc_2",            # ぴったり 同じでも 番号は のこる
		"MK_friend_rbc_3": "MK_friend_rbc_3",
		"MK_friend_zendama_3": "MK_friend_wbc_3",        # 前方一致：のこりの 番号は そのまま
		"MK_boss_boss_virus": "MK_boss_boss_haien",      # 番号の 無い マーカー
		"MK_goal": "MK_goal",                            # かえられない
		"MK_player": "MK_player",
		"MK_checkpoint_1": "MK_checkpoint_1",
	}
	var used := {}
	for mk in cases.keys():
		var got := Level._apply_spawn_rules(mk, rules, used)
		if got != cases[mk]:
			_fail("spawn rules: %s -> 「%s」（「%s」の はず）" % [mk, got, cases[mk]])
	if used.has("goal") or used.has("player") or not used.has("friend_rbc_2") or not used.has("card_acid"):
		_fail("spawn rules: 使った ルールの 記録が ちがう：%s" % [used.keys()])
	if Level._apply_spawn_rules("MK_enemy_pylori_4", {}, used) != "MK_enemy_pylori_4":
		_fail("spawn rules: ルールが 無い とき 名前が 変わった")


## カルテの 紙が 入るか（カルテ画面と ずかんの ポップアップが 同じ 紙を 使う）。
## 挿絵（cards/card_<ep>_karte.png）が 届いた ときの 形（文の 幅が せまく なる）も 先に はかる
func _check_sheets() -> void:
	for ep in EpisodeDB.EPISODES:
		var hs: Array[float] = []
		for with_pic in [false, true]:
			var sh := KarteSheet.build(ep, with_pic)
			sh.theme = Game.theme
			add_child(sh)
			await get_tree().process_frame
			await get_tree().process_frame
			hs.append(sh.get_combined_minimum_size().y)
			if hs[-1] > KarteSheet.MAX_HEIGHT:
				_fail("%s: カルテの 紙が 高すぎる（%.0f px。%.0f まで。挿絵 %s）" % [ep["id"], hs[-1], KarteSheet.MAX_HEIGHT, "あり" if with_pic else "なし"])
			sh.queue_free()
		_info("karte sheet %s: %.0f px (with picture %.0f px)" % [ep["id"], hs[0], hs[1]])


## 人物の 絵の 口（T.portrait）：絵が ある 人は 絵、無い 人は コードで 描く 仮の 顔。どちらも 言われた 大きさで 返る。
## 1〜3 話で 両方の 道を 通る こと（はなちゃん・ピコ ＝ 絵、絵の 無い 患者 ＝ 仮の 顔）も 見る
func _check_portraits() -> void:
	var with_art := 0
	var drawn := 0
	var whos: Array = EpisodeDB.PATIENTS.keys() + ["pico"]
	for who in whos:
		var col: Color = EpisodeDB.speaker(who)["color"]
		for mood in ["sick", "happy", "normal"]:
			for full in [false, true]:
				var size := Vector2(300, 400) if full else Vector2(76, 76)
				var c := T.portrait(who, mood, size, col, full)
				if c == null or c.custom_minimum_size != size:
					_fail("portrait: %s %s の 大きさが ちがう" % [who, mood])
				elif (c is TextureRect) != (T.has_portrait_art(who, mood) or who == "pico" or (full and T.art("%s_fullbody_%s" % [who, mood]) != null)):
					_fail("portrait: %s %s の 絵の えらびかたが ちがう" % [who, mood])
				if c != null:
					c.free()
	for ep in EpisodeDB.EPISODES:
		for mood in ["sick", "happy"]:
			if T.has_portrait_art(ep["patient"], mood):
				with_art += 1
			else:
				drawn += 1
	if with_art == 0 or drawn == 0:
		_info("portrait: 1〜3 話が 絵と 仮の 顔の 片方しか 通らない（絵 %d・仮 %d）" % [with_art, drawn])
	# ことばの 途中で 折らない しるしは、文の 検査には 見えない（画面の 文も データと 同じ きまりで 調べられる）
	var sample := "い（胃）の かべに ピロリきんが いるよ。"
	if T.nobreak(sample).replace(T.WJ, "") != sample or not EpisodeDB.text_problems(T.nobreak(sample)).is_empty() or EpisodeDB.text_problems(T.nobreak("いが いたい")).is_empty():
		_fail("nobreak: 文の 検査が 折りかえしの しるしで くるう")


# ---------------------------------------------------------------- 3. セーブ
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
	if SaveData.data["version"] != SaveData.VERSION or SaveData.total_stars() != 0 or SaveData.is_cleared("ep01") or not SaveData.card_seen("mouth", "stage") or SaveData.setting("volume") != 0.5 or SaveData.setting("touch") != "on" or SaveData.data["cards_seen"].size() != 2:
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
		var hs := SaveData.heart_scenes(ep2)
		SaveData.record_clear(ep2)
		SaveData.record_scene(ep2, hs[hs.size() - 1], true)
		if SaveData.star_flags(ep2) != [true, false, false]:
			_fail("save: 場面が 1 つ まだなのに ハートの ほし")
		# とおりみちは ハートの ほしに 入らない（へっても へらなくても かわらない）
		for i in EpisodeDB.scene_count(ep2):
			if EpisodeDB.is_pass(EpisodeDB.get_episode(ep2), i):
				SaveData.record_scene(ep2, i, false)
		for i in hs:
			SaveData.record_scene(ep2, i, true)
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
	_check_save_v2()
	_info("save checks done")


## v2 の セーブ（とおりみちを 入れる 前：ep02 は しょくどう・い、ep03 は い・ちょう）を 読む。
## ハートの 印は 場所に 読みかえ（とって いない ほしは つかない）、つづきは いまの 場面の 番号に（ある 場面に 入る）
func _check_save_v2() -> void:
	SaveData.reset()
	var old := {"version": 2, "opening_seen": true, "cards_seen": ["mouth/stage"],
		"episodes": {
			"ep01": {"clear": true, "quiz": true, "nd": [true]},
			"ep02": {"clear": true, "quiz": false, "nd": [true, true]},
			"ep03": {"clear": true, "quiz": true, "nd": [false, true, true, true]},
		},
		"resume": {"ep": "ep03", "cleared": 1, "guess": "intestine"}}
	_write(JSON.stringify(old))
	SaveData.load_data()
	var where := "save v2"
	if SaveData.data["version"] != SaveData.VERSION or not FileAccess.file_exists("user://save_test.v2.json"):
		_fail("%s: 版が %s のまま、または 元の ファイルが のこって いない" % [where, SaveData.data["version"]])
	if SaveData.star_flags("ep01") != [true, true, true]:
		_fail("%s: ep01 の ほしが ちがう：%s" % [where, SaveData.star_flags("ep01")])
	if SaveData.star_flags("ep02") != [true, true, false]:
		_fail("%s: ep02（しょくどう・い とも ハート そのまま）の ほしが ちがう：%s" % [where, SaveData.star_flags("ep02")])
	# ep03 の v2 は 場面 2 つ（い・ちょう）。い（胃）で ハートが へった → ほしは つかない（よぶんな 印は すてる）
	if SaveData.star_flags("ep03") != [true, false, true]:
		_fail("%s: ep03 に とって いない ハートの ほしが ついた：%s" % [where, SaveData.star_flags("ep03")])
	var r := SaveData.resume()
	var ep3 := EpisodeDB.get_episode("ep03")
	if r.get("ep", "") != "ep03" or int(r.get("cleared", 0)) < 1 or int(r["cleared"]) > ep3["scenes"].size() or ep3["scenes"][int(r["cleared"]) - 1]["place"] != "stomach":
		_fail("%s: ep03 の つづき（い（胃）まで おえた）が いまの 場面に ならない：%s" % [where, r])
	# 読みなおしても 同じ（v3 で 書きなおされて いる）
	SaveData.load_data()
	if SaveData.star_flags("ep02") != [true, true, false] or SaveData.star_flags("ep03") != [true, false, true] or SaveData.resume().get("cleared", 0) != r.get("cleared", -1):
		_fail("%s: 書きなおした あとで かわった：%s" % [where, SaveData.data])
	# つづき：ep02 の 場面 2（い）まで → いまの さいごの 場面。数が 合わない つづきは すてる
	for c in [[{"ep": "ep02", "cleared": 2}, "stomach"], [{"ep": "ep02", "cleared": 3}, ""], [{"ep": "ep03", "cleared": 0}, ""], [{"ep": "ep09", "cleared": 1}, ""]]:
		_write(JSON.stringify({"version": 2, "resume": c[0]}))
		SaveData.load_data()
		var rr := SaveData.resume()
		if c[1] == "" and not rr.is_empty():
			_fail("%s: 合わない つづきが のこった：%s → %s" % [where, c[0], rr])
		if c[1] != "":
			var e := EpisodeDB.get_episode(c[0]["ep"])
			if rr.is_empty() or e["scenes"][int(rr["cleared"]) - 1]["place"] != c[1]:
				_fail("%s: つづき %s が %s に ならない：%s" % [where, c[0], c[1], rr])
	# v2 の nd が こわれて いても ほしは つかない
	_write('{"version":2,"episodes":{"ep02":{"clear":true,"nd":{"a":1}},"ep03":{"clear":true,"nd":"x"}}}')
	SaveData.load_data()
	if SaveData.star_flags("ep02")[1] or SaveData.star_flags("ep03")[1]:
		_fail("%s: こわれた nd で ハートの ほしが ついた" % where)
	# つづきから：v2 の つづき（ep02 の しょくどうまで）で、つづきから が ある 場面に 入る
	SaveData.reset()
	_write(JSON.stringify({"version": 2, "episodes": {"ep01": {"clear": true}}, "resume": {"ep": "ep02", "cleared": 1, "guess": "stomach"}}))
	SaveData.load_data()
	r = SaveData.resume()
	var ep2 := EpisodeDB.get_episode("ep02")
	if r.is_empty() or ep2["scenes"][int(r["cleared"]) - 1]["place"] != "esophagus":
		_fail("%s: ep02 の つづきが しょくどうの あとに ならない：%s" % [where, r])
	# 同じ 場所を 2 回 使う 話（5 話の はな → はい → はな）：場面の キーが 分かれ、つづきも ハートの 印も まざらない
	var dup := {"id": "ep05", "scenes": [{"place": "nose"}, {"place": "lungs"}, {"place": "nose"}]}
	var keys := []
	for i in 3:
		keys.append(SaveData.scene_key(dup, i))
	if keys != ["nose", "lungs", "nose#1"]:
		_fail("%s: 同じ 場所の 場面の キーが 分かれない：%s" % [where, keys])
	for c in [["nose", 1], ["lungs", 2], ["nose#1", 3]]:
		if SaveData._resume_index(dup, 1, c[0], SaveData.VERSION) != c[1]:
			_fail("%s: 同じ 場所が 2 回 ある 話の つづき「%s」が 場面 %d の あとに ならない（%d）" % [where, c[0], c[1], SaveData._resume_index(dup, 1, c[0], SaveData.VERSION)])
	# v3 の つづきは キーで 読みなおせる
	SaveData.reset()
	SaveData.set_resume("ep03", 2, "stomach")
	SaveData.load_data()
	if SaveData.resume().get("cleared", 0) != 2 or SaveData.resume().get("key", "") != "esophagus":
		_fail("%s: v3 の つづきが 読みなおせない：%s" % [where, SaveData.resume()])
	SaveData.reset()


# ---------------------------------------------------------------- 4. カルテ
func _expected_phases(ep: Dictionary) -> Array[String]:
	var out: Array[String] = ["consult"]
	if ep.has("guess"):
		out.append("guess")
	out.append("enter")
	for i in ep["scenes"].size():
		out.append("scene%d" % i)
		if ep["scenes"][i].has("after"):
			out.append("after%d" % i)
		if i + 1 < ep["scenes"].size():
			out.append("hop%d" % i)    # みちの ちず（場面と 場面の あいだ）
	out.append("exit")
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


## root の 下に 出ている 文（ラベルと ボタン）を 文の きまりで 調べる。画面の 決まり文句も ここで 守られる
func _check_texts(root: Control, where: String) -> void:
	for n in root.find_children("*", "Control", true, false):
		if (n is Label or n is Button) and n.is_visible_in_tree() and n.text != "" and not _text_seen.has(n.text):
			_text_seen[n.text] = true
			for p in EpisodeDB.text_problems(n.text):
				_fail("%s: 画面の 文「%s」: %s" % [where, n.text, p])


## root の 下の、見えている ラベルと ボタンが 画面（1280×720）の 中に あり、文が 切れて いないか。
## ボタンは 指で 押せる 大きさ（高さ 56 px 以上）か。スクロールの 中は 見ない（外に 出て いて よい）
func _check_layout(root: Control, where: String) -> void:
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(1.0)
	for n in root.find_children("*", "Control", true, false):
		if not (n is Label or n is BaseButton) or not n.is_visible_in_tree():
			continue
		var in_scroll := false
		var p: Node = n.get_parent()
		while p != null and p != root:
			if p is ScrollContainer:
				in_scroll = true
			p = p.get_parent()
		if in_scroll:
			continue
		var what: String = String(n.text).replace(T.WJ, "").left(16) if n.text != "" else String(n.name)
		var r: Rect2 = n.get_global_rect()
		if not view.encloses(r):
			_fail("%s: 「%s」が 画面の 外に 出て いる（%s）" % [where, what, r])
		if n is Label and n.autowrap_mode != TextServer.AUTOWRAP_OFF and n.get_visible_line_count() < n.get_line_count():
			_fail("%s: 「%s」の 文が 切れて いる（%d 行の うち %d 行だけ）" % [where, what, n.get_line_count(), n.get_visible_line_count()])
		if n is Button and not n.disabled and n.size.y < 56.0:
			_fail("%s: ボタン「%s」が 小さい（高さ %.0f px）" % [where, what, n.size.y])


## 画面の 文と、はみ出し（fits() が ある 画面）を 調べる
func _check_screen(scr: Control, where: String) -> void:
	_check_texts(scr, where)
	_check_layout(scr, where)
	if scr.has_method("fits") and not scr.fits():
		_fail("%s: 中身が 箱から はみ出して いる%s" % [where, ("：" + scr.overflow()) if scr.has_method("overflow") else ""])


## HUD に 文が 出た：場面ごとに ためる。カルテの 場面では 文の きまりも 見る（Level や てきの 決まり文句も）
func _on_said(t: String) -> void:
	_said.append([Engine.get_physics_frames(), t])
	if not Game.episode.is_empty() and not _text_seen.has(t):
		_text_seen[t] = true
		for p in EpisodeDB.text_problems(t):
			_fail("%s scene %d: HUD の 文「%s」: %s" % [Game.episode["id"], Game.scene_index, t, p])


## 場面が おわった とき：intro・each_say・goal_say・clear_say が HUD に 出たか。
## goal_say が 出てから 2 秒の うちに、ほかの 文（えいようを とどけた！・チェックポイント！）に 上書きされて いないか
func _check_says() -> void:
	var sc: Dictionary = EpisodeDB.scene_stage(Game.episode, Game.scene_index)   # とおりみちの 文は ここで 作られる
	var where := "%s scene %d" % [Game.episode["id"], Game.scene_index]
	var texts: Array = _said.map(func(e): return e[1])
	var want: Array = [sc["intro"]]
	var has_work: bool = sc["missions"].size() > 1
	for m in sc["missions"]:
		var each: Array = m.get("each_say", [])
		for i in mini(each.size(), int(m.get("count", 1)) - 1):
			want.append(each[i])
	if has_work and sc.has("goal_say"):
		want.append(sc["goal_say"])
	if sc.has("clear_say"):
		want.append(sc["clear_say"])
	for t in want:
		# clear_say は うしろに ことばが つく ことが ある（しょくどう：「なみに のって ○ センチ すすんだよ！」）
		if not texts.has(t) and not (t == sc.get("clear_say", "") and texts.any(func(x: String): return x.begins_with(t))):
			_fail("%s: HUD に 出なかった：%s" % [where, t])
	if has_work and sc.has("goal_say"):
		var i := texts.find(sc["goal_say"])
		var j := i + 1
		while i >= 0 and j < _said.size() and _said[j][0] - _said[i][0] < HOLD_FRAMES:
			if not String(_said[j][1]).begins_with(sc.get("clear_say", "クリア！")):
				_fail("%s: goal_say が すぐ 上書きされた：%s" % [where, _said[j][1]])
			j += 1


func _mission_state(lvl) -> String:
	var parts: Array[String] = []
	for m in lvl.missions:
		parts.append("%s:%d/%d%s" % [m.type, m.current, m.count, "✓" if m.done else ""])
	return ", ".join(parts)


func _run_episode(id: String) -> void:
	_info("=== episode %s ===" % id)
	var ep := EpisodeDB.get_episode(id)
	var t0 := Time.get_ticks_msec()
	_ep_done = false
	_phases.clear()
	_scene_clears = 0
	_found_now.clear()
	# id だけを 回す とき（--episode=）は、前の 話を クリアずみに して おく（カルテえらびが id を えらぶ ように）
	for prev in EpisodeDB.ids():
		if prev == id:
			break
		if not SaveData.is_cleared(prev):
			SaveData.record_clear(prev)
	Game.show_episode_select()
	var total := 0.0
	var idle := 0.0          # いまの フェーズに 入ってからの 時間
	var seen_phases := 0
	var nofocus := 0
	var select_done := false
	var wrong_done := false
	var checked_level = null
	var journeys_seen := {}
	var hops_seen: Array[String] = []
	var pass_t := 0.0          # いまの とおりみちの 場面の 時間
	# クイズは 話ごとに 正解・はずれを かわるがわる えらぶ（「せいかい！」も「おしい！」も 毎回 通る。ほしの 数も 毎回 同じ）
	var quiz_right: bool = EpisodeDB.ids().find(id) % 2 == 0
	var quiz_before: bool = SaveData.star_flags(id)[2]
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
				# HUD の 題は だれの からだか（患者の 名前 ＋ 場所）
				var title: String = Game.hud.title_label().text if Game.hud != null else ""
				if title != HudScreen.title_text(lvl.stage) or not title.begins_with(EpisodeDB.speaker(ep["patient"])["name"]):
					_fail("%s scene %d: HUD の 題が「%s」（患者の 名前が ない）" % [id, Game.scene_index, title])
				for p in lvl.stage.get("spawn", {}).get("skip", []):
					for m in lvl.markers:
						if m["node"] != null and Level.spawn_rule_matches(String(m["node"].name).substr(3), p):
							_fail("%s: skip が きいていない: %s" % [id, m["node"].name])
				pass_t = 0.0
				if lvl.is_pass():
					_check_pass_level(lvl, "%s scene %d" % [id, Game.scene_index])
			_watch_cards(lvl, "%s scene %d" % [id, Game.scene_index])
			if lvl.started and not lvl.finished:
				Autopilot.drive(lvl, get_tree())
				if lvl.is_pass():
					pass_t += dt
					if lvl.damage_taken:
						_fail("%s scene %d: とおりみちで ハートが へった" % [id, Game.scene_index])
			elif lvl.finished and lvl.is_pass():
				var key := "%s scene %d (%s)" % [id, Game.scene_index, lvl.stage_id]
				if not _pass_times.has(key):
					_pass_times[key] = pass_t
					if pass_t > MAX_PASS_SECONDS:
						_fail("%s: とおりみちが 長い（%.1f 秒。%.0f 秒まで）" % [key, pass_t, MAX_PASS_SECONDS])
					elif pass_t < MIN_PASS_SECONDS:
						_fail("%s: とおりみちが みじかすぎる（%.1f 秒。%.0f 秒 いじょう）" % [key, pass_t, MIN_PASS_SECONDS])
			if idle > MAX_SCENE_SECONDS:
				_fail("%s: scene %d (%s) did not finish in %.0fs; missions: %s" % [id, Game.scene_index, lvl.stage_id, MAX_SCENE_SECONDS, _mission_state(lvl)])
				break
			continue
		var scr := Game.screen()
		if idle > MAX_UI_SECONDS:
			_fail("%s: stuck on %s for %.0fs" % [id, Game.phase, MAX_UI_SECONDS])
			break
		if scr == null or not scr.has_method("locked") or scr.locked():
			continue
		var where: String = Game.phase if Game.phase != "" else "カルテえらび"
		var fo := _focused_button(scr)
		if fo == null:
			nofocus += 1
			if nofocus == 30:
				_fail("%s: %s の 画面で フォーカスが ボタンに ない" % [id, where])
			continue
		nofocus = 0
		_check_screen(scr, "%s %s" % [id, where])
		_check_no_dup(scr, ep, "%s %s" % [id, where])
		if scr is JourneyScreen and not journeys_seen.has(scr.mode):
			journeys_seen[scr.mode] = true
			_check_journey_screen(scr, ep)
		if scr is CardsScreen and scr.focus_target == scr.button:
			_check_cards_found(scr, fo, "%s cards%d" % [id, Game.scene_index])
		if scr is HopScreen and not hops_seen.has("%d" % scr.from):
			hops_seen.append("%d" % scr.from)
			_check_hop_screen(scr, ep, false)
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
		if scr is KarteScreen and scr.step == 2:
			var pick: int = scr.quiz_answer if quiz_right else (scr.quiz_answer + 1) % scr.quiz_buttons.size()
			scr.quiz_buttons[pick].pressed.emit()
			continue
		fo.pressed.emit()
	var expect := _expected_phases(ep)
	for m in ["enter", "exit"]:
		if not journeys_seen.has(m):
			_fail("%s: たびの 画面（%s）が 出なかった" % [id, m])
	if hops_seen.size() != ep["scenes"].size() - 1:
		_fail("%s: みちの ちずが 場面の あいだ ごとに 出ない（%s）" % [id, hops_seen])
	if _ep_done:
		_info("cleared %s in %.1fs (sim) / %.1fs (real); scenes=%d stars=%d" % [id, total, (Time.get_ticks_msec() - t0) / 1000.0, _scene_clears, SaveData.stars(id)])
		# 「みつけた ものしりカード」は セーブ しだい（はじめて みつけた ときだけ）。ここでは のぞいて くらべ、出る・出ないは _check_cards_phase が 見る
		var got := _phases_at_end.filter(func(p): return p != "cards")
		if got != expect:
			_fail("%s: phases %s != %s" % [id, got, expect])
		if _scene_clears != ep["scenes"].size():
			_fail("%s: %d scenes cleared, expected %d" % [id, _scene_clears, ep["scenes"].size()])
		if not SaveData.is_cleared(id) or SaveData.stars(id) < 1 or not SaveData.card_seen(id, "karte") or not SaveData.resume().is_empty():
			_fail("%s: clear／karte が 記録されていない、または つづきが 残っている" % id)
		if SaveData.star_flags(id)[2] != (quiz_before or quiz_right):
			_fail("%s: クイズの ほしが ちがう（%s を えらんだ）" % [id, "正解" if quiz_right else "はずれ"])
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


## たびの 画面：この 話の 患者・入口／出口・道・ピコの ひとこと。ボタンに フォーカス
func _check_journey_screen(scr, ep: Dictionary) -> void:
	var id: String = ep["id"]
	var mode: String = scr.mode
	var where := "%s %s" % [id, mode]
	if mode != Game.phase or scr.ep["id"] != id:
		_fail("%s: たびの 画面の 形が ちがう（%s／%s）" % [where, mode, Game.phase])
		return
	var ways: Dictionary = EpisodeDB.ENTRANCES if mode == "enter" else EpisodeDB.EXITS
	var way_id: String = ep.get(mode, {}).get("way", "")
	if not ways.has(way_id):
		return   # データの まちがいは validate() が 知らせる（画面は こわれずに 出る）
	if scr.j["way"] != ways[way_id]:
		_fail("%s: 入口／出口が データと ちがう" % where)
	var place: String = ep["scenes"][0 if mode == "enter" else ep["scenes"].size() - 1]["place"]
	var pts: PackedVector2Array = scr.path_points()
	var outside: Vector2 = scr._map.to_local_pos(ways[way_id]["out"][-1])
	var inner: Vector2 = scr._map.point(place)
	var first := pts[0]
	var last := pts[pts.size() - 1]
	if mode == "enter" and (first.distance_to(outside) > 1.0 or last.distance_to(inner) > 1.0):
		_fail("%s: ミクロごうが 外 → %s に 行かない（%s → %s）" % [where, place, first, last])
	if mode == "exit" and (first.distance_to(inner) > 1.0 or last.distance_to(outside) > 1.0):
		_fail("%s: ミクロごうが %s → 外 に 行かない（%s → %s）" % [where, place, first, last])
	var texts: Array = scr.find_children("*", "Label", true, false).filter(func(l): return l.is_visible_in_tree()).map(func(l): return String(l.text).replace(T.WJ, ""))
	for want in [ep[mode].get("say", ""), EpisodeDB.speaker(ep["patient"])["name"]]:
		if not texts.has(want):
			_fail("%s: 画面に「%s」が ない" % [where, want])
	if get_viewport().gui_get_focus_owner() != scr.button:
		_fail("%s: ボタンに フォーカスが ない" % where)
	if Game.touch_controls != null and is_instance_valid(Game.touch_controls) and Game.touch_controls.visible:
		_fail("%s: タッチの ボタンが 画面の 上に のこって いる" % where)
	# exit：とおった みち（入口から さいごの 場所まで の 場所の ならび）
	if mode == "exit" and (scr.route == null or scr.route.places != EpisodeDB.stops(ep) or not scr.route.done or not texts.has("とおった みち")):
		_fail("%s: 出口の 画面に とおった みちが ない" % where)
	# enter：とおりみちを とばす は クリアずみで とおりみちが ある 話だけ（はじめて 遊ぶ ときは 出ない）
	if mode == "enter" and (scr.skip_button != null) != (SaveData.is_cleared(id) and EpisodeDB.has_pass(ep)):
		_fail("%s: 「とおりみちを とばす」の 出かたが ちがう" % where)


## とおりみちの Level：てき・ボス・いけ・ドア・しんけい・なかま・ミッションの ひろいものが 出ない。ミッションは ゴールだけ、ゴールは はじめから 開く
func _check_pass_level(lvl, where: String) -> void:
	for m in lvl.markers:
		var kind: String = m["kind"]
		if not Level.PASS_KEEP.has(kind) and not (kind == "pickup" and Level._kind_and_index(m["rest"], "")["kind"] == "heart_item"):
			_fail("%s: とおりみちに %s が 出る" % [where, m["name"]])
	for c in lvl.get_children():
		if c is Enemy or c is Boss or c is HazardPool or c is ValveGate or c is Neuron or c is Friend or c is DeliverZone or (c is Pickup and c.get("kind") != "heart_item"):
			_fail("%s: とおりみちに %s が いる" % [where, c.name])
	if lvl.missions.size() != 1 or not lvl.missions[0].is_reach():
		_fail("%s: とおりみちの ミッションが ゴールだけで ない（%s）" % [where, _mission_state(lvl)])
	if lvl.goal == null or lvl.goal.locked:
		_fail("%s: とおりみちの ゴールが はじめから 開いて いない" % where)
	if not lvl.data_warnings.is_empty():
		_fail("%s: %s" % [where, lvl.data_warnings])


## みちの ちず：from（おえた 場面）から to（つぎの 場面）へ。いま ここ／つぎは ここ・とおる 場所の ならび・ピコの ひとこと
func _check_hop_screen(scr, ep: Dictionary, skipping: bool) -> void:
	var id: String = ep["id"]
	var where := "%s hop%d" % [id, scr.from]
	var want_to := EpisodeDB.next_scene(ep, scr.from, skipping)
	if scr.to != want_to or Game.phase != "hop" or scr.ep["id"] != id:
		_fail("%s: みちの ちずの つぎの 場面が ちがう（%d。%d の はず）" % [where, scr.to, want_to])
		return
	if get_viewport().gui_get_focus_owner() != scr.button:
		_fail("%s: ボタンに フォーカスが ない" % where)
	var texts: Array = scr.find_children("*", "Label", true, false).filter(func(l): return l.is_visible_in_tree()).map(func(l): return String(l.text).replace(T.WJ, ""))
	var want_say: String = ep["scenes"][scr.from]["say"] if EpisodeDB.is_pass(ep, scr.from) else EpisodeDB.hop_say(ep, scr.from, scr.to)
	for want in [want_say, "いま ここ", "つぎは ここ"]:
		if not texts.has(want):
			_fail("%s: 画面に「%s」が ない" % [where, want])
	if not HopScreen.say_fits(want_say):
		_fail("%s: ピコの ひとことが ふきだしに 入らない：%s" % [where, want_say])
	# とおる 場所の ならび：場面の 順。いまの 場所と つぎの 場所
	# とばした ときは 入口（さいしょの 場所）が いま ここ（地図の「いま ここ」と そろう）
	var line = scr.line
	var want_cur: int = scr.from
	if scr.from < 0 and EpisodeDB.stops(ep)[0] == EpisodeDB.trip(ep)["entry"]:
		want_cur = 0
	if line.places != EpisodeDB.stops(ep) or line.current != want_cur or line.next != scr.to:
		_fail("%s: とおる 場所の ならびが ちがう（%s %d→%d）" % [where, line.places, line.current, line.next])
	for i in line.names.size():
		var st := StageDB.get_stage(line.places[i])
		if line.names[i].text != st["name"]:
			_fail("%s: ならびの %d ばんめが「%s」" % [where, i, line.names[i].text])
	# ミクロごうは いまの 点から つぎの 場所へ（地図の 上）
	var pts: PackedVector2Array = scr.hop_points()
	var to_pt: Vector2 = scr._map.point(ep["scenes"][scr.to]["place"])
	if pts[pts.size() - 1].distance_to(to_pt) > 1.0:
		_fail("%s: ミクロごうが つぎの 場所へ 行かない" % where)
	if scr.from >= 0 and pts[0].distance_to(scr._map.point(ep["scenes"][scr.from]["place"])) > 1.0:
		_fail("%s: ミクロごうが いまの 場所から 出ない" % where)
	if Game.touch_controls != null and is_instance_valid(Game.touch_controls) and Game.touch_controls.visible:
		_fail("%s: タッチの ボタンが 画面の 上に のこって いる" % where)


## 遊びなおしの「とおりみちを とばす」：はじめての 話には 出ない。クリアずみで とおりみちが ある 話だけ。
## フォーカスは ふつうの ボタン。押すと みちの ちず（入口 → さいしょの ふつうの 場面）が 1 回 出て、その 場面へ
func _check_skip() -> void:
	_info("=== skip ===")
	var ep := EpisodeDB.get_episode("ep02")
	var id: String = ep["id"]
	var was_cleared := SaveData.is_cleared(id)
	SaveData.data["episodes"].erase(id)
	Game.start_episode(id, "enter")
	await _wait_focus()
	var jr := Game.screen()
	if not (jr is JourneyScreen) or jr.skip_button != null:
		_fail("skip: はじめての 話に「とおりみちを とばす」が 出る")
	# とおりみちが ない 話（ep01）は クリアずみでも 出ない
	SaveData.record_clear("ep01")
	Game.start_episode("ep01", "enter")
	await _wait_focus()
	if Game.screen().skip_button != null:
		_fail("skip: とおりみちの ない ep01 に「とおりみちを とばす」が 出る")
	SaveData.record_clear(id)
	_phases.clear()
	Game.start_episode(id, "enter")
	await _wait_focus()
	jr = Game.screen()
	if not (jr is JourneyScreen) or jr.skip_button == null:
		_fail("skip: クリアずみの %s に「とおりみちを とばす」が ない" % id)
		return
	if get_viewport().gui_get_focus_owner() != jr.button:
		_fail("skip: フォーカスが ふつうの ボタンに ない")
	_check_screen(jr, "skip enter")
	jr.skip_button.pressed.emit()
	await _wait_focus()
	var h := Game.screen()
	var first := EpisodeDB.next_scene(ep, -1, true)
	if not (h is HopScreen) or h.from != -1 or h.to != first:
		_fail("skip: とばしても みちの ちず（入口 → 場面 %d）が 出ない" % first)
		return
	_check_screen(h, "skip hop")
	_check_hop_screen(h, ep, true)
	# みちは 入口から：とばした 場所も ならびに ある
	if h.hop_points()[0].distance_to(h._map.point(EpisodeDB.ENTRANCES[ep["enter"]["way"]]["at"])) > 1.0:
		_fail("skip: みちの ちずが 入口から 始まらない")
	h.button.pressed.emit()
	await get_tree().process_frame
	if Game.phase != "scene" or Game.scene_index != first or Game.level == null:
		_fail("skip: みちの ちずの あと 場面 %d に 入らない（%s %d）" % [first, Game.phase, Game.scene_index])
	if _phases != ["enter", "hop-1", "scene%d" % first]:
		_fail("skip: 流れが ちがう（%s）" % [_phases])
	# この あとも とおりみちは とばす（ep03：い（胃）→ ちょう は そのまま。ep02 は い（胃）が さいご）
	if not await _play_until(func(): return Game.phase != "scene", MAX_SCENE_SECONDS):
		_fail("skip: 場面 %d が おわらない" % first)
	if not await _play_until(func(): return Game.phase == "scene" and Game.scene_index > first, MAX_UI_SECONDS):
		_fail("skip: つぎの 場面に 進まない（%s）" % Game.phase)
	elif EpisodeDB.is_pass(ep, Game.scene_index):
		_fail("skip: とばす はずの とおりみちに 入った")
	Game.show_episode_select()
	if not was_cleared:
		SaveData.data["episodes"].erase(id)
	await get_tree().process_frame


## 入口・出口の ひとことは たびの 画面だけに 出る（よそう・カルテには 出さない ＝ 2 回 読ませない）
func _check_no_dup(scr: Control, ep: Dictionary, where: String) -> void:
	for n in scr.find_children("*", "Label", true, false):
		if not n.is_visible_in_tree():
			continue
		var t := String(n.text).replace(T.WJ, "")
		for m in ["enter", "exit"]:
			if t == ep.get(m, {}).get("say", "—") and not (scr is JourneyScreen and scr.mode == m):
				_fail("%s: %s の ひとことが ほかの 画面にも 出て いる：%s" % [where, m, t])


# ---------------------------------------------------------------- ものしりカード
## 場面が 動いて いる あいだ：ゲームが 止まって いない（ポーズメニュー いがい）・カードの ポップアップが 無い。
## みつけた しらせは HUD の 部品（ハート・題・ミッション・ピコ・ポーズ・ポケット・てびき・タッチの ボタン）に 重ならない
func _watch_cards(lvl, where: String) -> void:
	if not lvl.started or lvl.finished:
		return
	var popup := false
	for c in Game.overlay_layer.get_children():
		if c is CardPopup:
			popup = true
	var paused := get_tree().paused and Game.overlay_layer.get_node_or_null("PauseMenu") == null
	if (popup or paused or Game.is_popup_open()) and not _card_stop_seen.has(where):
		_card_stop_seen[where] = true
		_fail("%s: 場面の とちゅうで %s" % [where, "カードが ひらいた" if popup or Game.is_popup_open() else "ゲームが 止まった"])
	var chip: Control = Game.hud.card_chip() if Game.hud != null and is_instance_valid(Game.hud) else null
	if chip != null and chip.modulate.a > 0.5 and not _chips_checked.has(chip.get_instance_id()):
		_chips_checked[chip.get_instance_id()] = true
		_chips_seen += 1
		_check_chip(chip, where)


## しらせ 1 つ：絵と だいめいが あり、本文は 無い。画面の 中で、HUD の 部品に 重ならない
func _check_chip(chip: Control, where: String) -> void:
	var r := chip.get_global_rect()
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	if not view.encloses(r):
		_fail("%s: カードの しらせが 画面の 外（%s）" % [where, r])
	var rects: Dictionary = Game.hud.hud_rects()
	for k in rects:
		if r.intersects(rects[k]):
			_fail("%s: カードの しらせ %s が %s %s に 重なる" % [where, r, k, rects[k]])
	var labels := chip.find_children("*", "Label", true, false)
	if labels.size() != 2 or String(labels[1].text) == "":
		_fail("%s: カードの しらせに だいめいが ない" % where)
	_check_texts(chip, where + " しらせ")


## フェーズが かわった：「みつけた ものしりカード」は 出る はずの ときだけ 出る
func _check_cards_phase(p: String, _i: int) -> void:
	if p == "cards":
		_cards_screens += 1
		if not _cards_pending:
			_fail("%s: 「みつけた ものしりカード」が 出ては いけない ときに 出た（とおりみち／新しい カード なし）" % Game.episode.get("id", "?"))
		# ボタンの 画面：場面（ボス）の 曲の まま に しない（あとの はなしと 同じ 曲）
		var want_m := Sfx.phase_music("after")
		if want_m != "" and Sfx._bgm_name != want_m:
			_fail("%s: 「みつけた ものしりカード」の 曲が %s（%s の はず）" % [Game.episode.get("id", "?"), Sfx._bgm_name, want_m])
		_cards_pending = false
	elif _cards_pending and p in ["after", "hop", "exit", "karte", "consult"]:
		_fail("%s: 新しい カード %s を みつけたのに「みつけた ものしりカード」が 出ない（%s へ）" % [Game.episode.get("id", "?"), _cards_want, p])
		_cards_pending = false


## 「みつけた ものしりカード」の 画面（カルテの 流れの 中）：みつけた カードが ならび、主ボタンに フォーカス
func _check_cards_found(scr, fo: Control, where: String) -> void:
	if scr.has_meta("checked"):
		return
	scr.set_meta("checked", true)
	if fo != scr.button:
		_fail("%s: 主ボタンに フォーカスが ない（%s）" % [where, _ctl_name(fo)])
	var want := _cards_want.duplicate()
	if scr.keys != want:
		_fail("%s: ならんだ カード %s が みつけた カード %s と ちがう" % [where, scr.keys, want])
	if not scr.keys.has("stage") and not SaveData.card_seen(scr.stage_id, "stage"):
		_fail("%s: 場所の カード（stage）が ない" % where)
	for k in scr.keys:
		if not SaveData.card_seen(scr.stage_id, k):
			_fail("%s: %s が ずかんに 入って いない" % [where, k])
	_info("  %s: %d cards %s" % [where, scr.keys.size(), scr.keys])


## いちばん 多い 形・矢印・タイルを 開いて もどる・決定で 進む・そこで やめた ときの つづきから・古い セーブ
func _check_cards_screen() -> void:
	_info("=== cards screen ===")
	var keep: Dictionary = SaveData.data.duplicate(true)
	# 1. どの 場所も、全部の カード ＋ stage を ならべて 入る（場面で みつかる いちばん 多い 数は これ いか）
	var most := ""
	var most_n := 0
	for sid in StageDB.stage_ids():
		var keys: Array = StageDB.get_stage(sid)["cards"].keys().filter(func(k): return k != "stage")
		keys.append("stage")
		var scr = CardsScreen.new()
		scr.setup(sid, keys)
		Game._set_screen(scr)
		await _wait_focus()
		_check_screen(scr, "cards " + sid)
		if get_viewport().gui_get_focus_owner() != scr.button:
			_fail("cards %s: 主ボタンに フォーカスが ない" % sid)
		if keys.size() > most_n:
			most_n = keys.size()
			most = sid
	_info("cards screen: most %d (%s), max %d" % [most_n, most, CardsScreen.MAX_TILES])
	# 2. 本物の 入力：上 → さいごの タイル、ひだり → その まえ、決定 → カードが ひらく、決定 → とじて 同じ タイルへ、下 → 主ボタン、決定 → 進む
	SaveData.reset()
	var keys2: Array = StageDB.get_stage(most)["cards"].keys().filter(func(k): return k != "stage")
	keys2.append("stage")
	for k in keys2:
		SaveData.find_card(most, k)
	var scr = CardsScreen.new()
	scr.setup(most, keys2)
	var done := [false]
	scr.finished.connect(func(): done[0] = true)
	Game._set_screen(scr)
	await _wait_focus()
	var n: int = scr.tiles.size()
	await _tap_expect("ui_up", scr.tiles[n - 1], "みつけた カード 主ボタン")
	await _tap_expect("ui_up", scr.tiles[n - 1], "みつけた カード タイル")
	await _tap_expect("ui_left", scr.tiles[n - 2], "みつけた カード タイル")
	var k2: String = keys2[n - 2]
	if not SaveData.card_is_new(most, k2):
		_fail("cards: みつけた カードに まだ 開いて いない しるしが ない")
	await _tap("ui_accept")
	var t := 0.0
	while t < 5.0 and (scr.popup == null or scr.popup.button().disabled):
		await get_tree().process_frame
		t += get_process_delta_time()
	if scr.popup == null:
		_fail("cards: タイルを 決定で 押しても カードが ひらかない")
	else:
		if get_viewport().gui_get_focus_owner() != scr.popup.button():
			_fail("cards: ひらいた カードの ボタンに フォーカスが ない")
		_check_texts(scr.popup, "cards popup")
		_check_layout(scr.popup, "cards popup")
		# 矢印で 下の 画面へ 出て いかない
		await _tap_expect("ui_down", scr.popup.button(), "ひらいた カード")
		await _tap_expect("ui_right", scr.popup.button(), "ひらいた カード")
		await _tap("ui_accept")
		t = 0.0
		while t < 5.0 and (scr.popup != null or scr.locked()):
			await get_tree().process_frame
			t += get_process_delta_time()
		if scr.popup != null or Game.screen() != scr:
			_fail("cards: カードを とじても もどらない")
		if get_viewport().gui_get_focus_owner() != scr.tiles[n - 2]:
			_fail("cards: カードを とじた あと 同じ タイルに フォーカスが もどらない（%s）" % _ctl_name(get_viewport().gui_get_focus_owner()))
		if SaveData.card_is_new(most, k2) or not SaveData.card_is_new(most, keys2[0]):
			_fail("cards: 開いた カードだけ しるしが 消える はず")
	if done[0]:
		_fail("cards: タイルを 押しただけで 進んだ")
	await _tap_expect("ui_down", scr.button, "みつけた カード タイル")
	await _tap("ui_accept")
	await get_tree().process_frame
	if not done[0]:
		_fail("cards: 主ボタンを 決定で 押しても 進まない")
	# 3. ずかん：開いて いない カードに しるし、開いた カードには ない
	Game.show_zukan()
	for i in 5:
		await get_tree().process_frame
	var z := Game.screen()
	if not (z is ZukanScreen) or not z.new_marks.has(SaveData.card_key(most, keys2[0])) or z.new_marks.has(SaveData.card_key(most, k2)):
		_fail("cards: ずかんの まだ 開いて いない しるしが ちがう（%s）" % (z.new_marks.keys() if z is ZukanScreen else "なし"))
	# 4. 古い セーブ（cards_new が 無い）：見た カードは 見た まま（しるし なし）。cards_new の まちがいは すてる
	_write('{"version":3,"cards_seen":["mouth/stage","mouth/mushiba"]}')
	SaveData.load_data()
	if not SaveData.card_seen("mouth", "mushiba") or SaveData.card_is_new("mouth", "mushiba") or SaveData.card_is_new("mouth", "stage"):
		_fail("cards: 古い セーブの 見た カードが 見た ままで ない")
	_write('{"version":3,"cards_seen":["mouth/stage"],"cards_new":["mouth/stage","mouth/tooth",7]}')
	SaveData.load_data()
	if not SaveData.card_is_new("mouth", "stage") or SaveData.card_is_new("mouth", "tooth") or SaveData.data["cards_new"].size() != 1:
		_fail("cards: cards_new の 読みこみが ちがう（%s）" % [SaveData.data["cards_new"]])
	# 5. 「みつけた ものしりカード」で やめた：つづきから は その 場面の あとの はなし（→ みちの ちず → つぎの 場面）。カードは ずかんに ある
	var ep_id := ""
	var at := -1
	for e in EpisodeDB.EPISODES:
		for i in e["scenes"].size() - 1:
			if ep_id == "" and not EpisodeDB.is_pass(e, i):
				ep_id = e["id"]
				at = i
	if ep_id != "":
		var ep := EpisodeDB.get_episode(ep_id)
		SaveData.reset()
		SaveData.data["opening_seen"] = true
		for prev in EpisodeDB.ids():   # この 話が 開いて いる ように（カルテえらびの 主ボタンが「つづきから」に なる）
			if prev == ep_id:
				break
			SaveData.record_clear(prev)
		Game.start_episode(ep_id, "scene", at)
		if not await _play_until(func(): return Game.phase == "cards" or (Game.phase != "scene" and Game.phase != ""), MAX_SCENE_SECONDS):
			_fail("cards resume: 場面が おわらない")
		elif Game.phase != "cards":
			_fail("cards resume: %s 場面 %d の あとに「みつけた ものしりカード」が 出ない（%s）" % [ep_id, at, Game.phase])
		else:
			await _wait_focus()
			var cs = Game.screen()
			var found: Array = cs.keys.duplicate()
			var csid: String = cs.stage_id
			Game.show_episode_select()   # ここで やめた（アプリを とじて また 開いた ときと 同じ）
			await _wait_focus()
			var r := SaveData.resume()
			if r.get("ep", "") != ep_id or int(r.get("cleared", 0)) != at + 1:
				_fail("cards resume: つづきが ちがう（%s）" % r)
			var sel := Game.screen()
			if not (sel is SelectScreen) or not sel.main_is_resume or _focused_button(sel) != sel.main_btn:
				_fail("cards resume: カルテえらびの 主ボタンが「つづきから」で ない")
			for k in found:
				if not SaveData.card_seen(csid, k) or not SaveData.card_is_new(csid, k):
					_fail("cards resume: %s が ずかんに 新しい カードとして 入って いない" % k)
			_phases.clear()
			if not await _play_until(func(): return Game.phase == "scene" and Game.level != null and Game.level.started, MAX_UI_SECONDS, "cards resume"):
				_fail("cards resume: つづきから 場面に 入れない（%s）" % Game.phase)
			var want: Array = (["after%d" % at] if not EpisodeDB.after_lines(ep, at, "").is_empty() else []) + ["hop%d" % at, "scene%d" % EpisodeDB.next_scene(ep, at, false)]
			if _phases != want:
				_fail("cards resume: つづきからの 流れが ちがう（%s。%s の はず）" % [_phases, want])
			else:
				_info("cards resume %s: quit on cards after scene %d -> %s" % [ep_id, at, _phases])
			Game.show_episode_select()
	# 6. 場面の とちゅうで みつけた しらせ（タッチの ボタン あり）：HUD の 部品に 重ならない。ピコの ながい 文が 出て いても
	# [タッチ, 場所, カード, はじめての そうじゅうの てびき]：ながい だいめい（かぜウイルスだいおう）・てびきの みぎ
	for cfg in [[true, "lungs", "boss_virus", false], [false, "lungs", "boss_virus", false], [true, "mouth", "stage", true], [false, "mouth", "mushiba", true]]:
		var touch_on: bool = cfg[0]
		SaveData.reset()
		SaveData.set_setting("volume", 0.0)
		SaveData.set_setting("touch", "on" if touch_on else "off")
		SaveData.data["steer_guide_seen"] = not cfg[3]
		Game.start_stage(cfg[1])
		for i in 30:
			await get_tree().process_frame
		var where := "chip %s %s touch=%s guide=%s" % [cfg[1], cfg[2], touch_on, cfg[3]]
		if cfg[3] and Game.hud.get_node_or_null("SteerGuide") == null:
			_fail("%s: てびきが 出て いない" % where)
		# ピコの いちばん ながい ふきだし（4 行）でも 重ならない
		Game.say("これは とても ながい ひとことの ためしだよ。しらせと かさならないか みるよ。もう すこし ながく して、4 ぎょうに なるかな？ まだ まだ つづくよ。", 5.0)
		Game.find_card(cfg[1], cfg[2])
		for i in 10:
			await get_tree().process_frame
		var chip: Control = Game.hud.card_chip()
		if chip == null:
			_fail("%s: しらせが 出ない" % where)
		else:
			_check_chip(chip, where)
			_info("%s: %s; hud %s" % [where, chip.get_global_rect(), Game.hud.hud_rects()])
		# てびきの ない ときは、どの カードの だいめいも 字を 小さく せずに 入る（ちいさい 字は 6 さいには 読みにくい）
		if not cfg[3]:
			for sid in StageDB.stage_ids():
				for ck in StageDB.get_stage(sid)["cards"].keys():
					Game.hud.show_card_chip(StageDB.card(sid, ck), ck, sid)
					await get_tree().process_frame
					var c2: Control = Game.hud.card_chip()
					var tl: Label = c2.find_child("Title", true, false) if c2 != null else null
					if tl == null:
						_fail("%s %s/%s: しらせが 出ない" % [where, sid, ck])
						continue
					if tl.get_theme_font_size("font_size") < Game.HudScene.CHIP_TITLE_SIZE:
						_fail("%s %s/%s: だいめいの 字が 小さく なった（%d）" % [where, sid, ck, tl.get_theme_font_size("font_size")])
					_check_chip(c2, "%s %s/%s" % [where, sid, ck])
		if get_tree().paused:
			_fail("%s: しらせで ゲームが 止まった" % where)
	Game.show_episode_select()
	SaveData.data = keep
	SaveData.save()
	await get_tree().process_frame


# ---------------------------------------------------------------- 5. 画面の 行き来
## 画面の フォーカス中の ボタンを 押しつづける（cond が true に なる まで）。場面は 自動操縦
func _play_until(cond: Callable, max_seconds: float, where := "") -> bool:
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
		var scr := Game.screen()
		var fo := _focused_button(scr)
		if fo != null:
			if where != "":
				_check_screen(scr, where)
			fo.pressed.emit()
	return cond.call()


## 画面が 出て、押せる ボタンに フォーカスが 入る まで 待つ
func _wait_focus() -> void:
	for i in 60:
		if _focused_button(Game.screen()) == null:
			await get_tree().physics_frame


## タイトル：「はじめる」に フォーカスが あり、押すと カルテえらびに 行く
func _check_title() -> void:
	Game.show_title()
	for i in 5:
		await get_tree().process_frame
	var scr := Game.screen()
	var fo := get_viewport().gui_get_focus_owner()
	if not (scr is TitleScreen) or not (fo is Button) or not scr.is_ancestor_of(fo):
		_fail("title: タイトルの ボタンに フォーカスが ない")
		return
	_check_texts(scr, "title")
	_check_layout(scr, "title")
	(fo as Button).pressed.emit()
	await get_tree().process_frame
	if not (Game.screen() is SelectScreen):
		_fail("title: 「はじめる」で カルテえらびに 行かない")


## よそうで「もどる」→ そうだんの さいごの ページ → 進むと また よそう（カルテえらびまで もどされない）
func _check_back() -> void:
	var id: String = EpisodeDB.ids()[0]
	Game.start_episode(id, "guess")
	await _wait_focus()
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


## さいしょの よそうが あたり（hit）だった 子：あとの はなしは lines_hit、かいけつの 段に「あたっていたね」
func _check_hit() -> void:
	for ep in EpisodeDB.EPISODES:
		var hit := ""
		for c in ep.get("guess", {}).get("choices", []):
			if hit == "" and c.get("hit", false):
				hit = c["place"]
		if hit == "":
			continue
		var id: String = ep["id"]
		for i in ep["scenes"].size():
			var a: Dictionary = ep["scenes"][i].get("after", {})
			if not a.has("lines_hit"):
				continue
			Game.start_episode(id, "after", i, hit)
			await _wait_focus()
			var t := Game.screen()
			if not (t is TalkScreen) or t.lines != a["lines_hit"]:
				_fail("hit: %s scene %d の あとの はなしが lines_hit で ない" % [id, i])
			else:
				_check_screen(t, "%s after%d（あたり）" % [id, i])
		Game.start_episode(id, "karte", 0, hit)
		await _wait_focus()
		var k := Game.screen()
		if not (k is KarteScreen) or not k.opts.get("guess_hit", false):
			_fail("hit: %s の カルテ画面に「あたっていたね」が 出ない" % id)
		else:
			_check_screen(k, "%s karte（あたり）" % id)
	Game.show_episode_select()
	await get_tree().process_frame


## 場面 1 を おえて やめる → カルテえらびに「つづきから」が 出て、押すと 場面 2 に 入る。
## そこで ポーズ →「カルテえらびへ」→ まだ「つづきから」が ある。ほかの 話を 遊びなおしても つづきは のこる。
## さいごに クイズの やりなおし（カルテの 紙と クイズだけ）
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
	# カルテえらびの 右の パネルが いちばん こむ 形に する：クリアずみ ＋ つづき ＋ クイズの ほしが まだ
	SaveData.record_clear(id)
	SaveData.data["episodes"][id]["quiz"] = false
	Game.show_episode_select()      # アプリを とじて また 開いた ときと 同じ
	await _wait_focus()
	var scr := Game.screen()
	if not (scr is SelectScreen) or scr.selected_id != id or not scr.main_is_resume or _focused_button(scr) != scr.main_btn or scr.restart_btn == null or scr.quiz_btn == null:
		_fail("resume: カルテえらびに「つづきから」「さいしょから」「クイズに もういちど」が そろわない")
		return
	_check_screen(scr, "resume カルテえらび")
	_phases.clear()
	if not await _play_until(func(): return Game.phase == "scene" and Game.level != null and Game.level.started, MAX_UI_SECONDS, "resume"):
		_fail("resume: つづきから 場面に 入れない（%s）" % Game.phase)
		return
		# つづきからは からだの 中に もどる（入口の たびの 画面を もう一度 通らない）。おえた 場面の あとの はなし（あれば）→ みちの ちず → 場面 2
	var want_ph: Array = (["after0"] if not EpisodeDB.after_lines(ep, 0, "").is_empty() else []) + ["hop0", "scene1"]
	if _phases.has("enter") or _phases != want_ph:
		_fail("resume: つづきからの 流れが ちがう（%s。%s の はず。enter は 通らない）" % [_phases, want_ph])
	if Game.scene_index != 1 or Game.level.stage_id != ep["scenes"][1]["place"]:
		_fail("resume: 場面 2 では ない（scene %d %s）" % [Game.scene_index, Game.level.stage_id])
	else:
		_info("resumed %s at scene 1 (%s)" % [id, Game.level.stage_id])
	# 「この ばめんを やりなおす」：同じ 場面が 最初から 始まる（そうだんへは もどらない。つづきも 消えない）
	var old_level = Game.level
	Game.retry_stage()
	await get_tree().process_frame
	if Game.level == null or Game.level == old_level or not Game.level.started or Game.phase != "scene" or Game.scene_index != 1 or Game.level.stage_id != ep["scenes"][1]["place"] or SaveData.resume().get("ep", "") != id:
		_fail("resume: 「この ばめんを やりなおす」で 同じ 場面が 始まらない")
		return
	# 場面 2 の とちゅうで ポーズ →「カルテえらびへ」。ボタンに「つづきから できるよ」と 書いて あり、やめても つづきは のこる
	Game.toggle_pause()
	await get_tree().process_frame
	var pm: Control = Game.overlay_layer.get_node_or_null("PauseMenu")
	var quit: Button = null
	if pm != null:
		_check_texts(pm, "pause")
		_check_layout(pm, "pause")
		for b in pm.find_children("*", "Button", true, false):
			if b.text.begins_with("カルテえらびへ"):
				quit = b
	var pause_focus := get_viewport().gui_get_focus_owner()
	if pm == null or not get_tree().paused or quit == null or not quit.text.contains("つづきから") or pause_focus == null or not pm.is_ancestor_of(pause_focus):
		_fail("resume: ポーズに「カルテえらびへ（つづきから できるよ）」が 無い、または フォーカスが 無い")
		if get_tree().paused:
			Game.toggle_pause()
		Game.show_episode_select()
	else:
		quit.pressed.emit()
	await _wait_focus()
	scr = Game.screen()
	if not (scr is SelectScreen) or not scr.main_is_resume or Game.level != null or get_tree().paused:
		_fail("resume: ポーズから やめた あと、カルテえらびに「つづきから」が 出ない")
	# クリアずみの ほかの 話を 遊びなおしても、この 話の つづきは 上書きされない
	var other := ""
	for e in EpisodeDB.EPISODES:
		if other == "" and e["id"] != id and SaveData.is_cleared(e["id"]):
			other = e["id"]
	if other != "":
		Game.start_episode(other, "scene", 0)
		if not await _play_until(func(): return Game.phase != "scene", MAX_SCENE_SECONDS):
			_fail("resume: %s の 場面 1 が おわらない" % other)
		if SaveData.resume().get("ep", "") != id:
			_fail("resume: クリアずみの %s を 遊びなおしたら %s の つづきが 消えた" % [other, id])
	# クリアずみの 話の クイズだけ もういちど：クリアの 記録も つづきも 変わらない
	SaveData.record_clear(id)
	_phases.clear()
	Game.review_karte(id)
	if Game.phase != "karte" or SaveData.resume().get("ep", "") != id:
		_fail("resume: review_karte が つづきを 消した")
	if not await _play_until(func(): return Game.screen() is SelectScreen, MAX_UI_SECONDS, "review"):
		_fail("resume: クイズの やりなおしから カルテえらびに もどらない")
	# クイズの やりなおしは カルテだけ（出口の たびの 画面は 出ない）
	if _phases != ["karte"]:
		_fail("resume: クイズの やりなおしの 流れが ちがう（%s。karte だけの はず）" % [_phases])
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
	_check_texts(scr, "zukan")
	_check_layout(scr, "zukan")
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
		_check_texts(scr.popup, "zukan card " + id)
		_check_layout(scr.popup, "zukan card " + id)
		scr.popup.button().pressed.emit()
		t = 0.0
		while t < 5.0 and scr.popup != null:
			await get_tree().process_frame
			t += get_process_delta_time()
		if get_viewport().gui_get_focus_owner() != b:
			_fail("zukan: カードを 閉じた あと フォーカスが もどらない（%s）" % id)
	if first:
		_fail("zukan: 見た カルテが 1 つも ない")


## アクションを 1 回 押して はなす（キーボード・ゲームパッドと 同じ 道：Input → Viewport → フォーカス中の Control）
func _tap(action: String) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await get_tree().process_frame


## 失敗の 文に 書く ボタンの 名前（c は 作りなおされて 消えた ボタンの ことも ある。だから 型を 書かない）
func _ctl_name(c) -> String:
	if c == null or not is_instance_valid(c):
		return "なし"
	return String(c.text).replace(T.WJ, "").left(14) if c is Button and c.text != "" else String(c.name)


## action を 押した あと、フォーカスが want に ある こと
func _tap_expect(action: String, want, where: String) -> void:
	await _tap(action)
	var fo := get_viewport().gui_get_focus_owner()
	if fo != want:
		_fail("keys: %s：%s の あと フォーカスが「%s」（「%s」の はず）" % [where, action, _ctl_name(fo), _ctl_name(want)])


## 本物の 入力（ui_up／ui_down／ui_left／ui_right／ui_accept／ui_cancel）で 4 つの 画面を 動かす。
## ほかの 検査は ボタンの pressed を 直接 出すので、「矢印で 行ける」「決定で 押せる」「もどるで もどれる」は ここで 守る
func _check_keys() -> void:
	_info("=== keys ===")
	var ids := EpisodeDB.ids()
	var id := ""
	for e in EpisodeDB.EPISODES:
		if id == "" and e["scenes"].size() >= 2 and e.has("guess"):
			id = e["id"]
	if id == "":
		return
	var ep := EpisodeDB.get_episode(id)
	# ---- カルテえらび：ボタンが いちばん 多い 形（つづきから・さいしょから・クイズに もういちど）
	for prev in ids:
		SaveData.record_clear(prev)
		if prev == id:
			break
	SaveData.data["episodes"][id]["quiz"] = false
	SaveData.set_resume(id, 1, "")
	Game.show_episode_select()
	await _wait_focus()
	var s := Game.screen()
	if not (s is SelectScreen) or s.restart_btn == null or s.quiz_btn == null or get_viewport().gui_get_focus_owner() != s.main_btn:
		_fail("keys: カルテえらびの 形が ちがう")
		return
	var row: Button = s.rows[id]
	await _tap_expect("ui_down", s.restart_btn, "カルテえらび 主ボタン")
	await _tap_expect("ui_right", s.quiz_btn, "カルテえらび さいしょから")
	await _tap_expect("ui_right", s.quiz_btn, "カルテえらび クイズに もういちど")
	await _tap_expect("ui_down", s.quiz_btn, "カルテえらび クイズに もういちど")
	await _tap_expect("ui_left", s.restart_btn, "カルテえらび クイズに もういちど")
	await _tap_expect("ui_up", s.main_btn, "カルテえらび さいしょから")
	await _tap_expect("ui_up", s.main_btn, "カルテえらび 主ボタン")
	await _tap_expect("ui_right", s.main_btn, "カルテえらび 主ボタン")
	await _tap_expect("ui_left", row, "カルテえらび 主ボタン")
	await _tap_expect("ui_left", row, "カルテえらび 行")
	var at := ids.find(id)
	if at > 0:
		# 行の 上下：フォーカスと いっしょに えらんだ 話が 変わり、右の パネルが その 話に なる
		await _tap_expect("ui_up", s.rows[ids[at - 1]], "カルテえらび 行")
		if s.selected_id != ids[at - 1] or s.main_is_resume:
			_fail("keys: カルテえらび：行を 上に 動かしても えらんだ 話が 変わらない（%s）" % s.selected_id)
		await _tap_expect("ui_right", s.main_btn, "カルテえらび 行")
		# 小さい ボタンが 無い 話では 下を 押しても 主ボタンの まま。ある 話では そこへ 行って、上で もどる
		var below: Button = s.restart_btn if s.restart_btn != null else (s.quiz_btn if s.quiz_btn != null else s.main_btn)
		await _tap_expect("ui_down", below, "カルテえらび 主ボタン")
		await _tap_expect("ui_up", s.main_btn, "カルテえらび 主ボタンの 下")
		await _tap_expect("ui_left", s.rows[ids[at - 1]], "カルテえらび 主ボタン")
		await _tap_expect("ui_down", row, "カルテえらび 行")
	if s.selected_id != id or not s.main_is_resume:
		_fail("keys: カルテえらび：行を もどしても えらんだ 話が もどらない（%s）" % s.selected_id)
	# 行を 決定で 押す → 主ボタンへ。さいしょから（決定）→ そうだん
	await _tap("ui_accept")
	await _wait_focus()
	if get_viewport().gui_get_focus_owner() != s.main_btn:
		_fail("keys: カルテえらび：行を 押しても 主ボタンに フォーカスが 行かない")
	await _tap_expect("ui_down", s.restart_btn, "カルテえらび 主ボタン")
	await _tap("ui_accept")
	await _wait_focus()
	# ---- そうだん：決定で 次の ページ、もどるで 前の ページ。矢印を 押しても ボタンから 外れない
	var t := Game.screen()
	if not (t is TalkScreen) or Game.episode.get("id", "") != id or Game.phase != "consult":
		_fail("keys: 「さいしょから」を 決定で 押しても そうだんが 始まらない（%s）" % Game.phase)
		return
	if t.lines.size() >= 2:
		await _tap("ui_accept")
		await _wait_focus()
		if t.page != 1:
			_fail("keys: そうだん：決定で 次の ページに 行かない")
		await _tap("ui_cancel")
		await _wait_focus()
		if t.page != 0:
			_fail("keys: そうだん：もどるで 前の ページに もどらない")
	for a in ["ui_down", "ui_right", "ui_left", "ui_up", "ui_down"]:
		await _tap(a)
		if _focused_button(t) == null:
			_fail("keys: そうだん：%s の あと フォーカスが ボタンに ない" % a)
	t.focus_target.grab_focus()   # 矢印で「もどる」に 行って いても、ここからは「つぎへ」を 押す
	if not await _key_until(func(): return Game.phase == "guess", "ui_accept"):
		_fail("keys: そうだん：決定で よそうに 進めない")
		return
	# ---- よそう：上下で えらぶ。ひだり・みぎ では 動かない。はずれ → のこりへ、go → しゅっぱつ、もどる → そうだん
	await _wait_focus()
	var g := Game.screen()
	var places: Array[String] = []
	var wrong := ""
	var go := ""
	for c in ep["guess"]["choices"]:
		places.append(c["place"])
		if c.get("go", false) and go == "":
			go = c["place"]
		if not c.get("go", false) and wrong == "":
			wrong = c["place"]
	if get_viewport().gui_get_focus_owner() != g.buttons[places[0]]:
		_fail("keys: よそう：最初の フォーカスが 1 つめの えらびに ない")
	await _tap_expect("ui_left", g.buttons[places[0]], "よそう 1 つめ")
	await _tap_expect("ui_right", g.buttons[places[0]], "よそう 1 つめ")
	for i in range(1, places.size()):
		await _tap_expect("ui_down", g.buttons[places[i]], "よそう %d つめ" % i)
	await _tap_expect("ui_down", g.buttons[places[-1]], "よそう いちばん 下")
	for i in range(places.size() - 2, -1, -1):
		await _tap_expect("ui_up", g.buttons[places[i]], "よそう %d つめ" % (i + 2))
	if wrong != "":
		for i in places.find(wrong):
			await _tap("ui_down")
		await _wait_focus()
		await _tap("ui_accept")
		await _wait_focus()
		var rest := ""
		for p in places:
			if rest == "" and p != wrong:
				rest = p
		if not g.buttons[wrong].disabled or get_viewport().gui_get_focus_owner() != g.buttons[rest]:
			_fail("keys: よそう：はずれを 決定で えらんでも、のこりの 1 つめに フォーカスが 行かない")
	# go の えらびまで 下へ（押せない ボタンは とばされる）
	for i in places.size():
		if get_viewport().gui_get_focus_owner() != g.buttons[go]:
			await _tap("ui_down")
	if get_viewport().gui_get_focus_owner() != g.buttons[go]:
		_fail("keys: よそう：go の えらびに 矢印で 行けない")
		g.set_focus(g.buttons[go])
	await _wait_focus()
	await _tap("ui_accept")
	await _wait_focus()
	var go_btn := get_viewport().gui_get_focus_owner()
	if not (go_btn is Button) or not go_btn.text.begins_with("しゅっぱつ") or not go_btn.is_visible_in_tree():
		_fail("keys: よそう：go を 決定で えらんでも「しゅっぱつ」に フォーカスが 行かない")
	else:
		for a in ["ui_left", "ui_right", "ui_down"]:
			await _tap_expect(a, go_btn, "よそう しゅっぱつ")
	await _tap("ui_cancel")
	await _wait_focus()
	t = Game.screen()
	if Game.phase != "consult" or not (t is TalkScreen) or t.page != t.lines.size() - 1:
		_fail("keys: よそう：もどるで そうだんの さいごの ページに もどらない")
	elif not await _key_until(func(): return Game.screen() is SelectScreen, "ui_cancel"):
		_fail("keys: そうだん：もどるを つづけても カルテえらびに もどらない")
	# ---- たびの 画面：ボタン 1 つ。矢印でも フォーカスは ボタンの まま、もどるは 何も しない、決定で 進む
	for m in ["enter", "exit"]:
		Game.start_episode(id, m, 0 if m == "enter" else ep["scenes"].size() - 1)
		await _wait_focus()
		var jr := Game.screen()
		if not (jr is JourneyScreen) or get_viewport().gui_get_focus_owner() != jr.button:
			_fail("keys: たびの 画面（%s）の ボタンに フォーカスが ない" % m)
			continue
		for a in ["ui_up", "ui_down", "ui_right", "ui_cancel"]:
			await _tap_expect(a, jr.button, "たびの 画面 %s" % m)
		if jr.skip_button != null:
			# 遊びなおし：ひだりに「とおりみちを とばす」。そこからは みぎで もどる だけ
			await _tap_expect("ui_left", jr.skip_button, "たびの 画面 %s" % m)
			for a in ["ui_up", "ui_down", "ui_left"]:
				await _tap_expect(a, jr.skip_button, "たびの 画面 %s とばす" % m)
			await _tap_expect("ui_right", jr.button, "たびの 画面 %s とばす" % m)
		else:
			await _tap_expect("ui_left", jr.button, "たびの 画面 %s" % m)
		if Game.screen() != jr or Game.phase != m:
			_fail("keys: たびの 画面（%s）：もどるで 画面が 変わった" % m)
			continue
		await _wait_focus()
		await _tap("ui_accept")
		await get_tree().process_frame
		var want := "scene" if m == "enter" else "karte"
		if Game.phase != want:
			_fail("keys: たびの 画面（%s）：決定で %s に 進まない（%s）" % [m, want, Game.phase])
	# ---- みちの ちず：ボタン 1 つ。矢印でも もどるでも ボタンの まま、決定で つぎの 場面へ
	Game.start_episode(id, "hop", 0)
	await _wait_focus()
	var hp := Game.screen()
	if not (hp is HopScreen) or get_viewport().gui_get_focus_owner() != hp.button:
		_fail("keys: みちの ちずの ボタンに フォーカスが ない")
	else:
		for a in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_cancel"]:
			await _tap_expect(a, hp.button, "みちの ちず")
		var hop_to: int = hp.to
		await _wait_focus()
		await _tap("ui_accept")
		await get_tree().process_frame
		if Game.phase != "scene" or Game.scene_index != hop_to:
			_fail("keys: みちの ちず：決定で 場面 %d に 進まない（%s %d）" % [hop_to, Game.phase, Game.scene_index])
	Game.show_episode_select()
	await get_tree().process_frame
	# ---- カルテ：もどるは 何も しない。決定で 段を 進む。クイズは 上下、ほしの 段は 左右
	Game.start_episode(id, "karte")
	await _wait_focus()
	var k := Game.screen()
	await _tap("ui_cancel")
	if Game.screen() != k or not (k is KarteScreen) or k.step != 0:
		_fail("keys: カルテ：もどるで 画面が 変わった")
		return
	if not await _key_until(func(): return k.step == 2, "ui_accept"):
		_fail("keys: カルテ：決定で クイズまで 進めない")
		return
	if get_viewport().gui_get_focus_owner() != k.quiz_buttons[0]:
		_fail("keys: カルテ：クイズの 1 つめに フォーカスが ない")
	for i in range(1, k.quiz_buttons.size()):
		await _tap_expect("ui_down", k.quiz_buttons[i], "クイズ %d つめ" % i)
	await _tap_expect("ui_down", k.quiz_buttons[-1], "クイズ いちばん 下")
	await _tap_expect("ui_left", k.quiz_buttons[-1], "クイズ いちばん 下")
	await _wait_focus()
	await _tap("ui_accept")
	await _wait_focus()
	var main_b := get_viewport().gui_get_focus_owner()
	if k.step != 3 or not (main_b is Button):
		_fail("keys: カルテ：クイズを 決定で 答えても ほしの 段に 行かない")
		return
	if EpisodeDB.next_id(id) != "":
		# 主ボタン（つぎの カルテへ）の ひだりに「カルテえらびへ」
		await _tap("ui_left")
		var other := get_viewport().gui_get_focus_owner()
		if other == main_b or not (other is Button) or not other.text.begins_with("カルテえらびへ"):
			_fail("keys: カルテ：ほしの 段の ひだりが「カルテえらびへ」で ない（%s）" % _ctl_name(other))
		await _tap_expect("ui_right", main_b, "ほしの 段 カルテえらびへ")
	for a in ["ui_up", "ui_down", "ui_right"]:
		await _tap_expect(a, main_b, "ほしの 段 主ボタン")
	# ---- カルテの 読みかえし（クイズに もういちど）：こちらは もどるで カルテえらびへ。記録は 変わらない
	var stars_before := SaveData.stars(id)
	Game.review_karte(id)
	await _wait_focus()
	k = Game.screen()
	if not (k is KarteScreen) or k.step != 1:
		_fail("keys: 読みかえしが カルテの 紙から 始まらない")
	else:
		_check_screen(k, "読みかえし")
		await _tap("ui_cancel")
		await _wait_focus()
		if not (Game.screen() is SelectScreen) or SaveData.stars(id) != stars_before or not SaveData.is_cleared(id):
			_fail("keys: 読みかえし：もどるで カルテえらびに もどらない、または 記録が 変わった")
	SaveData.clear_resume()
	Game.show_episode_select()
	await get_tree().process_frame


## cond が true に なる まで、フォーカスが ボタンに 入る たびに action を 押す
func _key_until(cond: Callable, action: String) -> bool:
	for i in 12:
		if cond.call():
			return true
		await _wait_focus()
		await _tap(action)
	return cond.call()


# ---------------------------------------------------------------- 6. 場所
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
	var st := StageDB.get_stage(id)
	if Sfx.bgm_name() != Sfx.stage_music(st) or (id == "lungs" and Sfx.bgm_name() != "bgm_boss"):
		_fail("place %s: 曲が %s（%s の はず）" % [id, Sfx.bgm_name(), Sfx.stage_music(st)])
	if Game.hud == null or Game.hud.title_label().text != "%s（%s）" % [st["name"], st["kanji"]]:
		_fail("place %s: 場所だけの ときの HUD の 題が ちがう" % id)
	_finished = false
	var t := 0.0
	var last_report := 0.0
	while not _finished and t < MAX_SCENE_SECONDS:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if is_instance_valid(lvl):
			_watch_cards(lvl, "place " + id)
		if is_instance_valid(lvl) and not lvl.finished:
			Autopilot.drive(lvl, get_tree())
		if _debug and is_instance_valid(lvl) and fmod(t, 2.0) < dt and lvl.player:
			var p = lvl.player
			_info("  dbg t=%.0f pos=%s floor=%s vel=%s tgt=%s ctrl=%s seq=%s in=%d show=%s pend=%s" % [t, p.global_position, p.floor_found, p.velocity, p.autopilot_target, p.control_enabled, lvl.sequence_expected(), lvl._seq_input, lvl._seq_showing, lvl._seq_pending])
		if t - last_report > 30.0 and is_instance_valid(lvl):
			last_report = t
			_info("  t=%.0fs missions: %s  pos=%s hearts=%d" % [t, _mission_state(lvl), lvl.player.global_position, lvl.player.hearts])
	if not _finished:
		_fail("place %s did not finish in %.0fs; missions: %s" % [id, MAX_SCENE_SECONDS, _mission_state(lvl) if is_instance_valid(lvl) else "?"])
	else:
		_info("cleared %s in %.1fs (sim) / %.1fs (real)" % [id, t, (Time.get_ticks_msec() - t0) / 1000.0])
	await get_tree().process_frame


# ---------------------------------------------------------------- 6b. しょくどうの なみ
## しょくどう（peristalsis.gd）：
## ・GLB に たべものの かたまりが 無い。かたまりの いない 場面（場所だけ・ep03 の とおりみち）には かたまりが 出ない
## ・きんにくの わ（NC_Ring_*）が なみで しまる。なみに のると なみの はやさで はこばれる
## ・ep02：かたまりに ぶつかると なみから おちて ゆっくりに なる。ハートは へらない。つぎの なみに また のれる
## ・↑ を 押す だけで ゴールに つく（場所だけ・ep02）。かかった 時間を ログに 書く
func _check_esophagus() -> void:
	# 1. 場所だけ：かたまり なし、わが しまる、↑ だけで つく
	Game.start_stage("esophagus")
	var lvl = Game.level
	while not lvl.started:
		await get_tree().physics_frame
	var peri = lvl.peristalsis
	if peri == null:
		_fail("esophagus: なみ（peristalsis）が ない")
		return
	if lvl.env.find_child("FoodChunks", true, false) != null:
		_fail("esophagus: GLB に たべものの かたまり（FoodChunks）が のこって いる")
	if peri.lumps.size() != 0:
		_fail("esophagus: 場所だけ なのに かたまりが %d こ" % peri.lumps.size())
	if peri._rings.size() < 30:
		_fail("esophagus: きんにくの わが %d こ（30 こ いじょうの はず）" % peri._rings.size())
	var r := await _eso_forward(lvl, 60.0, "place")
	if not r["done"]:
		_fail("esophagus: ↑ だけで ゴールに つかない（%.1f 秒）" % r["t"])
	if r["squeezed"] < 0.05:
		_fail("esophagus: きんにくの わが しまらない（いちばん %.2f）" % r["squeezed"])
	if r["max_speed"] < peri.speed - 1.5 or r["rides"] < 1:
		_fail("esophagus: なみに のって はやく ならない（さいこう %.1f m/s、のった %d 回）" % [r["max_speed"], r["rides"]])
	# 2. ep03 の とおりみち：かたまり なし
	Game.start_episode("ep03", "scene", 1)
	lvl = Game.level
	while not lvl.started:
		await get_tree().physics_frame
	if lvl.peristalsis == null or lvl.peristalsis.lumps.size() != 0 or not lvl.is_pass():
		_fail("esophagus: ep03 の とおりみちに かたまりが ある（または なみが ない）")
	var r3 := await _eso_forward(lvl, 60.0, "ep03 pass")
	if not r3["done"] or r3["t"] > MAX_PASS_SECONDS or r3["t"] < 10.0:
		_fail("esophagus: ep03 の とおりみちを ↑ だけで %.1f 秒（10〜40 秒の はず）" % r3["t"])
	# 3. ep02：かたまりに ぶつかる
	Game.start_episode("ep02", "scene", 1)
	lvl = Game.level
	while not lvl.started:
		await get_tree().physics_frame
	peri = lvl.peristalsis
	if peri == null or peri.lumps.size() < 5:
		_fail("esophagus: ep02 に かたまりが ない")
		return
	var p = lvl.player
	# なみに のるまで ↑
	Input.action_press("move_up")
	var t := 0.0
	while not peri.riding and t < 12.0:
		Input.action_press("move_up")
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	if not peri.riding:
		_fail("esophagus: ep02 で 12 秒 たっても なみに のれない")
	# 船の すぐ 前に かたまりを おく（本物の 当たり判定で ぶつける）
	var lp = peri.lumps[0]
	var pp: float = lvl.path.progress_at(p.global_position)
	var smp: Dictionary = lvl.path.sample(pp)
	var dflat: Vector3 = smp["direction"]
	dflat.y = 0.0
	var right := dflat.normalized().cross(Vector3.UP)
	lp.prog = pp + 5.0
	lp.side = (p.global_position - (smp["position"] as Vector3)).dot(right)
	var hearts0: int = p.hearts
	var bumps0: int = peri.bumps
	t = 0.0
	while peri.bumps == bumps0 and t < 3.0:
		Input.action_press("move_up")
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	if peri.bumps == bumps0:
		_fail("esophagus: まえに おいた かたまりに ぶつからない")
	else:
		for i in 12:
			await get_tree().physics_frame
		var hv := Vector3(p.velocity.x, 0, p.velocity.z).length()
		_info("esophagus bump: 0.2 秒 あとの はやさ %.1f m/s、なみ %s、ハート %d → %d" % [hv, peri.riding, hearts0, p.hearts])
		if peri.riding or hv > 8.0:
			_fail("esophagus: ぶつかっても なみから おちない（はやさ %.1f m/s）" % hv)
		var t_back := 0.0
		while not peri.riding and t_back < 8.0:
			Input.action_press("move_up")
			await get_tree().physics_frame
			t_back += get_physics_process_delta_time()
		_info("esophagus bump: %.1f 秒で つぎの なみに のった" % t_back)
		if not peri.riding:
			_fail("esophagus: ぶつかった あと 8 秒 たっても なみに のれない")
	if p.hearts < hearts0 or lvl.damage_taken:
		_fail("esophagus: かたまりで ハートが へった")
	Input.action_release("move_up")
	# 4. ep02 を はじめから ↑ だけで（ものしりカード「food」も 見つかる：どの かたまりの そばでも）
	Game.start_episode("ep02", "scene", 1)
	lvl = Game.level
	while not lvl.started:
		await get_tree().physics_frame
	var food_before := SaveData.card_seen("esophagus", "food")
	var r2 := await _eso_forward(lvl, 120.0, "ep02")
	if not food_before and not SaveData.card_seen("esophagus", "food"):
		_fail("esophagus: ep02 を ↑ だけで いっても ものしりカード「food」が 見つからない")
	if lvl.peristalsis.ride_m > lvl.path.total + 1.0:
		_fail("esophagus: なみに のった きょり %.0f m が 道の 長さ %.0f m より 長い" % [lvl.peristalsis.ride_m, lvl.path.total])
	# 子どもに 見せる 数は 本物の しょくどうの 長さ（カードの「やく 25 cm」）に なおした センチ。ゲームの m は 出さない
	var peri2 = lvl.peristalsis
	var cm: int = peri2.ride_cm()
	var ct: String = peri2.clear_text("い（胃）の いりぐちに ついた！")
	_info("esophagus ep02: なみに のった %.0f m → 見せる 数 %d センチ（%s）、のった あとで 出さなかった ヒント %d" % [peri2.ride_m, cm, ct, lvl.hints_skipped])
	if cm < 1 or cm > int(peri2.body_cm):
		_fail("esophagus: 見せる きょり %d センチが 0 か しょくどうの 長さ %d センチより 長い" % [cm, int(peri2.body_cm)])
	if not ct.ends_with("%d センチ すすんだよ！" % cm):
		_fail("esophagus: クリアの ひとことが センチで ない：%s" % ct)
	if is_instance_valid(peri2._readout_label) and not String(peri2._readout_label.text).ends_with(" センチ"):
		_fail("esophagus: 左上の きょりが センチで ない：%s" % peri2._readout_label.text)
	if not r2["done"]:
		_fail("esophagus: ep02 を ↑ だけで ゴールに つかない（%.1f 秒）" % r2["t"])
	if r2["hurt"]:
		_fail("esophagus: ep02 を ↑ だけで いったら ハートが へった")
	# 5. きかんに 入れない・左の かべに はさまらない（場所だけ と ep03）
	for which in ["place", "ep03"]:
		if which == "place":
			Game.start_stage("esophagus")
		else:
			Game.start_episode("ep03", "scene", 1)
		lvl = Game.level
		while not lvl.started:
			await get_tree().physics_frame
		await _eso_left(lvl, which, ["move_left"], 6.0, [], 10.0)
		if which == "place":
			Game.start_stage("esophagus")
		else:
			Game.start_episode("ep03", "scene", 1)
		lvl = Game.level
		while not lvl.started:
			await get_tree().physics_frame
		await _eso_left(lvl, which + " ↑←", ["move_up", "move_left"], 40.0, [], 0.0)
	Game.unload_level()
	Game.show_title()
	await get_tree().process_frame


## a を sa 秒、b を sb 秒 押して から ↑ で ゴールまで。船が しょくどうの はば（かたがわ 7.2 m）から 出ない こと、
## スタートへ もどされない こと、さいごに つく こと
func _eso_left(lvl, tag: String, a: Array, sa: float, b: Array, sb: float) -> void:
	var p = lvl.player
	var t := 0.0
	var worst := 0.0
	var best := 0.0
	var jumped := false
	var phases := [[a, sa], [b, sb], [["move_up"], 60.0]]
	for ph in phases:
		var tt := 0.0
		while tt < float(ph[1]) and not lvl.finished:
			for act in ph[0]:
				Input.action_press(act)
			await get_tree().physics_frame
			var dt := get_physics_process_delta_time()
			tt += dt
			t += dt
			var pp: float = lvl.path.progress_at(p.global_position)
			var smp: Dictionary = lvl.path.sample(pp)
			var dd: Vector3 = smp["direction"]
			var right := Vector3(dd.x, 0.0, dd.z).normalized().cross(Vector3.UP)
			worst = maxf(worst, absf((p.global_position - (smp["position"] as Vector3)).dot(right)))
			if pp < best - 10.0:
				jumped = true
			best = maxf(best, pp)
		for act in ph[0]:
			Input.action_release(act)
	_info("esophagus %s: よこ いちばん %.1f m、%.1f 秒で %s%s" % [tag, worst, t, "ついた" if lvl.finished else "つかない", "（もどされた）" if jumped else ""])
	if worst > 7.2:
		_fail("esophagus %s: 船が しょくどうの そとへ（よこ %.1f m。きかんに 入った？）" % [tag, worst])
	if jumped:
		_fail("esophagus %s: はさまって うしろへ もどされた" % tag)
	if not lvl.finished:
		_fail("esophagus %s: さいごに ゴールに つかない（%.1f 秒）" % [tag, t])


## ↑ だけを 押して ゴールまで。{done, t, max_speed, rides, bumps, hurt, squeezed}
func _eso_forward(lvl, limit: float, tag: String) -> Dictionary:
	var peri = lvl.peristalsis
	var p = lvl.player
	var out := {"done": false, "t": 0.0, "max_speed": 0.0, "rides": 0, "bumps": 0, "hurt": false, "squeezed": 0.0}
	Input.action_press("move_up")
	var t := 0.0
	var next_log := 0.0
	var trace: Array[String] = []
	while t < limit and not lvl.finished:
		Input.action_press("move_up")   # ものしりカードの ポーズで はなされる（touch_controls.gd）ので まいかい 押す
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		var hv := Vector3(p.velocity.x, 0, p.velocity.z).length()
		out["max_speed"] = maxf(out["max_speed"], hv)
		for rr in peri._rings:
			out["squeezed"] = maxf(out["squeezed"], 1.0 - (rr["node"] as Node3D).global_transform.basis.get_scale().x / (rr["basis"] as Basis).get_scale().x)
		if t >= next_log:
			next_log += 1.0
			trace.append("%.0f:%.1f%s" % [t, hv, "W" if peri.riding else ""])
	Input.action_release("move_up")
	out["done"] = lvl.finished
	out["t"] = t
	out["rides"] = peri.ride_count
	out["bumps"] = peri.bumps
	out["hurt"] = lvl.damage_taken
	_info("esophagus %s: ↑ だけで %.1f 秒、なみに のった %d 回・%.0f m、かたまりに %d 回、ハート %d、さいこう %.1f m/s" % [tag, t, peri.ride_count, peri.ride_m, peri.bumps, p.hearts, out["max_speed"]])
	_info("  はやさ（秒:m/s、W ＝ なみに のって いる）%s" % " ".join(PackedStringArray(trace)))
	return out


# ---------------------------------------------------------------- 7. そうじゅう
## ひろい 場所の のりものの 操作（player.gd の is_steering）を 本物の アクションで 動かして 見る：
## ← 1 びょうで 船が ひだりへ 80〜140 ど まわり、その場から ほぼ 動かない。はなして 0.5 びょうで カメラが 船の うしろ（10 ど いない）。
## ↑ で 船の むきへ すすみ、↓ で うしろへ さがる（船も カメラも 向きが かわらない）
func _check_steering(id: String) -> void:
	Game.start_stage(id)
	var lvl = Game.level
	while not lvl.started:
		await get_tree().physics_frame
	for i in 30:
		await get_tree().physics_frame
	var p = lvl.player
	var cam = lvl.camera
	var where := "steer %s" % id
	if not p.is_steering():
		_fail("%s: のりものの 操作に なって いない" % where)
	# はじめての そうじゅうの てびき：まだ 見て いなければ 出る（キーボードの 絵）
	var guide = Game.hud.get_node_or_null("SteerGuide")
	var guide_first := not SaveData.steer_guide_seen()
	if guide_first:
		_check_guide(guide, false, where)
	elif guide != null:
		_fail("%s: 見おわった てびきが また 出た" % where)
	var flow := Vector3.ZERO
	if lvl.flow_speed > 0.0 and lvl.path.is_valid():
		flow = lvl.path.direction_at(p.global_position) * lvl.flow_speed   # ながれの ぶんは さしひく
	var y0: float = HoverBody.yaw_for(p.heading)
	var pos0: Vector3 = p.global_position
	await _hold(["move_left"], 1.0)
	await _hold([], 0.5)
	var turned := rad_to_deg(angle_difference(y0, HoverBody.yaw_for(p.heading)))
	var drift: Vector3 = p.global_position - pos0 - flow * 1.5
	drift.y = 0.0
	var cam_off := rad_to_deg(absf(angle_difference(cam.yaw, HoverBody.yaw_for(p.heading))))
	_info("%s: ← 1s で %.1f ど、ずれ %.2f m、カメラの おくれ %.1f ど" % [where, turned, drift.length(), cam_off])
	if turned < 80.0 or turned > 140.0:
		_fail("%s: ← 1 びょうで 船が %.1f ど まわった（80〜140 の はず）" % [where, turned])
	if drift.length() > 0.5:
		_fail("%s: その場で まわる はずが %.2f m 動いた" % [where, drift.length()])
	if cam_off > 10.0:
		_fail("%s: カメラが 船の うしろに ついて こない（%.1f ど ずれ）" % [where, cam_off])
	var h: Vector3 = p.heading
	var y1: float = HoverBody.yaw_for(h)
	pos0 = p.global_position
	await _hold(["move_up"], 0.6)
	var mv: Vector3 = p.global_position - pos0 - flow * 0.6
	mv.y = 0.0
	if mv.length() < 2.0 or mv.normalized().dot(h) < 0.8:
		_fail("%s: ↑ で 船の むきへ すすまない（%.2f m、むきとの ずれ dot=%.2f）" % [where, mv.length(), mv.normalized().dot(h) if mv.length() > 0.01 else 0.0])
	await _hold([], 0.4)
	pos0 = p.global_position
	await _hold(["move_down"], 0.8)
	mv = p.global_position - pos0 - flow * 0.8
	mv.y = 0.0
	var flip := rad_to_deg(absf(angle_difference(y1, HoverBody.yaw_for(p.heading))))
	var cam_flip := rad_to_deg(absf(angle_difference(y1, cam.yaw)))
	if mv.length() < 1.0 or mv.normalized().dot(-h) < 0.8:
		_fail("%s: ↓ で うしろへ さがらない（%.2f m）" % [where, mv.length()])
	if flip > 2.0 or cam_flip > 3.0:
		_fail("%s: ↓ で 船（%.1f ど）か カメラ（%.1f ど）が まわった" % [where, flip, cam_flip])
	await _hold([], 0.2)
	if guide_first and (not SaveData.steer_guide_seen() or (is_instance_valid(guide) and not guide.is_closing())):
		_fail("%s: まわって すすんでも てびきが 消えない" % where)
	Game.unload_level()
	await get_tree().process_frame
	if guide_first:
		await _check_guide_touch()


## そうじゅうの てびき：出て いる・文の きまり・ピコの ふきだしにも ミクロごうにも かからない
func _check_guide(guide, touch: bool, where: String) -> void:
	if guide == null or not guide.is_visible_in_tree():
		_fail("%s: はじめての ひろい 場所で そうじゅうの てびきが 出ない" % where)
		return
	if guide.touch != touch:
		_fail("%s: てびきの 絵が %s で ない" % [where, "タッチ" if touch else "キーボード"])
	for t in guide.texts():
		for pr in EpisodeDB.text_problems(t):
			_fail("%s: てびきの 文「%s」: %s" % [where, t, pr])
	_check_texts(guide, where + " てびき")
	_check_layout(guide, where + " てびき")
	var r: Rect2 = guide.get_global_rect()
	var view := get_viewport().get_visible_rect().size
	var msg := Rect2(view.x * 0.5 - 430.0, view.y - 200.0, 860.0, 174.0)   # ピコの ふきだし（いちばん ひろい とき。hud.gd）
	if r.intersects(msg):
		_fail("%s: てびきが ピコの ふきだしに かかる（%s）" % [where, r])
	var lvl = Game.level
	var ship: Vector2 = get_viewport().get_camera_3d().unproject_position(lvl.player.global_position)
	if r.grow(40.0).has_point(ship):
		_fail("%s: てびきが ミクロごうに かかる" % where)
	if Game.touch_controls != null and Game.touch_controls.visible and r.intersects(Rect2(Vector2(150, view.y - 150) - Vector2(100, 100), Vector2(200, 200))):
		_fail("%s: てびきが タッチの スティックに かかる" % where)


## タッチの とき：てびきは タッチの 絵。スティックで まわる・すすむ（タッチそうさも 同じ アクション）で 消える
func _check_guide_touch() -> void:
	var before = SaveData.setting("touch", "auto")
	SaveData.data["steer_guide_seen"] = false
	SaveData.set_setting("touch", "on")
	Game.start_stage("mouth")
	var lvl = Game.level
	while not lvl.started:
		await get_tree().physics_frame
	for i in 10:
		await get_tree().physics_frame
	var guide = Game.hud.get_node_or_null("SteerGuide")
	_check_guide(guide, true, "steer guide touch")
	await _hold(["move_right"], 0.3)
	if SaveData.steer_guide_seen():
		_fail("steer guide touch: まわった だけで 消えた（すすむ も やる まで のこす）")
	await _hold(["move_up"], 0.3)
	if not SaveData.steer_guide_seen() or (is_instance_valid(guide) and not guide.is_closing()):
		_fail("steer guide touch: まわって すすんでも 消えない")
	Game.unload_level()
	SaveData.set_setting("touch", before)
	await get_tree().process_frame


## actions を sec びょう 押しつづける（物理フレームで 数える）
func _hold(actions: Array, sec: float) -> void:
	for a in actions:
		Input.action_press(a)
	var t := 0.0
	while t < sec - 0.0001:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	for a in actions:
		Input.action_release(a)


# ---------------------------------------------------------------- 8. いえきの いけ
## いけの 見た目と あぶない ところが 合うか（い（胃）の 3 つの いけ、8 方向ずつ）：
##   見た目：まんなかから 外へ ゆかを 下向きに しらべ、ゆか（ふち）が 水面より 上に 出る きょり ＝ 水の ふち
##   あぶない：ミクロごうを 外へ ずらしながら 置き、いけの 当たりに 入って いるか。入らなく なる きょり ＝ あぶない ふち
## どちらも マーカー名の 半径 r から 0.15 m 以内。ちがえば「水が 見えない 所で ハートが へる」か「水の 中で へらない」
func _check_pools() -> void:
	Game.start_stage("stomach")
	var lvl = Game.level
	while not lvl.started:
		await get_tree().physics_frame
	var p = lvl.player
	p.control_enabled = false
	p.invulnerable = 9999.0
	# 光る 黄色は ゴールだけ（いけの 水は 光らない。ゴールと まちがえない ように）。
	# ミクロごうの やじるし（どの 場所でも つぎの 行き先を さす）は 場所の ものでは ないので 数えない
	var glowing: Array[String] = []
	for g in lvl.find_children("*", "GeometryInstance3D", true, false):
		if lvl.goal != null and (g == lvl.goal or lvl.goal.is_ancestor_of(g)):
			continue
		if lvl.player != null and lvl.player.is_ancestor_of(g):
			continue
		var mats: Array = [g.material_override]
		if g is MeshInstance3D and g.mesh != null:
			for i in g.mesh.get_surface_count():
				mats.append(g.get_surface_override_material(i))
				mats.append(g.mesh.surface_get_material(i))
		for m in mats:
			if m is StandardMaterial3D and m.emission_enabled:
				var e: Color = m.emission
				if e.s > 0.4 and e.h > 0.08 and e.h < 0.2 and e.v > 0.5:
					glowing.append(String(lvl.get_path_to(g)))
			elif m is ShaderMaterial and m.shader == StageLook.GlowShader:
				var c: Color = m.get_shader_parameter("tint")
				if c.s > 0.4 and c.h > 0.08 and c.h < 0.2:
					glowing.append(String(lvl.get_path_to(g)))
	if not glowing.is_empty():
		_fail("pools: ゴールの ほかに 光る 黄色が ある：%s" % ", ".join(PackedStringArray(glowing)))
	var space: PhysicsDirectSpaceState3D = lvl.get_world_3d().direct_space_state
	var pools: Array = []
	for n in lvl.get_children():
		if n is HazardPool:
			pools.append(n)
	if pools.size() != 3:
		_fail("pools: い（胃）の いけが %d こ（3 この はず）" % pools.size())
	for h in pools:
		var c: Vector3 = h.global_position
		var r: float = h.radius
		var worst_geo := 0.0
		var worst_hurt := 0.0
		for k in 8:
			var dir := Vector3(cos(TAU * k / 8.0), 0.0, sin(TAU * k / 8.0))
			# 見た目の ふち
			var geo := INF
			var d := r - 0.6
			while d <= r + 0.6:
				var at := c + dir * d
				var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 4.0, 1)
				var hit := space.intersect_ray(q)
				if not hit.is_empty() and hit["position"].y > c.y:
					geo = d
					break
				d += 0.02
			# あぶない ふち
			var hurt_edge := INF
			d = r - 0.6
			while d <= r + 0.6:
				p.global_position = c + dir * d + Vector3.UP * 1.2
				p.velocity = Vector3.ZERO
				await get_tree().physics_frame
				await get_tree().physics_frame
				if not p.hitbox.get_overlapping_areas().has(h):
					hurt_edge = d
					break
				d += 0.05
			worst_geo = maxf(worst_geo, absf(geo - r))
			worst_hurt = maxf(worst_hurt, absf(hurt_edge - r))
		_info("pool r%.0f at %s: 水の ふち と r の ずれ 最大 %.2f m、あぶない ふち と r の ずれ 最大 %.2f m" % [r, c, worst_geo, worst_hurt])
		if worst_geo > 0.15:
			_fail("pool r%.0f: 水の ふちが r から %.2f m ずれる" % [r, worst_geo])
		if worst_hurt > 0.15:
			_fail("pool r%.0f: あぶない ふちが r から %.2f m ずれる（水が 見えない 所で へる／水の 中で へらない）" % [r, worst_hurt])
	await get_tree().process_frame


# ---------------------------------------------------------------- 9. はさまった ときの もどし
## ひろい 場所で ↓ を 12 びょう 押しつづける（うしろの かべに はさまり、もどしが 2 回 はたらく）。
## 船は へやの 中に いる こと：下に 上向きの ゆかが あり、スタートより 6 m いじょう 下へ おちて いない。
## （前は もどしが かべの 外へ 3 m うごかし、船が へやの 下へ おちて いた）
## はさまった ときの もどし（player._free_step）：どの むきへ 40 m たのんでも、かべを こえず、行き先の 下に ゆかが ある
func _check_free_step(p, where: String) -> void:
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var from: Vector3 = p.global_position + Vector3.UP * 0.5
	var moved := 0
	for i in 16:
		var d := Vector3(cos(TAU * i / 16.0), 0.0, sin(TAU * i / 16.0))
		var step: float = p._free_step(d, 40.0)
		if step <= 0.0:
			continue
		moved += 1
		var to: Vector3 = from + d * step
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		if not hit.is_empty():
			_fail("%s: もどし %.1f m が かべを こえる（むき %d）" % [where, step, i])
			continue
		var g: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(to, to + Vector3.DOWN * 12.0, 1))
		if g.is_empty() or (g["normal"] as Vector3).y < 0.3:
			_fail("%s: もどし %.1f m の 行き先に ゆかが ない（むき %d）" % [where, step, i])
	if moved == 0:
		_fail("%s: もどしが どの むきにも うごかない" % where)


func _check_back_hold(id: String) -> void:
	Game.start_stage(id)
	var lvl = Game.level
	while not lvl.started:
		await get_tree().physics_frame
	for i in 30:
		await get_tree().physics_frame
	var p = lvl.player
	var where := "back hold %s" % id
	var tube: bool = String(lvl.stage.get("kind", "arena")) == "tube"
	_check_free_step(p, where)
	var y0: float = p.global_position.y
	var low := 0.0
	var no_floor := 0
	var rescues := 0
	var last: Vector3 = p.global_position
	var t := 0.0
	Input.action_press("move_down")
	while t < 12.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		low = minf(low, p.global_position.y - y0)
		if p.global_position.distance_to(last) > 0.45:   # 1 フレームで とんだ ＝ もどしが はたらいた
			rescues += 1
		last = p.global_position
		var from: Vector3 = p.global_position + Vector3.UP * 0.5
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 12.0, 1)
		var g: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
		if g.is_empty() or (g["normal"] as Vector3).y < 0.3:
			no_floor += 1
	Input.action_release("move_down")
	_info("%s: ↓ 12 びょうで もどし %d 回、いちばん 下 %.1f m、ゆかが ない フレーム %d" % [where, rescues, low, no_floor])
	# ひろい 場所では かべに おしつけて もどしが はたらく。くだでは はじめで とまる（もどしは なくて よい）
	if rescues == 0 and not tube:
		_fail("%s: もどしが 1 回も はたらかなかった（この テストが 何も 見て いない）" % where)
	if low < -6.0:
		_fail("%s: 船が スタートより %.1f m 下へ おちた（へやの 外）" % [where, -low])
	if no_floor > 5:
		_fail("%s: 船の 下に ゆかが ない フレームが %d（へやの 外）" % [where, no_floor])
	Game.unload_level()
	await get_tree().process_frame
