class_name Goal
extends Area3D
## ゴールのわっか。ほかのミッションが終わるまでは灰色でロック。

signal reached

var locked := true
var level: Node = null
var _ring: MeshInstance3D
var _beam: MeshInstance3D
var _t := 0.0
var _hint_cd := 0.0


## 最初の物理フレームで ゆかの高さに合わせる
func _physics_process(_delta: float) -> void:
	ModelLib.snap_to_floor(self, 0.0)
	set_physics_process(false)


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 2.4
	cs.shape = s
	cs.position = Vector3(0, 1.2, 0)
	add_child(cs)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.0
	tm.outer_radius = 2.5
	_ring.mesh = tm
	_ring.position = Vector3(0, 1.6, 0)
	add_child(_ring)
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 1.4
	cm.height = 30.0
	_beam.mesh = cm
	_beam.position = Vector3(0, 15.0, 0)
	add_child(_beam)
	_apply_look()
	add_to_group("goal")


func set_locked(v: bool) -> void:
	if locked == v:
		return
	locked = v
	_apply_look()
	if not v and level != null and level.get("started"):
		Sfx.play("goal_open")


func _apply_look() -> void:
	if locked:
		_ring.material_override = ModelLib.flat_material(Color(0.6, 0.6, 0.65), Color.BLACK, 0.9)
		_beam.material_override = ModelLib.flat_material(Color(0.7, 0.7, 0.75), Color.BLACK, 0.12)
	else:
		_ring.material_override = ModelLib.flat_material(Color(1.0, 0.9, 0.3), Color(1.0, 0.8, 0.2))
		_beam.material_override = ModelLib.flat_material(Color(1.0, 0.95, 0.5), Color(1.0, 0.9, 0.3), 0.25)


func _process(delta: float) -> void:
	_t += delta
	_hint_cd = maxf(_hint_cd - delta, 0.0)
	_ring.rotation.y += delta * (1.5 if not locked else 0.3)
	_ring.rotation.x = sin(_t) * 0.2
	_ring.position.y = 1.6 + sin(_t * 1.5) * 0.15


func on_player_touch(_player: Node) -> void:
	if locked:
		if _hint_cd <= 0.0:
			_hint_cd = 4.0
			Sfx.play("locked")
			if level and level.has_method("remaining_text"):
				Game.say("まだ やることが あるよ：" + level.remaining_text(), 4.0)
		return
	reached.emit()


## わっかの中に いるときに ゴールが ひらいても すぐ クリアできるように
func on_player_stay(player: Node, _delta: float) -> void:
	if not locked:
		on_player_touch(player)
