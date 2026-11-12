extends Node
## 自動テスト（ヘッドレス）。
##   godot --headless --fixed-fps 60 --path godot res://tests/smoke.tscn [-- --episode=ep03 | --stage=mouth] [--debug]
## 1. src/ の 全スクリプトを 読みこむ
## 2. データを 調べる（EpisodeDB.validate ＋ 文が 箱に 入るか ＋ spawn の ルール）
## 3. セーブを 調べる（v1 からの 移行・こわれた ファイル・ほし・つづき）
## 4. 全カルテを カルテえらび → そうだん → よそう → 場面 → カルテ まで 通す
##    （画面は フォーカス中の ボタンを 押す ＝「いつも フォーカスが ある」ことも 見る。場面は 自動操縦）
## 5. タイトル、よそうの「もどる」、あたりの よそう、つづきから（場面の やりなおし・ポーズから やめる）、クイズの やりなおし、ずかん
## 6. 全部の 場所を 既定の ミッションで 自動操縦（カルテで まだ 使わない 場所も ここで 守る）
## --episode= は 4 を その 話だけ、--stage= は 6 を その 場所だけ 回す（5 は 全部 回す ときだけ）。
## セーブは user://save_test.json を 使う（本物の セーブを さわらない）。

const MAX_SCENE_SECONDS := 420.0
const MAX_UI_SECONDS := 30.0
## 物語の ひとことは 出てから 2 秒 上書きされない（level.gd の say_story）。その 間を フレームで 数える（少し 短めに 見る）
const HOLD_FRAMES := 110
const Autopilot := preload("res://tests/autopilot.gd")
const SelectScreen := preload("res://src/ui/episode_select.gd")
const TalkScreen := preload("res://src/ui/talk.gd")
const GuessScreen := preload("res://src/ui/guess.gd")
const KarteScreen := preload("res://src/ui/karte.gd")
const TitleScreen := preload("res://src/ui/title.gd")
const ZukanScreen := preload("res://src/ui/zukan.gd")
const KarteSheet := preload("res://src/ui/karte_sheet.gd")

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
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	_check_scripts()
	_check_data()
	_check_spawn_rules()
	await _check_sheets()
	_check_save()
	SaveData.reset()
	SaveData.set_setting("volume", 0.0)
	Game.phase_changed.connect(func(p: String, i: int): _phases.append("%s%s" % [p, str(i) if p in ["scene", "after"] else ""]))
	# episode_finished の しゅんかんの フェーズ列を 写す（「つぎの カルテへ」は すぐ 次の 話の consult を 出すので）
	Game.episode_finished.connect(func(_id, _stars):
		_ep_done = true
		_phases_at_end = _phases.duplicate())
	Game.stage_started.connect(func(_sid): _said.clear())
	Game.said.connect(_on_said)
	Game.stage_finished.connect(func(sid: String, _stars):
		_scene_clears += 1
		_finished = true
		if not Game.episode.is_empty():
			_info("  scene %d (%s) done" % [Game.scene_index, sid])
			_check_says())
	# データに まちがいが あっても 先へ 進む（まちがった データでも 子どもが 詰まらない ことを 見る）
	if args_ok:
		if _only_place == "":
			for id in EpisodeDB.ids():
				if _only_ep == "" or id == _only_ep:
					await _run_episode(id)
		if _only_place == "" and _only_ep == "":
			await _check_title()
			await _check_back()
			await _check_hit()
			await _check_resume()
			await _check_zukan()
		if _only_ep == "":
			for id in StageDB.stage_ids():
				if _only_place == "" or id == _only_place:
					await _run_place(id)
	_remove_test_saves()
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
			if not GuessScreen.depart_fits(ep["guess"]["depart"]):
				_fail("%s: depart が 箱に 入らない" % id)
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
	_info("episodes: %d, places: %d" % [EpisodeDB.EPISODES.size(), StageDB.STAGES.size()])


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


# ---------------------------------------------------------------- 4. カルテ
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


## root の 下に 出ている 文（ラベルと ボタン）を 文の きまりで 調べる。画面の 決まり文句も ここで 守られる
func _check_texts(root: Control, where: String) -> void:
	for n in root.find_children("*", "Control", true, false):
		if (n is Label or n is Button) and n.is_visible_in_tree() and n.text != "" and not _text_seen.has(n.text):
			_text_seen[n.text] = true
			for p in EpisodeDB.text_problems(n.text):
				_fail("%s: 画面の 文「%s」: %s" % [where, n.text, p])


## 画面の 文と、はみ出し（fits() が ある 画面）を 調べる
func _check_screen(scr: Control, where: String) -> void:
	_check_texts(scr, where)
	if scr.has_method("fits") and not scr.fits():
		_fail("%s: 中身が 箱から はみ出して いる" % where)


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
	var sc: Dictionary = Game.episode["scenes"][Game.scene_index]
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
		if not texts.has(t):
			_fail("%s: HUD に 出なかった：%s" % [where, t])
	if has_work and sc.has("goal_say"):
		var i := texts.find(sc["goal_say"])
		var j := i + 1
		while i >= 0 and j < _said.size() and _said[j][0] - _said[i][0] < HOLD_FRAMES:
			if _said[j][1] != sc.get("clear_say", "クリア！"):
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
				for p in lvl.stage.get("spawn", {}).get("skip", []):
					for m in lvl.markers:
						if m["node"] != null and Level.spawn_rule_matches(String(m["node"].name).substr(3), p):
							_fail("%s: skip が きいていない: %s" % [id, m["node"].name])
			if lvl.started and not lvl.finished:
				Autopilot.drive(lvl, get_tree())
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
	if _ep_done:
		_info("cleared %s in %.1fs (sim) / %.1fs (real); scenes=%d stars=%d" % [id, total, (Time.get_ticks_msec() - t0) / 1000.0, _scene_clears, SaveData.stars(id)])
		if _phases_at_end != expect:
			_fail("%s: phases %s != %s" % [id, _phases_at_end, expect])
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
	if not await _play_until(func(): return Game.phase == "scene" and Game.level != null and Game.level.started, MAX_UI_SECONDS, "resume"):
		_fail("resume: つづきから 場面に 入れない（%s）" % Game.phase)
		return
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
	Game.review_karte(id)
	if Game.phase != "karte" or SaveData.resume().get("ep", "") != id:
		_fail("resume: review_karte が つづきを 消した")
	if not await _play_until(func(): return Game.screen() is SelectScreen, MAX_UI_SECONDS, "review"):
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
	_check_texts(scr, "zukan")
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
		scr.popup.button().pressed.emit()
		t = 0.0
		while t < 5.0 and scr.popup != null:
			await get_tree().process_frame
			t += get_process_delta_time()
		if get_viewport().gui_get_focus_owner() != b:
			_fail("zukan: カードを 閉じた あと フォーカスが もどらない（%s）" % id)
	if first:
		_fail("zukan: 見た カルテが 1 つも ない")


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
	_finished = false
	var t := 0.0
	var last_report := 0.0
	while not _finished and t < MAX_SCENE_SECONDS:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
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
