extends Node
const Autopilot := preload("res://tests/autopilot.gd")
## スクリーンショット撮影（ソフトウェアレンダリング用）
##   xvfb-run godot --rendering-driver opengl3 --path godot res://tests/shot.tscn -- --stage=mouth --out=/tmp/x.png
## --stage=title / select / zukan / <stage id>。--frames=N で待つフレーム数。--play=秒 で自動操縦してから撮る。

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
	SaveData.set_setting("volume", 0.0)
	SaveData.set_setting("unlock_all", true)
	SaveData.set_setting("touch", "on" if touch else "off")
	if stage == "title":
		Game.show_title()
	elif stage == "select":
		Game.show_stage_select()
	elif stage == "zukan":
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
	elif stage == "result":
		Game.start_stage("lungs")
		var waited := 0
		while (Game.level == null or not Game.level.started) and waited < 600:
			await get_tree().process_frame
			waited += 1
		Game.testing = false
		Game.level.damage_taken = true
		Game.level.finish()
		for i in 60:
			await get_tree().process_frame
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
	get_tree().quit()


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
