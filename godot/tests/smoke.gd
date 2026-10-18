extends Node
## 自動テスト（ヘッドレス）。
##   godot --headless --fixed-fps 60 --path godot res://tests/smoke.tscn
## 1. src/ の全スクリプトを読み込んで 文法エラーがないか
## 2. 全ステージを 自動操縦（autopilot）で クリアまで動かす

const MAX_STAGE_SECONDS := 420.0

var _failures: Array[String] = []
var _log: Array[String] = []
var _stage_elapsed := 0.0
var _only := ""
var _finished := false
var _debug := false


func _ready() -> void:
	Game.testing = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			_only = a.substr(8)
		if a == "--debug":
			_debug = true
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	_check_scripts()
	SaveData.reset()
	SaveData.set_setting("unlock_all", true)
	SaveData.set_setting("volume", 0.0)
	await _run_stages()
	SaveData.reset()
	_print_summary()
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


func _run_stages() -> void:
	for id in StageDB.stage_ids():
		if _only != "" and id != _only:
			continue
		await _run_stage(id)


func _run_stage(id: String) -> void:
	_info("=== stage %s ===" % id)
	var t0 := Time.get_ticks_msec()
	Game.start_stage(id)
	var lvl = Game.level
	if lvl == null:
		_fail("level not created: " + id)
		return
	# カードが閉じて started になるまで待つ
	var waited := 0.0
	while not lvl.started and waited < 10.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not lvl.started:
		_fail("stage never started: " + id)
		return
	_info("env=%s markers=%d missions=%d path_pts=%d" % [lvl.stage["env"], lvl.markers.size(), lvl.missions.size(), lvl.path.points.size()])
	_stage_elapsed = 0.0
	_finished = false
	Game.stage_finished.connect(func(_sid, _stars): _finished = true, CONNECT_ONE_SHOT)
	var last_report := 0.0
	while not _finished and _stage_elapsed < MAX_STAGE_SECONDS:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		_stage_elapsed += dt
		if is_instance_valid(lvl) and not lvl.finished:
			_drive(lvl)
		if _debug and is_instance_valid(lvl) and fmod(_stage_elapsed, 2.0) < dt and lvl.player:
			var p = lvl.player
			var cols: Array[String] = []
			for i in p.get_slide_collision_count():
				var c: KinematicCollision3D = p.get_slide_collision(i)
				cols.append("%s n=%s" % [c.get_collider().get_parent().name if c.get_collider().get_parent() else c.get_collider().name, c.get_normal()])
			_info("  dbg t=%.0f pos=%s floor=%s fp=%s vel=%s tgt=%s cols=%s" % [_stage_elapsed, p.global_position, p.floor_found, p.floor_point, p.velocity, p.autopilot_target, cols])
		if _stage_elapsed - last_report > 30.0:
			last_report = _stage_elapsed
			if is_instance_valid(lvl):
				_info("  t=%.0fs missions: %s  pos=%s hearts=%d" % [_stage_elapsed, _mission_state(lvl), lvl.player.global_position, lvl.player.hearts])
	if not _finished:
		_fail("stage %s did not finish in %.0fs; missions: %s" % [id, MAX_STAGE_SECONDS, _mission_state(lvl) if is_instance_valid(lvl) else "?"])
	else:
		_info("cleared %s in %.1fs (sim) / %.1fs (real); stars=%d" % [id, _stage_elapsed, (Time.get_ticks_msec() - t0) / 1000.0, SaveData.stars(id)])
		if SaveData.stars(id) < 1:
			_fail("stars not recorded for " + id)
	# ステージえらび画面に戻っているはず
	await get_tree().process_frame


func _mission_state(lvl) -> String:
	var parts: Array[String] = []
	for m in lvl.missions:
		parts.append("%s:%d/%d%s" % [m.type, m.current, m.count, "✓" if m.done else ""])
	return ", ".join(parts)


## 自動操縦：いまの目標へ向かう。くだステージでは道にそって進む。
func _drive(lvl) -> void:
	var p = lvl.player
	if p == null or not lvl.started:
		return
	var target: Vector3 = lvl.current_target_position()
	var enemy := _nearest_enemy(lvl, p.global_position)
	var enemy_target := target != Vector3.INF and enemy != null and enemy.global_position.distance_to(target) < 0.5
	p.autopilot_shoot = enemy != null and enemy.global_position.distance_to(p.global_position) < 13.0
	if enemy_target:
		var away: Vector3 = (p.global_position - target)
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3.FORWARD
		target = target + away.normalized() * 5.5
	var tube: bool = lvl.stage.get("kind", "arena") != "arena" and lvl.path.is_valid()
	if target == Vector3.INF:
		p.autopilot_target = Vector3.INF
		return
	if not tube:
		p.autopilot_target = target
		return
	var d := target.distance_to(p.global_position)
	if d < 12.0:
		p.autopilot_target = target
		return
	var prog: float = lvl.path.progress_at(p.global_position)
	var tprog: float = lvl.path.progress_at(target)
	var step := 7.0 if tprog >= prog - 1.0 else -7.0
	p.autopilot_target = lvl.path.sample(clampf(prog + step, 0.0, lvl.path.total)).position


func _nearest_enemy(lvl, pos: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D) or not e.get("alive"):
			continue
		var d: float = e.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = e
	return best


func _print_summary() -> void:
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
