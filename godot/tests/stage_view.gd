extends Node
const Autopilot := preload("res://tests/autopilot.gd")
## 場所の 見た目を 作る ときの 撮影（HUD なし・すきな 位置の カメラ）。ソフトウェアレンダリング用。
##   xvfb-run godot --rendering-driver opengl3 --resolution 1280x720 --path godot res://tests/stage_view.tscn -- \
##     --stage=mouth --out=/tmp/v/ "--views=start;top:0,0,60>0,0,0@50;back:0,20,0>0,-30,2"
## --views= は「;」で ならべる。座標は Blender の 向き（x 右・y おく・z 上）で 書く。
##   名前:カメラ x,y,z>見る 先 x,y,z[@画角]     すきな 位置から
##   名前:@x,y[,向き（度。0 = おく、90 = 右）]      ミクロごうを そこへ 置いて、ゲームの カメラで（「start」だけなら スタート位置）
## --play=秒 で 自動操縦してから。--hud で HUD を 出した まま。--unlock で ゴールを 開いた 色に。--frames=N（既定 30）。

var _frames := 30


func _ready() -> void:
	var stage := "mouth"
	var out := "/tmp/stage_view/"
	var views := "start"
	var play := 0.0
	var hud := false
	var unlock := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			stage = a.substr(8)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--views="):
			views = a.substr(8)
		elif a.begins_with("--play="):
			play = float(a.substr(7))
		elif a.begins_with("--frames="):
			_frames = int(a.substr(9))
		elif a == "--hud":
			hud = true
		elif a == "--unlock":
			unlock = true
	Game.testing = true
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	SaveData.use_path("user://save_shot.json")
	SaveData.reset()
	SaveData.set_setting("volume", 0.0)
	SaveData.set_setting("touch", "off")
	DirAccess.make_dir_recursive_absolute(out)
	Game.start_stage(stage)
	var lvl = Game.level
	var waited := 0
	while not lvl.started and waited < 600:
		await get_tree().process_frame
		waited += 1
	var t := 0.0
	while t < play and not lvl.finished:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		Autopilot.drive(lvl, get_tree())
	lvl.player.autopilot_target = Vector3.INF
	lvl.player.autopilot_shoot = false
	if not hud:
		Game.hud.visible = false
		lvl.player.arrow.scale = Vector3.ZERO
	if unlock and lvl.goal:
		lvl.goal.set_locked(false)
	var free_cam := Camera3D.new()
	free_cam.near = 0.1
	free_cam.far = 400.0
	lvl.add_child(free_cam)
	for v in views.split(";", false):
		var name := v.get_slice(":", 0)
		var spec := v.substr(name.length() + 1) if v.contains(":") else ""
		if spec == "" or spec.begins_with("@"):
			if spec != "":
				var n := spec.substr(1).split_floats(",")
				var p := Vector3(n[0], 0.0, -n[1])
				var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 12.0, p + Vector3.DOWN * 60.0, 1)
				var hit: Dictionary = lvl.get_world_3d().direct_space_state.intersect_ray(q)
				lvl.player.global_position = (hit["position"] if not hit.is_empty() else p) + Vector3.UP * 1.1
				lvl.player.velocity = Vector3.ZERO
				var deg := n[2] if n.size() > 2 else 0.0
				lvl.player.heading = Vector3(sin(deg_to_rad(deg)), 0, -cos(deg_to_rad(deg)))
			for i in 20:
				await get_tree().physics_frame
			lvl.camera.snap_to_target()
			lvl.camera.camera().current = true
		else:
			var fov := 68.0
			if spec.contains("@"):
				fov = float(spec.get_slice("@", 1))
				spec = spec.get_slice("@", 0)
			var a := spec.get_slice(">", 0).split_floats(",")
			var b := spec.get_slice(">", 1).split_floats(",")
			var from := Vector3(a[0], a[2], -a[1])
			var to := Vector3(b[0], b[2], -b[1])
			free_cam.fov = fov
			free_cam.look_at_from_position(from, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.FORWARD)
			free_cam.current = true
		for i in _frames:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var file := out.path_join(name + ".png")
		img.save_png(file)
		print("saved ", file, " ", img.get_size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	get_tree().quit(0)
