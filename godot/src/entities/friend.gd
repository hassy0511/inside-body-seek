class_name Friend
extends Node3D
## なかま（赤血球・白血球・ぜんだまきん・いのかべの細胞）。さわると おうえんできる。
## wbc は おうえんすると 近くの敵に たいあたりして たたかってくれる。
## rbc は 道（path）に そって ながれる。

signal cheered(friend: Friend)

const TouchRelay := preload("res://src/entities/touch_relay.gd")

const CONFIG := {
	"wallcell": {"radius": 0.9, "move": "static"},
	"zendama": {"radius": 0.7, "move": "wander"},
	"rbc": {"radius": 0.8, "move": "flow"},
	"wbc": {"radius": 0.9, "move": "wander"},
}

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


static func create(k: String) -> Friend:
	var f := Friend.new()
	f.kind = k
	return f


func _ready() -> void:
	var c: Dictionary = CONFIG.get(kind, CONFIG["zendama"])
	radius = c["radius"]
	move_kind = c["move"]
	model = ModelLib.character(kind, radius)
	add_child(model)
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
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 2.0, global_position + Vector3.DOWN * 12.0, 1)
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
			_attack_cd = 2.0
			best.take_hit(2, global_position)
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
