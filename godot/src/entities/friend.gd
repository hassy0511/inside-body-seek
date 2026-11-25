class_name Friend
extends Node3D
## なかま（赤血球・白血球・ぜんだまきん・いのかべの細胞）。さわると おうえんできる。
## wbc は おうえんすると 近くの敵に たいあたりして たたかってくれる。
## rbc は 道（path）に そって ながれる。
## うごかない なかま（move が "static"。い（胃）の かべの さいぼう）は かべの 一部：ゆかに 立ち（モデルの いちばん 下を
## ゆかより SINK m 下に。上下に ゆれない）、下を 中心に ゆっくり いきを して、いつも ミクロごうの ほうを むく。
## 足もとに かげ。中に 小さい 当たり（FriendSolid）が あって、船は つきぬけずに まわりを すべる。
## モデルに MouthHappy（ひらいた 口）が あれば、おうえんされる まで かくす。おうえんの あとは ときどき うれしそうに はずむ。

signal cheered(friend: Friend)

const TouchRelay := preload("res://src/entities/touch_relay.gd")

const CONFIG := {
	"wallcell": {"radius": 0.9, "move": "static"},
	"zendama": {"radius": 0.7, "move": "wander"},
	"rbc": {"radius": 0.8, "move": "flow"},
	"wbc": {"radius": 0.9, "move": "wander"},
}

## うごかない なかま：モデルの いちばん 下を ゆかより この m 下に（ふちが 浮いて 見えない）
const SINK := 0.05
const BREATH := 0.025          # いきの ふくらみ（たての 割合）
const BREATH_SEC := 2.8
const TURN_RATE := 2.2         # ミクロごうの ほうへ むく はやさ（1/秒）
const HOP_EVERY := 2.4         # おうえんの あと、この 秒ごとに うれしそうに はずむ
## 当たり（FriendSolid）の 層。船（player.gd）だけが 見る。ゆかの レイ（1）・てき（1|4）・たま・カメラは 見ない
const SOLID_LAYER := 128

var kind := "zendama"
var radius := 0.7
var move_kind := "static"
var level: Node = null
var home := Vector3.ZERO
var is_cheered := false
var model: Node3D
var area: Area3D
var attack_mode := false
var _vel := Vector3.ZERO
var _wander_target := Vector3.ZERO
var _wander_t := 0.0
var _bob := 0.0
var _attack_cd := 0.0
var _path_t := 0.0
var _oxygen: Node3D
## うごかない なかまの 台（モデルの 親。原点 ＝ モデルの いちばん 下。いき・はずみ・ふくらみは この 台を のばす）
var stand: Node3D
var happy_mouth: Node3D
var solid: StaticBody3D
var _shadow: MeshInstance3D
var _model_box := AABB()
var _floor_y := NAN
var _floor_point := Vector3.ZERO
var _floor_normal := Vector3.UP
var _t := 0.0
var _swell := 1.0
var _hop_t := 0.0


static func create(k: String) -> Friend:
	var f := Friend.new()
	f.kind = k
	return f


func _ready() -> void:
	var c: Dictionary = CONFIG.get(kind, CONFIG["zendama"])
	radius = c["radius"]
	move_kind = c["move"]
	model = ModelLib.character(kind, radius)
	if move_kind == "static":
		stand = Node3D.new()
		stand.name = "Stand"
		add_child(stand)
		stand.add_child(model)
		_model_box = ModelLib._aabb(model)
		model.position = Vector3(0.0, -_model_box.position.y * model.scale.y, 0.0)
		_shadow = HoverBody.make_shadow(_footprint() * 1.3)   # 足もとから すこし 外へ はみ出す かげ
		_shadow.visible = false
		add_child(_shadow)
		_make_solid()
		_face(_start_target(), 1.0)
	else:
		add_child(model)
	find_happy_mouth()
	area = TouchRelay.new()
	area.collision_layer = 16   # trigger(5)
	area.collision_mask = 0
	area.monitoring = false
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = radius + 0.5
	cs.shape = s
	area.add_child(cs)
	add_child(area)
	add_to_group("friend")
	home = global_position
	_bob = randf() * TAU
	_pick_wander()


## ひらいた 口（MouthHappy）を さがして、おうえんされて いなければ かくす（テストは 代わりの ノードを 足して よびなおす）
func find_happy_mouth() -> void:
	happy_mouth = model.find_child("MouthHappy", true, false) as Node3D
	if happy_mouth:
		happy_mouth.visible = is_cheered


## 足もとの はば（m。モデルの よこと おくゆきの 小さい ほうの 半分）
func _footprint() -> float:
	return maxf(minf(_model_box.size.x, _model_box.size.z) * 0.5 * model.scale.x, 0.2)


## 中の 当たり：たての 円柱。モデルより ほそく（足もとの はばの 0.85 倍）、上は 船が のりこえない 高さまで。
## ゆかに おく までは うごかさない（_settle() が 高さを 合わせる）
func _make_solid() -> void:
	solid = StaticBody3D.new()
	solid.name = "FriendSolid"
	solid.collision_layer = SOLID_LAYER
	solid.collision_mask = 0
	solid.add_to_group("friend_solid")
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = _footprint() * 0.85
	cy.height = _model_box.size.y * model.scale.y + 1.2
	cs.shape = cy
	solid.add_child(cs)
	solid.top_level = true
	add_child(solid)
	solid.global_position = global_position


## 中の 当たりの 半径（テストが 見る）
func solid_radius() -> float:
	if solid == null:
		return 0.0
	return ((solid.get_child(0) as CollisionShape3D).shape as CylinderShape3D).radius


## はじめに むく ところ：ミクロごうの スタート（まだ 船が いない ので マーカーから）
func _start_target() -> Vector3:
	if level and level.has_method("player_start"):
		return level.player_start()
	return global_position + Vector3.FORWARD


## 台を target の ほうへ むける（よこの 回転だけ）。k ＝ どれだけ よせるか（1 で ぴったり）
func _face(target: Vector3, k: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.2:
		return
	stand.rotation.y = lerp_angle(stand.rotation.y, HoverBody.yaw_for(to.normalized()), k)


## ゆかを さがす（足もとの まん中と まわり 8 か所。いちばん ひくい 所に 合わせるが、まん中より 0.08 m 下まで）。
## 物理の 空間は さいしょの フレームでは まだ 空の ことが あるので、見つかる まで 毎フレーム さがす
func _find_floor() -> void:
	var space := get_world_3d().direct_space_state
	var c := global_position
	var center := NAN
	var low := INF
	var r := _footprint() * 0.7
	for k in 9:
		var o := Vector3.ZERO if k == 0 else Vector3(cos(TAU * k / 8.0), 0.0, sin(TAU * k / 8.0)) * r
		var q := PhysicsRayQueryParameters3D.create(c + o + Vector3.UP * 4.0, c + o + Vector3.DOWN * 16.0, 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit["normal"].y < 0.35:
			continue
		if k == 0:
			center = hit["position"].y
			_floor_point = hit["position"]
			_floor_normal = hit["normal"]
		low = minf(low, hit["position"].y)
	if is_nan(center):
		return
	_floor_y = clampf(low, center - 0.08, center)
	solid.global_position = Vector3(c.x, _floor_y - SINK + (solid.get_child(0).shape as CylinderShape3D).height * 0.5, c.z)
	_shadow.visible = true
	HoverBody.place_shadow(_shadow, _floor_point, _floor_normal, 1.0, 0.03)


## うごかない なかまの 見た目：ゆかに 立って、いき・むき・はずみ
func _static_step(delta: float) -> void:
	_t += delta
	if is_nan(_floor_y):
		_find_floor()
	if not is_nan(_floor_y):
		stand.position.y = _floor_y - SINK - global_position.y
	var p := _player()
	if p:
		_face(p.global_position, minf(1.0, TURN_RATE * delta))
	# いき：下を 中心に ほんの すこし のびちぢみ（よこは たての 半分だけ はんたいに）
	var b := sin(_t * TAU / BREATH_SEC) * BREATH
	var sy := 1.0 + b
	var sxz := 1.0 - b * 0.5
	var wiggle := 0.0
	if is_cheered:
		# おうえんの あと：ときどき ぴょこんと のびて、くるっと からだを ふる（ゆかからは はなれない）
		# （さいしょは おうえんの ふくらみが おわって から）
		_hop_t += delta
		var ph := _hop_t - 0.6
		var u := fmod(ph, HOP_EVERY) / 0.7 if ph > 0.0 else 1.0
		if u < 0.25:
			var sq := sin(u / 0.25 * PI)     # ちぢむ
			sy -= 0.1 * sq
			sxz += 0.05 * sq
		elif u < 1.0:
			var st := sin((u - 0.25) / 0.75 * PI)   # のびる
			sy += 0.16 * st
			sxz -= 0.06 * st
			wiggle = sin((u - 0.25) / 0.75 * TAU) * 0.3
	stand.scale = Vector3(sxz, sy, sxz) * _swell
	model.rotation.y = wiggle


func _player() -> Node3D:
	if not is_inside_tree():
		return null
	var ps := get_tree().get_nodes_in_group("player")
	return ps[0] if ps.size() > 0 else null


func _pick_wander() -> void:
	var a := randf() * TAU
	var r := randf_range(1.5, 5.0)
	_wander_target = home + Vector3(cos(a) * r, 0, sin(a) * r)
	_wander_t = randf_range(2.0, 4.0)


func _physics_process(delta: float) -> void:
	_bob += delta * 2.5
	var move := Vector3.ZERO
	match move_kind:
		"wander":
			if attack_mode:
				move = _attack_step(delta)
			else:
				_wander_t -= delta
				var to := _wander_target - global_position
				to.y = 0.0
				if _wander_t <= 0.0 or to.length() < 0.5:
					_pick_wander()
				else:
					move = to.normalized() * 2.0
		"flow":
			var dir := Vector3.FORWARD
			var sp := 2.0
			if level and level.has_method("path_direction_at"):
				dir = level.path_direction_at(global_position)
				sp = 2.0 + float(level.get("flow_speed")) * (0.9 if is_cheered else 0.5)
			move = dir * sp
			_path_t += delta
	if move_kind == "static":
		_stick_to_floor(delta)
		_static_step(delta)
		return
	_vel = _vel.move_toward(move, 8.0 * delta)
	global_position += _vel * delta
	_stick_to_floor(delta)
	if move_kind == "flow" and level and level.has_method("path_is_end") and level.path_is_end(global_position):
		global_position = level.path_start_position() + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	model.position.y = sin(_bob) * 0.15 + (0.1 if is_cheered else 0.0)
	if _vel.length() > 0.3:
		model.rotation.y = lerp_angle(model.rotation.y, HoverBody.yaw_for(_vel.normalized()), minf(1.0, 5.0 * delta))
	if kind == "rbc":
		model.rotation.x = sin(_bob * 0.7) * 0.3
	if _oxygen:
		_oxygen.rotate_y(delta * 3.0)


func _stick_to_floor(_delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 4.0, global_position + Vector3.DOWN * 16.0, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var ty: float = hit["position"].y + 0.9 + radius * 0.3
		global_position.y = lerpf(global_position.y, ty, 0.2)


func _attack_step(delta: float) -> Vector3:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	var best: Node3D = null
	var bd := 26.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D) or not e.get("alive"):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return Vector3.ZERO
	var to := best.global_position - global_position
	to.y = 0.0
	var reach: float = 1.6 + float(best.get("radius"))
	if to.length() < reach:
		if _attack_cd <= 0.0:
			# ボスには ちょっとだけ。たおすのは プレイヤーの やくめ
			var is_boss: bool = best.get("kind") == "boss_virus"
			_attack_cd = 3.0 if is_boss else 2.0
			best.take_hit(1 if is_boss else 2, global_position)
			Sfx.play("cheer", 1.4)
			_vel = -to.normalized() * 6.0
		return Vector3.ZERO
	return to.normalized() * 5.0


func on_player_touch(_player: Node) -> void:
	cheer()


func cheer() -> void:
	if is_cheered:
		Sfx.play("cheer", 1.1)
		_hearts()
		return
	is_cheered = true
	if happy_mouth:
		happy_mouth.visible = true
	Sfx.play("cheer")
	_hearts()
	if kind == "wbc":
		attack_mode = true
	if kind == "rbc":
		_oxygen = Node3D.new()
		for i in 4:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.16
			sm.height = 0.32
			mi.mesh = sm
			mi.material_override = ModelLib.flat_material(Color(0.5, 0.8, 1.0), Color(0.3, 0.6, 1.0))
			var a := TAU * i / 4.0
			mi.position = Vector3(cos(a) * 1.1, 0.5, sin(a) * 1.1)
			_oxygen.add_child(mi)
		add_child(_oxygen)
	var t := create_tween()
	if stand:
		# 台（下が 中心）を ふくらませる：ゆかに めりこまない
		t.tween_property(self, "_swell", 1.3, 0.12)
		t.tween_property(self, "_swell", 1.0, 0.2)
	else:
		t.tween_property(model, "scale", Vector3.ONE * 1.3, 0.12)
		t.tween_property(model, "scale", Vector3.ONE, 0.2)
	cheered.emit(self)


func _hearts() -> void:
	var p := GPUParticles3D.new()
	p.amount = 10
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 1.0
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 40.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 3.5
	mat.gravity = Vector3(0, 1, 0)
	mat.scale_min = 0.15
	mat.scale_max = 0.3
	p.process_material = mat
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	p.draw_pass_1 = sm
	p.material_override = ModelLib.flat_material(Color(1.0, 0.4, 0.6), Color(1.0, 0.3, 0.5))
	add_child(p)
	p.position = Vector3(0, radius + 0.5, 0)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
