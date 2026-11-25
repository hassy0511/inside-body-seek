extends Node
## そうじゅうの 記録（ヘッドレスでも 画面つきでも 動く）。決まった 入力を 順に 押して、船と カメラの 向きを 書き出す。
##   godot --headless --fixed-fps 60 --path godot res://tests/steer_trace.tscn -- --stage=mouth --steps=left:1,none:0.5,up:1,down:1
##   --steps=  「なにを:秒」を「,」で ならべる。なにを ＝ none / left / right / up / down / dash / action を「+」で つなぐ（up+left:1）
##   --touch   やじるしの かわりに タッチの スティックを ゆびで 引く（touch_controls.gd に 本物の タッチを 送る）
##   --out=フォルダ  ひとつの 入力が おわる たびに 画面を 撮る（画面つきで 動かす ときだけ。tools/screenshot.sh と 同じ 起動の しかた）
##   --cards-seen  その 場所の ものしりカードを 見た ことに して から（カードの 画面で とまらない）
##   --no-enemies  てきを けして から（地形だけで はさまるか 見る ため）
##   --at=x,y,向き  スタートの かわりに ここから（Blender の 向き：x 右・y おく、向きは 度で 0 ＝ おく、90 ＝ 右。高さは ゆかに 合わせる）
## 出力：「TRACE t= step= pos= hyaw= cyaw= ...」と、HUD に 出た 文「SAY t= ...」（hyaw ＝ 船の 向き、cyaw ＝ カメラの 向き。どちらも 度。0 ＝ -Z、ひだりまわりが ＋）

var _stage := "mouth"
var _steps: Array = []
var _touch := false
var _out := ""
var _at := ""
var _no_enemies := false
var _cards_seen := false
var _t := 0.0   # ラムダは ローカル変数を 値で つかむので、時間は メンバに おく


func _ready() -> void:
	Game.testing = true
	var steps := "left:1,none:0.5,up:1,down:1"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			_stage = a.substr(8)
		elif a.begins_with("--steps="):
			steps = a.substr(8)
		elif a == "--touch":
			_touch = true
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--at="):
			_at = a.substr(5)
		elif a == "--no-enemies":
			_no_enemies = true
		elif a == "--cards-seen":
			_cards_seen = true
	for s in steps.split(",", false):
		var kv := s.split(":")
		_steps.append({"keys": kv[0].split("+", false), "sec": float(kv[1]) if kv.size() > 1 else 1.0, "name": s})
	SaveData.use_path("user://save_trace.json")
	SaveData.reset()
	SaveData.set_setting("volume", 0.0)
	SaveData.set_setting("touch", "on" if _touch else "off")
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	add_child(load("res://src/main.tscn").instantiate())
	await get_tree().process_frame
	if _cards_seen:
		for k in StageDB.get_stage(_stage).get("cards", {}).keys():
			SaveData.mark_card(_stage, k)
	Game.start_stage(_stage)
	var lvl = Game.level
	while not lvl.started:
		await get_tree().physics_frame
	# 出てきた ときの ゆれが おさまるまで まつ
	for i in 30:
		await get_tree().physics_frame
	var p = lvl.player
	if _no_enemies:
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
	if _at != "":
		var v := _at.split_floats(",")
		var xz := Vector3(v[0], 0.0, -v[1])
		var q := PhysicsRayQueryParameters3D.create(xz + Vector3.UP * 60.0, xz + Vector3.DOWN * 60.0, 1)
		var hit: Dictionary = lvl.get_world_3d().direct_space_state.intersect_ray(q)
		p.global_position = xz + Vector3.UP * ((hit["position"].y if not hit.is_empty() else 0.0) + 1.2)
		p.velocity = Vector3.ZERO
		var yaw := deg_to_rad(v[2] if v.size() > 2 else 0.0)
		p.heading = Vector3(sin(yaw), 0.0, -cos(yaw))
		lvl.camera.snap_to_target()
		for i in 20:
			await get_tree().physics_frame
	var t := 0.0
	Game.said.connect(func(text: String): print("SAY t=%5.2f %s" % [_t, text]))
	_trace(t, "start", p, lvl)
	var n := 0
	for st in _steps:
		_press(st["keys"], true)
		var dt_sum := 0.0
		var next_log := 0.25
		while dt_sum < st["sec"] - 0.0001:
			await get_tree().physics_frame
			var dt := get_physics_process_delta_time()
			dt_sum += dt
			t += dt
			_t = t
			if dt_sum >= next_log - 0.0001 and dt_sum < st["sec"] - 0.0001:
				next_log += 0.25
				_trace(t, st["name"], p, lvl)
		_trace(t, st["name"] + " END", p, lvl)
		_press(st["keys"], false)
		if _out != "":
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var file := _out.path_join("%02d_%s.png" % [n, st["name"].replace(":", "_").replace("+", "_")])
			img.save_png(file)
			print("saved " + file)
		n += 1
	print("TRACE DONE")
	SaveData.set_setting("touch", "auto")
	var d := DirAccess.open("user://")
	if d:
		d.remove("save_trace.json")
	get_tree().quit(0)


func _trace(t: float, step: String, p, lvl) -> void:
	var cam = lvl.camera
	print("TRACE t=%5.2f step=%-12s pos=(%6.2f, %6.2f) hyaw=%7.1f cyaw=%7.1f myaw=%7.1f speed=%5.2f h=%5.2f hearts=%d" % [
		t, step, p.global_position.x, p.global_position.z,
		rad_to_deg(HoverBody.yaw_for(p.heading)), rad_to_deg(cam.yaw), rad_to_deg(p.model.rotation.y),
		Vector2(p.velocity.x, p.velocity.z).length(), p.global_position.y, p.hearts])


func _press(keys: Array, on: bool) -> void:
	var v := Vector2.ZERO
	for k in keys:
		match k:
			"left": v.x -= 1.0
			"right": v.x += 1.0
			"up": v.y -= 1.0
			"down": v.y += 1.0
	for k in keys:
		var act := ""
		match k:
			"left": act = "move_left"
			"right": act = "move_right"
			"up": act = "move_up"
			"down": act = "move_down"
			"dash": act = "dash"
			"action": act = "action"
		if act == "" or (_touch and act.begins_with("move_")):
			continue
		if on:
			Input.action_press(act)
		else:
			Input.action_release(act)
	if _touch and v != Vector2.ZERO:
		# スティックの ばしょ（touch_controls.gd の _stick_home）を おして、ゆびを ひく
		var home := Vector2(150, 720 - 150)
		var ev_t := InputEventScreenTouch.new()
		ev_t.index = 0
		ev_t.position = home
		ev_t.pressed = on
		if on:
			get_viewport().push_input(ev_t, true)
			var ev_d := InputEventScreenDrag.new()
			ev_d.index = 0
			ev_d.position = home + v.normalized() * 80.0
			get_viewport().push_input(ev_d, true)
		else:
			ev_t.position = home + v.normalized() * 80.0
			get_viewport().push_input(ev_t, true)
