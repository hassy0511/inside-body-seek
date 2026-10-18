class_name Player
extends HoverBody
## ミクロごう（プレイヤー）。
## 操作：移動（カメラ基準）、action（おくすり／おうえん）、dash。
## ハートは 3 つ。0 になると最後のチェックポイントへ戻る（ゲームオーバーなし）。

signal hearts_changed(hearts: int)
signal hurt_happened
signal respawned

const MAX_HEARTS := 3
const SPEED := 9.0
const DASH_SPEED := 14.0
const ACCEL := 32.0
const SHOT_COOLDOWN := 0.32
const Projectile := preload("res://src/player/projectile.gd")

var hearts := MAX_HEARTS
var inventory: Array[String] = []
var heading := Vector3.FORWARD
var control_enabled := true
var speed_mult := 1.0
var external_push := Vector3.ZERO
var invulnerable := 0.0
var shot_timer := 0.0
var level: Node = null
var camera: Node3D = null
var model: Node3D
var arrow: Node3D
var hitbox: Area3D
var _blink := 0.0
var _propeller: Node3D
var _respawning := false
var _no_floor_time := 0.0

## テスト用：ここに座標を入れると その方向へ自動で動く
var autopilot_target: Vector3 = Vector3.INF
var autopilot_shoot := false


func _ready() -> void:
	super._ready()
	hover_height = 1.1
	collision_layer = 2
	collision_mask = 1 | 4  # world + enemy bodies(3rd bit = 4)
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.55
	shape.shape = s
	add_child(shape)

	model = ModelLib.character("pod", 0.7)
	add_child(model)
	_propeller = model.find_child("Propeller", true, false)

	hitbox = Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 32   # player_area (6)
	hitbox.collision_mask = 16 | 64  # trigger(5) + enemy_touch(7)
	var hs := CollisionShape3D.new()
	var hss := SphereShape3D.new()
	hss.radius = 0.7
	hs.shape = hss
	hitbox.add_child(hs)
	add_child(hitbox)
	hitbox.area_entered.connect(_on_area_entered)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.97, 0.9)
	light.light_energy = 0.9
	light.omni_range = 12.0
	light.position = Vector3(0, 1.0, -0.5)
	add_child(light)

	arrow = _make_arrow()
	add_child(arrow)
	add_to_group("player")


func _make_arrow() -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Arrow"
	pivot.position = Vector3(0, 1.9, 0)
	var mi := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.28
	cone.height = 0.7
	mi.mesh = cone
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.position = Vector3(0, 0, -0.5)
	mi.material_override = ModelLib.flat_material(Color(1.0, 0.85, 0.2), Color(1.0, 0.7, 0.1))
	pivot.add_child(mi)
	pivot.visible = false
	return pivot


func _physics_process(delta: float) -> void:
	shot_timer = maxf(shot_timer - delta, 0.0)
	if invulnerable > 0.0:
		invulnerable -= delta
		_blink += delta
		model.visible = fmod(_blink, 0.2) < 0.1
	else:
		model.visible = true

	hover_step(delta)
	# ゆかが見つからないまま落ちつづけたら、チェックポイントへ戻す（セーフティ）
	if floor_found:
		_no_floor_time = 0.0
	else:
		_no_floor_time += delta
		if _no_floor_time > 2.5 and level and level.has_method("respawn_position") and not _respawning:
			_no_floor_time = 0.0
			global_position = level.respawn_position()
			velocity = Vector3.ZERO
	var input := Vector2.ZERO
	var dash := false
	var shoot := false
	var dir := Vector3.ZERO
	if control_enabled and not _respawning:
		if autopilot_target != Vector3.INF:
			var to := autopilot_target - global_position
			to.y = 0.0
			if to.length() > 0.6:
				dir = to.normalized()
			shoot = autopilot_shoot
			dash = true
		else:
			input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			dash = Input.is_action_pressed("dash")
			shoot = Input.is_action_pressed("action")
			dir = _camera_relative(input)
	var target_speed := (DASH_SPEED if dash else SPEED) * speed_mult
	var target_vel := dir * target_speed + external_push
	steer(target_vel, ACCEL, delta)
	if dir.length() > 0.1:
		heading = heading.slerp(dir, minf(1.0, 10.0 * delta)).normalized()
	move_and_slide()

	# 見た目
	var yaw := HoverBody.yaw_for(heading)
	model.rotation.y = lerp_angle(model.rotation.y, yaw, minf(1.0, 8.0 * delta))
	var hv := Vector3(velocity.x, 0, velocity.z)
	var lean := clampf(hv.length() / DASH_SPEED, 0.0, 1.0)
	model.rotation.x = lerp(model.rotation.x, -0.18 * lean, 6.0 * delta)
	var side := hv.length() > 0.5 and dir.length() > 0.1
	var roll_target := 0.0
	if side:
		var right := Vector3(-heading.z, 0, heading.x)
		roll_target = -0.35 * clampf(dir.dot(right), -1.0, 1.0)
	model.rotation.z = lerp(model.rotation.z, roll_target, 6.0 * delta)
	if _propeller:
		_propeller.rotate_z(delta * (12.0 + 30.0 * lean))

	if shoot and shot_timer <= 0.0:
		_shoot()
	_check_overlaps()
	speed_mult = 1.0
	external_push = Vector3.ZERO
	_update_arrow(delta)


func _camera_relative(input: Vector2) -> Vector3:
	if input.length() < 0.05:
		return Vector3.ZERO
	var basis_yaw := 0.0
	if camera != null:
		basis_yaw = camera.global_rotation.y
	var forward := Vector3(-sin(basis_yaw), 0, -cos(basis_yaw))
	var right := Vector3(cos(basis_yaw), 0, -sin(basis_yaw))
	var d := right * input.x + forward * (-input.y)
	if d.length() > 1.0:
		d = d.normalized()
	return d


func _shoot() -> void:
	shot_timer = SHOT_COOLDOWN
	var dir := heading
	var target := _auto_aim()
	if target != null:
		var to := (target.global_position - global_position)
		to.y = 0.0
		if to.length() > 0.01:
			dir = to.normalized()
			heading = dir
	var p := Projectile.new()
	p.direction = dir
	p.owner_level = level
	get_parent().add_child(p)
	p.global_position = global_position + dir * 0.9 + Vector3.UP * 0.1
	Sfx.play("shoot", randf_range(0.95, 1.1))


func _auto_aim() -> Node3D:
	var best: Node3D = null
	var best_d := 16.0
	var fallback: Node3D = null
	var fallback_d := 9.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D) or not e.get("alive"):
			continue
		if not e.get("targetable"):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < 0.1:
			continue
		var ang := rad_to_deg(heading.angle_to(to.normalized()))
		if ang < 70.0 and d < best_d:
			best = e
			best_d = d
		elif d < fallback_d:
			fallback = e
			fallback_d = d
	return best if best != null else fallback


func _on_area_entered(area: Area3D) -> void:
	if area.has_method("on_player_touch"):
		area.on_player_touch(self)


func _check_overlaps() -> void:
	for area in hitbox.get_overlapping_areas():
		if area.is_in_group("enemy_touch") and invulnerable <= 0.0 and not _respawning:
			var src: Node3D = area.get_parent() if area.get_parent() is Node3D else area
			if src.get("alive") == false:
				continue
			hurt(src.global_position)
		elif area.has_method("on_player_stay"):
			area.on_player_stay(self, get_physics_process_delta_time())


func hurt(from: Vector3) -> void:
	if invulnerable > 0.0 or _respawning:
		return
	hearts -= 1
	invulnerable = 1.5
	_blink = 0.0
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		away = -heading
	velocity += away.normalized() * 10.0 + Vector3.UP * 2.0
	hearts_changed.emit(hearts)
	hurt_happened.emit()
	Sfx.play("hurt")
	if hearts <= 0:
		_respawn()


func heal(n := 1) -> void:
	hearts = mini(hearts + n, MAX_HEARTS)
	hearts_changed.emit(hearts)


func _respawn() -> void:
	_respawning = true
	control_enabled = false
	velocity = Vector3.ZERO
	var t := create_tween()
	t.tween_property(model, "scale", Vector3.ONE * 0.05, 0.4)
	t.tween_callback(func():
		if level and level.has_method("respawn_position"):
			global_position = level.respawn_position()
		hearts = MAX_HEARTS
		hearts_changed.emit(hearts)
		inventory.clear()
		velocity = Vector3.ZERO
	)
	t.tween_property(model, "scale", Vector3.ONE, 0.4)
	t.tween_callback(func():
		_respawning = false
		control_enabled = true
		invulnerable = 2.0
		respawned.emit()
	)


func _update_arrow(delta: float) -> void:
	if level == null or not level.has_method("current_target_position"):
		arrow.visible = false
		return
	var tp: Vector3 = level.current_target_position()
	if tp == Vector3.INF:
		arrow.visible = false
		return
	var to := tp - global_position
	to.y = 0.0
	if to.length() < 3.0:
		arrow.visible = false
		return
	arrow.visible = true
	var yaw := HoverBody.yaw_for(to.normalized())
	arrow.rotation.y = lerp_angle(arrow.rotation.y, yaw, minf(1.0, 8.0 * delta))
	arrow.position.y = 1.9 + sin(Time.get_ticks_msec() / 200.0) * 0.1
