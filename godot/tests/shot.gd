extends Node
const Autopilot := preload("res://tests/autopilot.gd")
## スクリーンショット撮影（ソフトウェアレンダリング用）
##   xvfb-run godot --rendering-driver opengl3 --path godot res://tests/shot.tscn -- --stage=mouth --out=/tmp/x.png
## --frames=N で待つフレーム数。--play=秒 で自動操縦してから撮る。--touch で タッチそうさの 見た目。
## --stage= に 書ける もの（「,」で ならべると 1 回の 起動で 何枚も 撮る。その ときの --out= は フォルダ。
## ファイル名は「:」「+」を「_」に した もの）：
##   title / zukan / card / card:<場所 id>:<カードの キー>（card:mouth:mushiba） / pause / model:<キャラクター id>
##   select_new        カルテえらび（はじめて：ep01 だけ 開いて いる）
##   select            カルテえらび（ep01 クリアずみ・ep02 が 開いた 状態）
##   resume            カルテえらび（クリアずみの ep02 を 遊びなおして 場面 1 まで おえた 状態：ボタンが いちばん 多い）
##   opening           はじめての そうだん（OPENING の ページ）
##   consult:ep03      そうだん
##   guess:ep03        よそう
##   guess_wrong:ep01  はずれを 1 回 えらんだ あと
##   guess_go:ep01     go の えらびを 押した あと（しゅっぱつの 箱）。+hit で「あたり」の えらびを 押す
##   after:ep03:0      場面 0 の あとの はなし
##   karte:ep03[:n]    カルテ画面の 段 0（n ＝ 1 紙／2 クイズ／3 ほし）
##   review:ep02[:n]   クリアずみの カルテの 読みかえし（紙から。n ＝ 1 クイズ／2 ほし）
##   zukan_karte:ep02  ずかんで カルテを 開いた ところ
##   ep03:1            3 話の 2 つめの 場面（＋ --play=秒）
##   <場所 id>         場所だけを 既定の ミッションで（＋ --play=秒）
## 1 枚ごとの しるし（「+」で つなぐ。例：after:ep03:0+hit+p1、karte:ep02:3+wrong+hurt、guess:ep01+touch）：
##   +p<N>   はなしの N ページ目（0 から）      +hit    さいしょの よそうが あたり だった 子
##   +wrong  クイズで はずれを えらぶ            +hurt   ハートが へった 場面が ある（2 つめ。1 場面の 話は 1 つめ）
##   +touch  タッチそうさ（--touch と 同じ）
## セーブは user://save_shot.json を 使う（本物の セーブを さわらない）。

var _frames := 60
var _play := 0.0


func _ready() -> void:
	var stages := "mouth"
	var out := "/tmp/shot.png"
	var touch := false
	for a in OS.get_cmdline_user_args():
		if a == "--touch":
			touch = true
		if a.begins_with("--stage="):
			stages = a.substr(8)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--frames="):
			_frames = int(a.substr(9))
		elif a.begins_with("--play="):
			_play = float(a.substr(7))
	Game.testing = true
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	SaveData.use_path("user://save_shot.json")
	var list := stages.split(",", false)
	var to_dir := list.size() > 1 or out.ends_with("/")
	if to_dir:
		DirAccess.make_dir_recursive_absolute(out)
	var code := 0
	for item in list:
		var flags := item.split("+")
		var stage := flags[0]
		flags.remove_at(0)
		_reset(touch or flags.has("touch"))
		if not await _setup(stage, flags):
			code = 1
			continue
		for i in _frames:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var file := out.path_join(item.replace(":", "_").replace("+", "_") + ".png") if to_dir else out
		img.save_png(file)
		print("saved ", file, " ", img.get_size())
		await _close_overlays()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	get_tree().quit(code)


func _reset(touch: bool) -> void:
	Game.testing = true
	SaveData.reset()
	SaveData.set_setting("volume", 0.0)
	SaveData.set_setting("touch", "on" if touch else "off")
	SaveData.data["opening_seen"] = true


## カード・ポーズを とじる（次の 1 枚に のこさない）
func _close_overlays() -> void:
	if Game.overlay_layer.get_node_or_null("PauseMenu") != null:
		Game.toggle_pause()
	for c in Game.overlay_layer.get_children():
		if c.has_method("close"):
			c.close()
	for i in 20:
		await get_tree().process_frame


## さいしょの「あたり」の えらび（無ければ ""）
func _hit_place(ep_id: String) -> String:
	for c in EpisodeDB.get_episode(ep_id).get("guess", {}).get("choices", []):
		if c.get("hit", false):
			return c["place"]
	return ""


## stage の 画面を 出す。出せたら true
func _setup(stage: String, flags: PackedStringArray) -> bool:
	# 「mode:epNN:番号」（consult:ep03、after:ep03:0）か「epNN:場面の 番号」（ep03:1）
	var parts := stage.split(":")
	var mode := parts[0]
	var is_scene := EpisodeDB.ids().has(mode)
	var ep_id := mode if is_scene else (parts[1] if parts.size() > 1 else "ep01")
	var num := int(parts[1 if is_scene else 2]) if parts.size() > (1 if is_scene else 2) else 0
	if mode != "model" and mode != "card" and not EpisodeDB.ids().has(ep_id):
		push_error("unknown episode: %s" % ep_id)
		return false
	var page := 0
	for f in flags:
		if f.begins_with("p") and f.substr(1).is_valid_int():
			page = int(f.substr(1))
	var guess := _hit_place(ep_id) if flags.has("hit") else ""
	if stage == "title":
		Game.show_title()
	elif stage == "select_new":
		Game.show_episode_select()
	elif stage == "select":
		SaveData.record_scene("ep01", 0, true)
		SaveData.record_clear("ep01")
		Game.show_episode_select()
	elif stage == "resume":
		SaveData.record_clear("ep01")
		SaveData.record_clear("ep02")
		SaveData.set_resume("ep02", 1, "stomach")
		Game.show_episode_select()
	elif stage == "opening":
		SaveData.data["opening_seen"] = false
		Game.start_episode("ep01")
	elif mode == "consult":
		Game.start_episode(ep_id)
		await _press(page)
	elif mode == "guess" or mode == "guess_wrong" or mode == "guess_go":
		Game.start_episode(ep_id, "guess")
		if mode != "guess":
			await _wait_unlocked()
			# guess_go+hit は「あたり」の えらび（3 話の しょうちょう：あたりだが、先に い（胃）を 見に 行く）
			for c in EpisodeDB.get_episode(ep_id)["guess"]["choices"]:
				if c.get("go", false) == (mode == "guess_go") and (guess == "" or c["place"] == guess):
					Game.screen().choose(c["place"])
					break
	elif mode == "after":
		Game.start_episode(ep_id, "after", num, guess)
		await _press(page)
	elif mode == "karte" or mode == "review":
		var n_scenes := EpisodeDB.scene_count(ep_id)
		for i in n_scenes:
			SaveData.record_scene(ep_id, i, not (flags.has("hurt") and i == mini(1, n_scenes - 1)))
		if mode == "review":
			SaveData.record_clear(ep_id)
			Game.review_karte(ep_id)
		else:
			Game.start_episode(ep_id, "karte", 0, guess)
		for n in num:
			await _wait_unlocked()
			var k := Game.screen()
			if k.step == 2:
				# クイズ：正解（+wrong なら はずれ）を えらぶ
				var pick: int = k.quiz_answer if not flags.has("wrong") else (k.quiz_answer + 1) % k.quiz_buttons.size()
				k.quiz_buttons[pick].pressed.emit()
			else:
				await _press(1)
	elif stage == "zukan" or mode == "zukan_karte":
		for id in ["ep01", "ep02", "ep03"] if mode == "zukan_karte" else ["ep01", "ep02"]:
			SaveData.record_clear(id)
			SaveData.mark_card(id, "karte")
		for sid in ["mouth", "esophagus", "stomach"]:
			for key in StageDB.get_stage(sid)["cards"].keys():
				SaveData.mark_card(sid, key)
		Game.show_zukan()
		if mode == "zukan_karte":
			await get_tree().process_frame
			Game.screen().karte_buttons[ep_id].pressed.emit()
			await get_tree().create_timer(0.9, true).timeout   # 「わかった！」が 押せる ように なる まで
	elif stage.begins_with("model:"):
		# キャラクターモデルを 大きく 1 体だけ映す（Blender の作り直し確認用）
		_show_model(stage.substr(6))
	elif stage == "card" or stage.begins_with("card:"):
		# card:mouth:mushiba のように 場所と カードの キーを 書くと その カード（キャラクターの 3D の 絵つき）
		var cp := (stage + ":stomach:stage").split(":") if stage == "card" else stage.split(":")
		Game.testing = false  # カードを自動で閉じない
		Game.start_stage(cp[1])
		Game.show_card(StageDB.card(cp[1], cp[2]), Callable(), cp[2], cp[1])
		await get_tree().create_timer(0.9, true).timeout   # 「わかった！」が 押せる ように なる まで
	elif stage == "pause":
		# 場面 2 の とちゅうで ポーズ（おえた 場面が あるので「つづきから できるよ」が 出る）
		SaveData.set_resume("ep02", 1, "stomach")
		Game.start_episode("ep02", "scene", 1)
		for i in 30:
			await get_tree().process_frame
		Game.toggle_pause()
	else:
		if is_scene:
			Game.start_episode(ep_id, "scene", num)
		else:
			Game.start_stage(stage)
		var waited := 0
		while (Game.level == null or not Game.level.started) and waited < 600:
			await get_tree().process_frame
			waited += 1
		if _play > 0.0 and Game.level:
			var t := 0.0
			while t < _play and Game.level and not Game.level.finished:
				await get_tree().physics_frame
				t += get_physics_process_delta_time()
				var lvl = Game.level
				Autopilot.drive(lvl, get_tree())
	return true


## 画面の 押しすぎ よけ（flow_screen.gd の lock）が とける まで 待つ
func _wait_unlocked() -> void:
	for i in 600:
		await get_tree().process_frame
		var scr := Game.screen()
		if scr != null and scr.has_method("locked") and not scr.locked():
			return


## フォーカス中の ボタンを n 回 押す（はなしの ページ送り・カルテの 段送り）
func _press(n: int) -> void:
	for i in n:
		await _wait_unlocked()
		var fo := get_viewport().gui_get_focus_owner()
		if fo is BaseButton:
			fo.pressed.emit()


func _show_model(name: String) -> void:
	var root := Node3D.new()
	Game.world.add_child(root)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.93, 0.95, 1.0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 0.95)
	e.ambient_light_energy = 0.8
	we.environment = e
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 0.9
	root.add_child(sun)
	var model := ModelLib.character(name, 0.7)
	ModelLib.fit(model, 1.0)
	model.rotation.y = deg_to_rad(35)
	root.add_child(model)
	var floor_mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.6
	cm.bottom_radius = 1.6
	cm.height = 0.05
	floor_mi.mesh = cm
	floor_mi.position = Vector3(0, -1.05, 0)
	floor_mi.material_override = ModelLib.flat_material(Color(0.85, 0.88, 0.95))
	root.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.9, -3.4)
	cam.look_at_from_position(cam.position, Vector3(0, 0, 0), Vector3.UP)
	cam.fov = 40
	root.add_child(cam)
	cam.current = true
