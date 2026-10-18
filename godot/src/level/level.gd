class_name Level
extends Node3D
## ステージ本体。
## 1. GLB（blender/ で生成）を読み、MK_ で始まる Empty をスポーン位置として使う
## 2. ミッションを組み立てて進行を見る
## 3. はじめて出会ったものの「ものしりカード」を出す
##
## マーカー名のきまり: MK_<種類>_<名前>[_<番号>]
##   MK_player            プレイヤーの開始位置
##   MK_goal              ゴール
##   MK_checkpoint_1      チェックポイント
##   MK_path_000 ...      道（くだステージの中心線。番号順）
##   MK_enemy_<kind>_1    敵      (mushiba / pylori / akudama / virus)
##   MK_boss_<kind>       ボス    (boss_virus)
##   MK_friend_<kind>_1   なかま  (wallcell / zendama / rbc / wbc)
##   MK_pickup_<kind>_1   ひろうもの (nutrient / heart_item)
##   MK_deliver_<kind>_1  とどけ先 (villus)
##   MK_hazard_acid_r5_1  いえきの いけ（r のあとは半径）
##   MK_gate_1            べん（ドア）。向きは Empty の回転
##   MK_neuron_1          しんけい
##   MK_sign_<key>        かんばん（文字は SIGN_TEXT）
##   MK_card_<key>        近づくとカードが出るだけの点

signal cleared(stage_id: String, no_damage: bool)
signal missions_changed
signal hearts_changed(hearts: int)

const PlayerScene := preload("res://src/player/player.tscn")
const FollowCameraScript := preload("res://src/player/follow_camera.gd")
const EnemyScript := preload("res://src/entities/enemy.gd")
const BossScript := preload("res://src/entities/boss.gd")
const FriendScript := preload("res://src/entities/friend.gd")
const PickupScript := preload("res://src/entities/pickup.gd")
const DeliverScript := preload("res://src/entities/deliver_zone.gd")
const GoalScript := preload("res://src/entities/goal.gd")
const CheckpointScript := preload("res://src/entities/checkpoint.gd")
const HazardScript := preload("res://src/entities/hazard_pool.gd")
const WaveScript := preload("res://src/entities/wave.gd")
const GateScript := preload("res://src/entities/valve_gate.gd")
const NeuronScript := preload("res://src/entities/neuron.gd")
const LevelPathScript := preload("res://src/level/level_path.gd")
const MissionScript := preload("res://src/level/mission.gd")

const SIGN_TEXT := {
	"ra": "みぎの しんぼう", "rv": "みぎの しんしつ", "la": "ひだりの しんぼう", "lv": "ひだりの しんしつ",
	"lung": "→ はいへ", "aorta": "だいどうみゃく（でぐち）", "start": "スタート", "goal": "ゴール",
	"throat": "のど", "trachea": "きかん（くうきの みち）", "esophagus": "しょくどう（たべものの みち）",
}

var stage: Dictionary = {}
var stage_id := ""
var flow_speed := 0.0
var player: Player
var camera: Node3D
var path: LevelPath
var missions: Array[Mission] = []
var goal: Goal = null
var env: Node3D = null
var started := false
var finished := false
var elapsed := 0.0
var damage_taken := false
var respawn_point := Vector3.ZERO
var spawn_point := Vector3.ZERO
var markers: Array[Dictionary] = []
var card_points: Array[Dictionary] = []   # {key, position, node}
var neurons: Array[Neuron] = []
var gates: Array[ValveGate] = []
var _hints: Array = []
var _card_cd := 0.0
var _card_check := 0.0
var _wave_timer := 0.0
var _seq: Array[int] = []
var _seq_input := 0
var _seq_round := 0
var _seq_showing := false
var _sign_font: Font


func setup(s: Dictionary) -> void:
	stage = s
	stage_id = s["id"]
	flow_speed = float(s.get("flow_speed", 0.0))
	_hints = s.get("hints", []).duplicate()


func _ready() -> void:
	_sign_font = Game.font_bold
	_build_environment()
	_load_env()
	_collect_markers()
	_build_path()
	_spawn_all()
	_build_missions()
	_spawn_player()


func begin() -> void:
	var card: Dictionary = stage["cards"].get("stage", {})
	var intro: String = stage.get("intro", "")
	var show_story: bool = stage["order"] == 1 and not SaveData.data.get("story_seen", false)
	var after_card := func():
		SaveData.mark_card(stage_id, "stage")
		started = true
		if intro != "":
			Game.say(intro, 6.0)
	if show_story:
		SaveData.data["story_seen"] = true
		SaveData.save()
		Game.show_card({"title": "はなちゃんを たすけよう！", "text": StageDB.STORY_INTRO}, func():
			Game.show_card(card, after_card, "stage"))
	else:
		Game.show_card(card, after_card, "stage")


# ---------------------------------------------------------------- 環境
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = stage.get("fog", Color(0.9, 0.7, 0.7))
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = stage.get("ambient", Color(1, 0.9, 0.9))
	e.ambient_light_energy = 0.55
	e.fog_enabled = true
	e.fog_light_color = stage.get("fog", Color(0.9, 0.7, 0.7)).darkened(0.1)
	e.fog_density = float(stage.get("fog_density", 0.015)) * 0.6
	e.fog_sky_affect = 0.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.9
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.75
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = false
	add_child(sun)


func _load_env() -> void:
	env = ModelLib.instance("stages/" + stage["env"])
	if env == null:
		push_warning("stage model not found: %s (fallback arena)" % stage["env"])
		env = _fallback_env()
	env.name = "Env"
	add_child(env)
	_ensure_collisions(env)


## GLB が無いときの代わりの広場（平らな円＋かべ）。マーカーも適当に置く。
func _fallback_env() -> Node3D:
	var root := Node3D.new()
	var floor_mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 40.0
	cm.bottom_radius = 40.0
	cm.height = 1.0
	floor_mi.mesh = cm
	floor_mi.position = Vector3(0, -0.5, 0)
	floor_mi.material_override = ModelLib.flat_material(stage.get("fog", Color(0.9, 0.7, 0.7)).darkened(0.2))
	root.add_child(floor_mi)
	var wall := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 38.0
	tm.outer_radius = 44.0
	wall.mesh = tm
	wall.position = Vector3(0, 0, 0)
	wall.material_override = ModelLib.flat_material(stage.get("fog", Color(0.9, 0.7, 0.7)).darkened(0.35))
	root.add_child(wall)
	var mk := func(n: String, p: Vector3):
		var m := Node3D.new()
		m.name = n
		m.position = p
		root.add_child(m)
	mk.call("MK_player", Vector3(0, 0, 20))
	mk.call("MK_goal", Vector3(0, 0, -30))
	mk.call("MK_checkpoint_1", Vector3(0, 0, -5))
	var i := 1
	for m in stage.get("missions", []):
		var kind: String = m.get("target", "")
		var n: int = int(m.get("count", 1))
		var prefix := ""
		match m.get("type", ""):
			"defeat": prefix = "MK_enemy_"
			"cheer": prefix = "MK_friend_"
			"collect": prefix = "MK_pickup_"
			"deliver": prefix = "MK_deliver_"; n = 1
			"boss": prefix = "MK_boss_"; n = 1
			"sequence": prefix = "MK_neuron_"; kind = ""; n = 5
			"gate": prefix = "MK_gate_"; kind = ""; n = 4
		if prefix == "":
			continue
		for j in n:
			var a := TAU * (i * 0.37 + j * 0.13)
			var r := randf_range(8.0, 26.0)
			var nm := prefix + (kind + "_" if kind != "" else "") + str(j + 1)
			mk.call(nm, Vector3(cos(a) * r, 0, sin(a) * r))
			i += 1
	for j in 12:
		var a := TAU * j / 12.0
		mk.call("MK_path_%03d" % j, Vector3(cos(a) * 20.0, 0, sin(a) * 20.0))
	return root


func _ensure_collisions(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name.begins_with("NC_") or m.mesh == null:
			continue
		var has_body := false
		for c in m.get_children():
			if c is StaticBody3D:
				has_body = true
		if not has_body:
			m.create_trimesh_collision()
		for c in m.get_children():
			if c is StaticBody3D:
				(c as StaticBody3D).collision_layer = 1
				(c as StaticBody3D).collision_mask = 0


func _collect_markers() -> void:
	markers.clear()
	for n in env.find_children("MK_*", "Node3D", true, false):
		var parts: PackedStringArray = (n.name as String).split("_")
		if parts.size() < 2:
			continue
		var kind := String(parts[1])
		var rest: Array = Array(parts.slice(2))
		markers.append({"node": n, "kind": kind, "rest": rest, "name": String(n.name), "position": (n as Node3D).global_position, "basis": (n as Node3D).global_transform.basis})
		(n as Node3D).visible = false


func _markers_of(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in markers:
		if m["kind"] == kind:
			out.append(m)
	out.sort_custom(func(a, b): return a["name"] < b["name"])
	return out


func _build_path() -> void:
	path = LevelPathScript.new()
	var pts: Array = []
	for m in _markers_of("path"):
		pts.append(m["position"])
	if pts.size() < 2:
		var ps := _markers_of("player")
		var gs := _markers_of("goal")
		if ps.size() > 0 and gs.size() > 0:
			pts = [ps[0]["position"], gs[0]["position"]]
	path.setup(pts)


# ---------------------------------------------------------------- スポーン
func _spawn_all() -> void:
	var cards: Dictionary = stage.get("cards", {})
	for m in markers:
		var kind: String = m["kind"]
		var rest: Array = m["rest"]
		var pos: Vector3 = m["position"]
		match kind:
			"player":
				spawn_point = pos
				respawn_point = pos
			"goal":
				goal = GoalScript.new()
				goal.level = self
				goal.position = pos
				add_child(goal)
				goal.reached.connect(_on_goal_reached)
				_add_card_point("goal", pos, goal)
			"checkpoint":
				var cp := CheckpointScript.new()
				cp.level = self
				cp.position = pos
				add_child(cp)
				cp.activated.connect(func(c): respawn_point = c.global_position; Game.say("チェックポイント！ ここから やりなおせるよ。", 2.5))
			"enemy":
				var ek := String(rest[0]) if rest.size() > 0 else "mushiba"
				spawn_enemy_at(ek, pos)
			"boss":
				var b := BossScript.new()
				b.level = self
				b.position = pos
				add_child(b)
				b.died.connect(_on_enemy_died)
				_add_card_point("boss_virus", pos, b)
			"friend":
				var fk := String(rest[0]) if rest.size() > 0 else "zendama"
				var f := FriendScript.create(fk)
				f.level = self
				f.position = pos
				add_child(f)
				f.cheered.connect(_on_friend_cheered)
				_add_card_point(fk, pos, f)
			"pickup":
				var pk := String(rest[0]) if rest.size() > 0 else "nutrient"
				var idx := int(rest[1]) if rest.size() > 1 and String(rest[1]).is_valid_int() else 0
				var p := PickupScript.create(pk, idx)
				p.level = self
				p.position = pos
				add_child(p)
				p.collected.connect(_on_pickup_collected)
				_add_card_point(pk, pos, p)
			"deliver":
				var dk := String(rest[0]) if rest.size() > 0 else "villus"
				var d := DeliverScript.new()
				d.kind = dk
				d.level = self
				d.position = pos
				add_child(d)
				d.delivered.connect(_on_delivered)
				_add_card_point(dk, pos, d)
			"hazard":
				var hk := String(rest[0]) if rest.size() > 0 else "acid"
				var h := HazardScript.new()
				h.kind = hk
				for r in rest:
					var rs := String(r)
					if rs.begins_with("r") and rs.substr(1).is_valid_float():
						h.radius = float(rs.substr(1))
				h.level = self
				h.position = pos
				add_child(h)
				_add_card_point(hk, pos, h)
			"gate":
				var g := GateScript.new()
				g.index = gates.size()
				g.level = self
				g.position = pos
				add_child(g)
				g.global_transform.basis = m["basis"]
				g.passed.connect(_on_gate_passed)
				gates.append(g)
				_add_card_point("valve", pos, g)
			"neuron":
				var nn := NeuronScript.new()
				nn.index = neurons.size()
				nn.level = self
				nn.position = pos
				add_child(nn)
				nn.touched.connect(_on_neuron_touched)
				neurons.append(nn)
				_add_card_point("neuron", pos, nn)
			"sign":
				var key := String(rest[0]) if rest.size() > 0 else ""
				_spawn_sign(SIGN_TEXT.get(key, key), pos)
			"card":
				var ck := String(rest[0]) if rest.size() > 0 else ""
				if cards.has(ck):
					_add_card_point(ck, pos, null)
			"path":
				pass
	if goal == null and path.is_valid():
		goal = GoalScript.new()
		goal.level = self
		goal.position = path.end()
		add_child(goal)
		goal.reached.connect(_on_goal_reached)


func spawn_enemy_at(kind: String, pos: Vector3) -> Node:
	var e := EnemyScript.create(kind)
	e.level = self
	e.position = pos
	add_child(e)
	e.died.connect(_on_enemy_died)
	_add_card_point(kind, pos, e)
	return e


func _spawn_sign(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = _sign_font
	l.font_size = 64
	l.pixel_size = 0.02
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1, 1, 1)
	l.outline_modulate = Color(0.3, 0.1, 0.15)
	l.outline_size = 14
	l.position = pos + Vector3.UP * 3.0
	add_child(l)


func _add_card_point(key: String, pos: Vector3, node: Node) -> void:
	if not stage.get("cards", {}).has(key):
		return
	card_points.append({"key": key, "position": pos, "node": node})


func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	player.level = self
	add_child(player)
	player.global_position = spawn_point + Vector3.UP * 1.0
	var ps := _markers_of("player")
	if ps.size() > 0:
		var b: Basis = ps[0]["basis"]
		var fwd := -b.z
		fwd.y = 0.0
		if fwd.length() > 0.1:
			player.heading = fwd.normalized()
	elif path.is_valid():
		player.heading = path.direction_at(spawn_point)
	camera = FollowCameraScript.new()
	camera.target = player
	camera.level = self
	camera.tube_mode = stage.get("kind", "arena") == "tube"
	add_child(camera)
	camera.snap_to_target()
	player.camera = camera
	player.hearts_changed.connect(func(h): hearts_changed.emit(h))
	player.hurt_happened.connect(func(): damage_taken = true)
	player.respawned.connect(func(): Game.say("ちょっと きゅうけい。もういっかい いこう！", 3.0))


# ---------------------------------------------------------------- ミッション
func _build_missions() -> void:
	missions.clear()
	for d in stage.get("missions", []):
		var m := MissionScript.from_dict(d)
		if m.type == "sequence":
			m.count = int(d.get("count", 3))
		m.progressed.connect(func(_m): missions_changed.emit())
		m.completed.connect(_on_mission_completed)
		missions.append(m)
	missions_changed.emit()
	_update_goal_lock()


func _mission(type: String, target := "") -> Mission:
	for m in missions:
		if m.type == type and (target == "" or m.target == target or m.target == ""):
			return m
	return null


func _on_mission_completed(m: Mission) -> void:
	Sfx.play("mission")
	if not m.is_reach():
		Game.say("やったね！「%s」クリア！" % m.text, 3.0)
	_update_goal_lock()
	missions_changed.emit()


func _non_reach_done() -> bool:
	for m in missions:
		if not m.is_reach() and not m.done:
			return false
	return true


func _update_goal_lock() -> void:
	if goal:
		var was := goal.locked
		goal.set_locked(not _non_reach_done())
		if was and not goal.locked and started:
			Game.say("ゴールが ひらいたよ！ きいろい わっかへ いこう！", 4.0)


func remaining_text() -> String:
	var parts: Array[String] = []
	for m in missions:
		if not m.done and not m.is_reach():
			parts.append(m.text)
	return "、".join(parts)


func _on_enemy_died(e: Node) -> void:
	var kind: String = e.get("kind")
	var m := _mission("boss", kind) if kind == "boss_virus" else _mission("defeat", kind)
	if m:
		m.add(1)


func _on_friend_cheered(f: Node) -> void:
	var m := _mission("cheer", f.get("kind"))
	if m:
		m.add(1)


func _on_pickup_collected(p: Node) -> void:
	var m := _mission("collect", p.get("kind"))
	if m:
		m.add(1)
	missions_changed.emit()


func _on_delivered(_zone: Node, n: int) -> void:
	var m := _mission("deliver")
	if m:
		m.add(n)
	Game.say("えいようを とどけた！ からだが げんきに なるよ。", 2.5)


func _on_gate_passed(_g: Node) -> void:
	var m := _mission("gate")
	if m:
		m.add(1)


func _on_goal_reached() -> void:
	if finished or not started:
		return
	if not _non_reach_done():
		return
	var rm := _mission("reach")
	if rm:
		rm.add(1)
	finish()


func finish() -> void:
	if finished:
		return
	finished = true
	player.control_enabled = false
	player.velocity = Vector3.ZERO
	Sfx.play("clear")
	Game.say("ステージクリア！", 3.0)
	var t := create_tween()
	t.tween_interval(0.2 if Game.testing else 1.6)
	t.tween_callback(func(): cleared.emit(stage_id, not damage_taken))


func respawn_position() -> Vector3:
	return respawn_point + Vector3.UP * 1.0


## 矢印が指す「いま向かうところ」
func current_target_position() -> Vector3:
	for m in missions:
		if m.done:
			continue
		match m.type:
			"defeat":
				return _nearest_in_group("enemy", func(n): return n.get("kind") == m.target and n.get("alive"))
			"boss":
				return _nearest_in_group("enemy", func(n): return n.get("kind") == "boss_virus" and n.get("alive"))
			"cheer":
				return _nearest_in_group("friend", func(n): return n.get("kind") == m.target and not n.get("is_cheered"))
			"collect":
				if player.inventory.size() > 0 and _mission("deliver") != null:
					return _nearest_in_group("deliver", func(_n): return true)
				return _nearest_in_group("pickup", func(n): return n.get("kind") == m.target)
			"deliver":
				if player.inventory.size() > 0:
					return _nearest_in_group("deliver", func(_n): return true)
				return _nearest_in_group("pickup", func(_n): return true)
			"gate":
				for g in gates:
					if not g._counted:
						return g.global_position
			"sequence":
				if _seq_input < _seq.size() and not _seq_showing and _seq.size() > 0:
					return neurons[_seq[_seq_input]].global_position
				return Vector3.INF
			"reach":
				if goal:
					return goal.global_position
	return Vector3.INF


func _nearest_in_group(group: String, pred: Callable) -> Vector3:
	var best := Vector3.INF
	var bd := INF
	for n in get_tree().get_nodes_in_group(group):
		if not (n is Node3D) or not pred.call(n):
			continue
		var d: float = (n as Node3D).global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = (n as Node3D).global_position
	return best


# ---------------------------------------------------------------- 道・流れ
func path_direction_at(pos: Vector3) -> Vector3:
	return path.direction_at(pos) if path.is_valid() else Vector3.FORWARD


func path_sample(dist: float) -> Dictionary:
	return path.sample(dist)


func path_is_end(pos: Vector3) -> bool:
	return path.is_valid() and path.progress_at(pos) >= path.total - 4.0


func path_start_position() -> Vector3:
	return path.start() if path.is_valid() else spawn_point


# ---------------------------------------------------------------- 進行
func _physics_process(delta: float) -> void:
	if not started or finished:
		return
	elapsed += delta
	# 流れ
	if flow_speed > 0.0 and path.is_valid() and player:
		player.external_push += path.direction_at(player.global_position) * flow_speed
	# ヒント
	if _hints.size() > 0 and elapsed >= float(_hints[0]["at"]):
		Game.say(_hints[0]["text"], 5.0)
		_hints.remove_at(0)
	# なみ（しょくどう）
	if stage_id == "esophagus":
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_wave_timer = 4.5
			var w := WaveScript.new()
			w.level = self
			add_child(w)
			w.global_position = path.start()
			if not SaveData.card_seen(stage_id, "wave"):
				card_points.append({"key": "wave", "position": Vector3.INF, "node": w})
	# カード
	_card_cd = maxf(_card_cd - delta, 0.0)
	_card_check -= delta
	if _card_check <= 0.0:
		_card_check = 0.3
		_check_cards()
	# しんけいパズル
	if _mission("sequence") != null and not _mission("sequence").done and _seq.is_empty() and not _seq_showing and elapsed > 2.0:
		_start_sequence_round()


func _check_cards() -> void:
	if _card_cd > 0.0 or Game.is_popup_open() or elapsed < 2.5:
		return
	for i in card_points.size():
		var cp: Dictionary = card_points[i]
		var key: String = cp["key"]
		if SaveData.card_seen(stage_id, key):
			continue
		var pos: Vector3 = cp["position"]
		var node = cp["node"]
		if node != null and is_instance_valid(node) and node is Node3D:
			pos = (node as Node3D).global_position
		if pos == Vector3.INF:
			continue
		if pos.distance_to(player.global_position) < 9.0:
			SaveData.mark_card(stage_id, key)
			_card_cd = 3.0
			var card: Dictionary = stage["cards"][key]
			Sfx.play("card")
			Game.show_card(card, Callable(), key)
			return


# ---------------------------------------------------------------- しんけいパズル
func _start_sequence_round() -> void:
	if neurons.is_empty():
		return
	var length := 3 + _seq_round
	_seq = []
	var last := -1
	for i in length:
		var n := randi() % neurons.size()
		if n == last:
			n = (n + 1) % neurons.size()
		_seq.append(n)
		last = n
	_seq_input = 0
	_show_sequence()


func _show_sequence() -> void:
	_seq_showing = true
	Game.say("よく みてね！", 1.5)
	var t := create_tween()
	t.tween_interval(1.2)
	for idx in _seq:
		var n := neurons[idx]
		t.tween_callback(func(): n.light_up(0.6))
		t.tween_interval(0.75)
	t.tween_callback(func():
		_seq_showing = false
		_seq_input = 0
		Game.say("きみの ばん！ おなじ じゅんばんに さわろう。", 3.0)
	)


func _on_neuron_touched(n: Neuron) -> void:
	if _seq.is_empty() or _seq_showing:
		return
	var m := _mission("sequence")
	if m == null or m.done:
		return
	if n.index == _seq[_seq_input]:
		n.light_up(0.5)
		_seq_input += 1
		if _seq_input >= _seq.size():
			_seq_round += 1
			m.add(1)
			_seq = []
			if not m.done:
				Game.say("せいかい！ つぎは もっと ながいよ。", 2.0)
				var t := create_tween()
				t.tween_interval(2.0)
				t.tween_callback(_start_sequence_round)
	else:
		Sfx.play("wrong")
		Game.say("ざんねん！ もういちど みてね。", 2.0)
		_seq_input = 0
		var t := create_tween()
		t.tween_interval(1.5)
		t.tween_callback(_show_sequence)


## テスト用：いまの正解の順番
func sequence_expected() -> Array[int]:
	return _seq
