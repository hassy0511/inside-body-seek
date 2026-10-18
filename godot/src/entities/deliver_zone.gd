class_name DeliverZone
extends Area3D
## とどけ先（じゅうもう）。えいようを持った プレイヤーが さわると 全部わたす。

signal delivered(zone: DeliverZone, count: int)

var kind := "villus"
var level: Node = null
var model: Node3D
var _t := 0.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 2.6
	cs.shape = s
	cs.position = Vector3(0, 1.0, 0)
	add_child(cs)
	model = ModelLib.character(kind, 1.6)
	add_child(model)
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 1.0, 0.6)
	light.light_energy = 1.0
	light.omni_range = 6.0
	light.position = Vector3(0, 2.0, 0)
	add_child(light)
	add_to_group("deliver")


func _process(delta: float) -> void:
	_t += delta
	model.scale = Vector3.ONE * (1.0 + 0.04 * sin(_t * 2.0))


func on_player_touch(player: Node) -> void:
	_try_deliver(player)


func on_player_stay(player: Node, _delta: float) -> void:
	_try_deliver(player)


func _try_deliver(player: Node) -> void:
	var inv: Array = player.inventory
	var n := 0
	var keep: Array[String] = []
	for item in inv:
		if item == "nutrient":
			n += 1
		else:
			keep.append(item)
	if n == 0:
		return
	player.inventory = keep
	Sfx.play("deliver")
	delivered.emit(self, n)
	var t := create_tween()
	t.tween_property(model, "scale", Vector3.ONE * 1.25, 0.15)
	t.tween_property(model, "scale", Vector3.ONE, 0.25)
