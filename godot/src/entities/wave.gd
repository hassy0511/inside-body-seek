class_name Wave
extends Area3D
## ぜんどううんどうの なみ。道に そって すすみ、プレイヤーを おしてくれる。

var level: Node = null
var speed := 12.0
var push := 9.0
var dist := 0.0
var ring_radius := 4.5
var _ring: MeshInstance3D


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = ring_radius
	cs.shape = s
	add_child(cs)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = ring_radius - 0.9
	tm.outer_radius = ring_radius + 0.3
	_ring.mesh = tm
	_ring.material_override = ModelLib.flat_material(Color(1.0, 0.55, 0.65), Color(1.0, 0.4, 0.5), 0.45)
	_ring.rotation = Vector3(PI / 2.0, 0, 0)
	add_child(_ring)
	add_to_group("wave")


func _physics_process(delta: float) -> void:
	if level == null:
		return
	dist += speed * delta
	var info: Dictionary = level.path_sample(dist)
	global_position = info["position"]
	var d: Vector3 = info["direction"]
	if d.length() > 0.01:
		look_at(global_position + d, Vector3.UP)
	if info["at_end"]:
		queue_free()


func on_player_stay(player: Node, _delta: float) -> void:
	var d: Vector3 = level.path_direction_at(global_position)
	player.external_push += d * push
