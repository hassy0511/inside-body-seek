extends Node
## 自動テスト（ヘッドレス）。
##   godot --headless --fixed-fps 60 --path godot res://tests/smoke.tscn
## 1. src/ の全スクリプトを読み込んで 文法エラーがないか
## 2. 全ステージを 自動操縦（autopilot）で クリアまで動かす

const MAX_STAGE_SECONDS := 420.0
const Autopilot := preload("res://tests/autopilot.gd")

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
			_info("  dbg t=%.0f pos=%s floor=%s vel=%s tgt=%s ctrl=%s seq=%s in=%d show=%s pend=%s cols=%d" % [_stage_elapsed, p.global_position, p.floor_found, p.velocity, p.autopilot_target, p.control_enabled, lvl.sequence_expected(), lvl._seq_input, lvl._seq_showing, lvl._seq_pending, cols.size()])
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


## 自動操縦（tests/autopilot.gd と共用）
func _drive(lvl) -> void:
	Autopilot.drive(lvl, get_tree())


func _nearest_enemy(lvl, pos: Vector3) -> Node3D:
	return Autopilot.nearest_enemy(get_tree(), pos)


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
