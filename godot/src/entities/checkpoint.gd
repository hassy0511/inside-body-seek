class_name Checkpoint
extends Area3D
## チェックポイント（はた）。さわると ここから再開できる。

signal activated(cp: Checkpoint)

var active := false
var level: Node = null
var _flag: MeshInstance3D


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 3.0
	cs.shape = s
	add_child(cs)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.08
	pm.bottom_radius = 0.1
	pm.height = 3.0
	pole.mesh = pm
	pole.position = Vector3(0, 1.5, 0)
	pole.material_override = ModelLib.flat_material(Color(0.9, 0.9, 0.95))
	add_child(pole)
	_flag = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 0.9, 0.08)
	_flag.mesh = bm
	_flag.position = Vector3(0.7, 2.5, 0)
	_flag.material_override = ModelLib.flat_material(Color(0.7, 0.7, 0.75))
	add_child(_flag)
	add_to_group("checkpoint")


func on_player_touch(_player: Node) -> void:
	if active:
		return
	active = true
	_flag.material_override = ModelLib.flat_material(Color(0.3, 0.9, 0.5), Color(0.2, 0.8, 0.3))
	Sfx.play("checkpoint")
	activated.emit(self)
