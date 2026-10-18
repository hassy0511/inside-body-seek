class_name Boss
extends Enemy
## ボス「かぜウイルスだいおう」。ときどき まんなかが ひらいて（weak）、そのときだけ おくすりが きく。
## 10 秒ごとに ちいさな ウイルスを よぶ（最大 4 ひき）。

signal weak_changed(is_weak: bool)

var weak := false
var _cycle := 0.0
var _spawn_t := 6.0
var core: MeshInstance3D
var minions: Array[Node] = []
var _base_scale := Vector3.ONE


func _ready() -> void:
	kind = "boss_virus"
	super._ready()
	hp = 14
	max_hp = 14
	speed = 1.8
	radius = 2.4
	hover_height = 2.6
	behavior = "boss"
	targetable = false
	for c in get_children():
		if c is CollisionShape3D and c.shape is SphereShape3D:
			(c.shape as SphereShape3D).radius = 2.0
	ModelLib.fit(model, 2.4)
	_base_scale = model.scale
	for c in touch.get_children():
		if c is CollisionShape3D and c.shape is SphereShape3D:
			(c.shape as SphereShape3D).radius = 2.6
	core = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 1.8
	core.mesh = sm
	core.material_override = ModelLib.flat_material(Color(1.0, 0.5, 0.2), Color(1.0, 0.4, 0.1))
	core.visible = false
	add_child(core)
	_cycle = 5.0


func _physics_process(delta: float) -> void:
	if not alive:
		return
	hover_step(delta)
	var player := _player()
	var move := Vector3.ZERO
	if player:
		var to := player.global_position - global_position
		to.y = 0.0
		if to.length() > 5.0:
			move = to.normalized() * speed
		var yaw := HoverBody.yaw_for(to.normalized()) if to.length() > 0.1 else model.rotation.y
		model.rotation.y = lerp_angle(model.rotation.y, yaw, minf(1.0, 2.0 * delta))
	steer(move, 6.0, delta)
	move_and_slide()
	_bob += delta * 1.5
	model.position.y = sin(_bob) * 0.3
	model.rotate_y(delta * 0.3)
	# 弱点サイクル：ひらく 3.5 秒 / とじる 5 秒
	_cycle -= delta
	if _cycle <= 0.0:
		_set_weak(not weak)
		_cycle = 3.5 if weak else 5.0
	if weak:
		core.visible = true
		core.scale = Vector3.ONE * (1.0 + 0.15 * sin(_bob * 6.0))
		core.position = Vector3(0, 0.2, 0)
		model.scale = _base_scale * 0.9
	else:
		core.visible = false
		model.scale = _base_scale * (1.0 + (_flash * 0.3 if _flash > 0.0 else 0.0))
	_flash = maxf(_flash - delta, 0.0)
	# ミニオン
	_spawn_t -= delta
	minions = minions.filter(func(m): return is_instance_valid(m) and m.get("alive"))
	if _spawn_t <= 0.0:
		_spawn_t = 10.0
		var alive_virus := 0
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.get("kind") == "virus" and e.get("alive"):
				alive_virus += 1
		if alive_virus < 4 and level and level.has_method("spawn_enemy_at"):
			var off := Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
			var m = level.spawn_enemy_at("virus", global_position + off)
			if m:
				minions.append(m)
			Sfx.play("boss_roar")


func _set_weak(w: bool) -> void:
	weak = w
	targetable = w
	weak_changed.emit(w)
	if w:
		Sfx.play("boss_weak")
		if level:
			Game.say("いまだ！ まんなかを ねらえ！", 2.5)


func take_hit(amount: int, from: Vector3 = Vector3.INF) -> void:
	if not alive:
		return
	if not weak:
		Sfx.play("hit", 0.6)
		_flash = 0.2
		return
	super.take_hit(amount, from)
	if alive:
		Sfx.play("boss_hit")


func _die() -> void:
	for m in minions:
		if is_instance_valid(m) and m.get("alive"):
			m.take_hit(99)
	Sfx.play("boss_down")
	super._die()
