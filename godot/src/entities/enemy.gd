class_name Enemy
extends HoverBody
## 敵（ばいきん・ウイルス）。種類ごとに動きが違う。
## take_hit() で HP が減り、0 で ぽん！と はじけて消える。ボスは boss.gd。

signal died(enemy: Enemy)

const CONFIG := {
	"mushiba": {"hp": 1, "speed": 3.0, "radius": 0.7, "behavior": "wander", "touch_r": 0.9},
	"pylori": {"hp": 2, "speed": 3.6, "radius": 0.7, "behavior": "orbit", "touch_r": 0.9},
	"akudama": {"hp": 2, "speed": 3.2, "radius": 0.8, "behavior": "chase", "touch_r": 1.0},
	"virus": {"hp": 1, "speed": 4.2, "radius": 0.6, "behavior": "jitter", "touch_r": 0.8},
}

var kind := "mushiba"
var hp := 1
var max_hp := 1
var speed := 3.0
var radius := 0.7
var behavior := "wander"
var alive := true
var targetable := true
var level: Node = null
var home := Vector3.ZERO
var model: Node3D
var touch: Area3D
var _wander_target := Vector3.ZERO
var _wander_t := 0.0
var _jitter_dir := Vector3.FORWARD
var _orbit_angle := 0.0
var _orbit_center := Vector3.INF
var _bob := 0.0
var _flash := 0.0


static func create(k: String) -> Enemy:
	var e := Enemy.new()
	e.kind = k
	return e


func _ready() -> void:
	super._ready()
	var c: Dictionary = CONFIG.get(kind, CONFIG["mushiba"])
	hp = c["hp"]
	max_hp = hp
	speed = c["speed"]
	radius = c["radius"]
	behavior = c["behavior"]
	hover_height = 0.9 + radius * 0.3
	hover_spring = 6.0
	collision_layer = 4           # enemy(3)
	collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = radius * 0.8
	cs.shape = s
	add_child(cs)
	model = ModelLib.character(kind, radius)
	add_child(model)
	touch = Area3D.new()
	touch.name = "Touch"
	touch.collision_layer = 64    # enemy_touch(7)
	touch.collision_mask = 0
	touch.monitoring = false
	touch.monitorable = true
	var ts := CollisionShape3D.new()
	var tss := SphereShape3D.new()
	tss.radius = c["touch_r"]
	ts.shape = tss
	touch.add_child(ts)
	touch.add_to_group("enemy_touch")
	add_child(touch)
	add_to_group("enemy")
	home = global_position
	_bob = randf() * TAU
	_pick_wander()


func _pick_wander() -> void:
	var a := randf() * TAU
	var r := randf_range(2.0, 6.0)
	_wander_target = home + Vector3(cos(a) * r, 0, sin(a) * r)
	_wander_t = randf_range(1.5, 3.5)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	hover_step(delta)
	var player := _player()
	var move := Vector3.ZERO
	match behavior:
		"wander":
			_wander_t -= delta
			var to := _wander_target - global_position
			to.y = 0.0
			if _wander_t <= 0.0 or to.length() < 0.8:
				_pick_wander()
			else:
				move = to.normalized() * speed
		"chase":
			if player and player.global_position.distance_to(global_position) < 14.0:
				var to := player.global_position - global_position
				to.y = 0.0
				if to.length() > 1.2:
					move = to.normalized() * speed
			else:
				_wander_t -= delta
				var to := _wander_target - global_position
				to.y = 0.0
				if _wander_t <= 0.0 or to.length() < 0.8:
					_pick_wander()
				else:
					move = to.normalized() * speed * 0.6
		"orbit":
			if _orbit_center == Vector3.INF:
				_orbit_center = _nearest_friend_position()
			var center := _orbit_center if _orbit_center != Vector3.INF else home
			_orbit_angle += delta * 0.9
			var want := center + Vector3(cos(_orbit_angle) * 3.5, 0, sin(_orbit_angle) * 3.5)
			var to := want - global_position
			to.y = 0.0
			if to.length() > 0.3:
				move = to.normalized() * minf(speed, to.length() * 2.0)
		"jitter":
			_wander_t -= delta
			if _wander_t <= 0.0:
				_jitter_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
				_wander_t = randf_range(0.4, 1.2)
			var to_home := home - global_position
			to_home.y = 0.0
			if to_home.length() > 9.0:
				_jitter_dir = to_home.normalized()
			move = _jitter_dir * speed
	steer(move, 14.0, delta)
	move_and_slide()
	# 見た目
	_bob += delta * 3.0
	model.position.y = sin(_bob) * 0.12
	if move.length() > 0.2:
		var yaw := HoverBody.yaw_for(move.normalized())
		model.rotation.y = lerp_angle(model.rotation.y, yaw, minf(1.0, 6.0 * delta))
	if behavior == "jitter":
		model.rotate_y(delta * 2.0)
	if _flash > 0.0:
		_flash -= delta
		model.scale = Vector3.ONE * (1.0 + _flash * 0.6)
	else:
		model.scale = Vector3.ONE


func _player() -> Node3D:
	var ps := get_tree().get_nodes_in_group("player")
	return ps[0] if ps.size() > 0 else null


func _nearest_friend_position() -> Vector3:
	var best := Vector3.INF
	var bd := INF
	for f in get_tree().get_nodes_in_group("friend"):
		if not (f is Node3D):
			continue
		var d: float = f.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = f.global_position
	return best


func take_hit(amount: int, from: Vector3 = Vector3.INF) -> void:
	if not alive:
		return
	hp -= amount
	_flash = 0.3
	if from != Vector3.INF:
		var away := global_position - from
		away.y = 0.0
		if away.length() > 0.01:
			velocity += away.normalized() * 6.0
	if hp <= 0:
		_die()
	else:
		Sfx.play("hit", 1.2)


func _die() -> void:
	alive = false
	targetable = false
	collision_layer = 0
	collision_mask = 0
	touch.set_deferred("monitorable", false)
	touch.remove_from_group("enemy_touch")
	remove_from_group("enemy")
	Sfx.play("pop", randf_range(0.9, 1.15))
	died.emit(self)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(model, "scale", Vector3.ONE * 1.5, 0.12)
	t.chain().tween_property(model, "scale", Vector3.ONE * 0.01, 0.25).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(queue_free)
	_spawn_sparkles()


func _spawn_sparkles() -> void:
	var p := GPUParticles3D.new()
	p.amount = 18
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.7
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -4, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.25
	mat.color = Color(1.0, 0.95, 0.5)
	p.process_material = mat
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	p.draw_pass_1 = sm
	p.material_override = ModelLib.flat_material(Color(1.0, 0.95, 0.5), Color(1.0, 0.8, 0.2))
	get_parent().add_child(p)
	p.global_position = global_position
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
