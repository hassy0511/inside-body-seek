class_name HazardPool
extends Area3D
## いえきの いけ。入ると おそくなって、1.2 秒ごとに ハートが へる。

var radius := 5.0
var level: Node = null
var kind := "acid"
var _tick := 0.0
var _warn_cd := 0.0
var _mesh: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = 3.0
	cs.shape = s
	cs.position = Vector3(0, 1.0, 0)
	add_child(cs)
	_mesh = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.4
	_mesh.mesh = cm
	_mesh.position = Vector3(0, 0.1, 0)
	_mesh.material_override = ModelLib.flat_material(Color(1.0, 0.9, 0.2), Color(0.9, 0.8, 0.1), 0.75)
	add_child(_mesh)
	add_to_group("hazard")


func _process(delta: float) -> void:
	_t += delta
	_warn_cd = maxf(_warn_cd - delta, 0.0)
	_mesh.scale = Vector3(1.0 + 0.02 * sin(_t * 2.0), 1.0, 1.0 + 0.02 * cos(_t * 2.0))


func on_player_stay(player: Node, delta: float) -> void:
	player.speed_mult = minf(player.speed_mult, 0.55)
	if _warn_cd <= 0.0:
		_warn_cd = 6.0
		Game.say("いえきだ！ はやく いけから でよう！", 2.5)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.2
		player.hurt(global_position)
