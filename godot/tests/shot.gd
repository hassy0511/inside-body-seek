extends Node
const Autopilot := preload("res://tests/autopilot.gd")
## スクリーンショット撮影（ソフトウェアレンダリング用）
##   xvfb-run godot --rendering-driver opengl3 --path godot res://tests/shot.tscn -- --stage=mouth --out=/tmp/x.png
## --frames=N で待つフレーム数。--play=秒 で自動操縦してから撮る。--touch で タッチそうさの 見た目。
## --stage= に 書ける もの：
##   title / zukan / card / pause / model:<キャラクター id>
##   select            カルテえらび（ep01 クリアずみ・ep02 が 開いた 状態）
##   resume            カルテえらび（クリアずみの ep02 を 遊びなおして 場面 1 まで おえた 状態：ボタンが いちばん 多い）
##   opening           はじめての そうだん（OPENING の ページ）
##   consult:ep03      そうだん
##   guess:ep03        よそう
##   guess_wrong:ep01  はずれを 1 回 えらんだ あと
##   guess_go:ep01     go の えらびを 押した あと（しゅっぱつの 箱）
##   after:ep03:0      場面 0 の あとの はなし
##   karte:ep03[:n]    カルテ画面の 段 0（n ＝ 1 紙／2 クイズ／3 ほし：主ボタンを n 回 押す）
##   ep03:1            3 話の 2 つめの 場面（＋ --play=秒）
##   <場所 id>         場所だけを 既定の ミッションで（＋ --play=秒）
## セーブは user://save_shot.json を 使う（本物の セーブを さわらない）。

func _ready() -> void:
	var stage := "mouth"
	var out := "/tmp/shot.png"
	var frames := 60
	var play := 0.0
	var touch := false
	for a in OS.get_cmdline_user_args():
		if a == "--touch":
			touch = true
		if a.begins_with("--stage="):
			stage = a.substr(8)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
		elif a.begins_with("--play="):
			play = float(a.substr(7))
	Game.testing = true
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	SaveData.use_path("user://save_shot.json")
	SaveData.reset()
	SaveData.set_setting("volume", 0.0)
	SaveData.set_setting("touch", "on" if touch else "off")
	SaveData.data["opening_seen"] = true
	# 「mode:epNN:番号」（consult:ep03、after:ep03:0）か「epNN:場面の 番号」（ep03:1）
	var parts := stage.split(":")
	var mode := parts[0]
	var is_scene := EpisodeDB.ids().has(mode)
	var ep_id := mode if is_scene else (parts[1] if parts.size() > 1 else "ep01")
	var num := int(parts[1 if is_scene else 2]) if parts.size() > (1 if is_scene else 2) else 0
	if mode != "model" and not EpisodeDB.ids().has(ep_id):
		push_error("unknown episode: %s" % ep_id)
		get_tree().quit(1)
		return
	if stage == "title":
		Game.show_title()
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
	elif mode == "guess" or mode == "guess_wrong" or mode == "guess_go":
		Game.start_episode(ep_id, "guess")
		if mode != "guess":
			await _wait_unlocked()
			for c in EpisodeDB.get_episode(ep_id)["guess"]["choices"]:
				if c.get("go", false) == (mode == "guess_go"):
					Game.screen().choose(c["place"])
					break
	elif mode == "after":
		Game.start_episode(ep_id, "after", num)
	elif mode == "karte":
		Game.start_episode(ep_id, "karte")
		for n in num:
			await _wait_unlocked()
			var fo := get_viewport().gui_get_focus_owner()
			if fo is BaseButton:
				fo.pressed.emit()
	elif stage == "zukan":
		for id in ["ep01", "ep02"]:
			SaveData.record_clear(id)
			SaveData.mark_card(id, "karte")
		for sid in ["mouth", "esophagus", "stomach"]:
			for key in StageDB.get_stage(sid)["cards"].keys():
				SaveData.mark_card(sid, key)
		Game.show_zukan()
	elif stage.begins_with("model:"):
		# キャラクターモデルを 大きく 1 体だけ映す（Blender の作り直し確認用）
		_show_model(stage.substr(6))
	elif stage == "card":
		Game.testing = false  # カードを自動で閉じない
		Game.start_stage("stomach")
		Game.show_card(StageDB.card("stomach", "stage"), Callable(), "stage", "stomach")
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
		if play > 0.0 and Game.level:
			var t := 0.0
			while t < play and Game.level and not Game.level.finished:
				await get_tree().physics_frame
				t += get_physics_process_delta_time()
				var lvl = Game.level
				Autopilot.drive(lvl, get_tree())
	for i in frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	get_tree().quit()


## 画面の 押しすぎ よけ（flow_screen.gd の lock）が とける まで 待つ
func _wait_unlocked() -> void:
	for i in 600:
		await get_tree().process_frame
		var scr := Game.screen()
		if scr != null and scr.has_method("locked") and not scr.locked():
			return


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
