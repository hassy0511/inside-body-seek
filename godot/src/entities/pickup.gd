class_name Pickup
extends Area3D
## ひろえるもの。nutrient（えいよう）は ポケットに入る。heart_item は ハート回復。

signal collected(pickup: Pickup)

var kind := "nutrient"
var variant := 0
var level: Node = null
var model: Node3D
var _t := 0.0
var _taken := false


static func create(k: String, v := 0) -> Pickup:
	var p := Pickup.new()
	p.kind = k
	p.variant = v
	return p


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.1
	cs.shape = s
	add_child(cs)
	var name_variant := kind
	if kind == "nutrient":
		name_variant = "nutrient_%s" % ["a", "b", "c"][variant % 3]
	model = ModelLib.instance("characters/" + name_variant)
	if model == null:
		model = ModelLib.placeholder(kind, 0.45)
	add_child(model)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.6) if kind == "nutrient" else Color(1.0, 0.5, 0.6)
	light.light_energy = 0.8
	light.omni_range = 4.0
	add_child(light)
	_t = randf() * TAU
	add_to_group("pickup")


func _process(delta: float) -> void:
	_t += delta
	model.position.y = 0.3 + sin(_t * 2.0) * 0.2
	model.rotation.y += delta * 1.5


func on_player_touch(player: Node) -> void:
	if _taken:
		return
	_taken = true
	if kind == "heart_item":
		player.heal(1)
		Sfx.play("heal")
	else:
		player.inventory.append(kind)
		Sfx.play("collect", randf_range(0.95, 1.2))
	collected.emit(self)
	set_process(false)
	var t := create_tween()
	t.tween_property(model, "scale", Vector3.ONE * 1.5, 0.1)
	t.tween_property(model, "scale", Vector3.ONE * 0.01, 0.2)
	t.tween_callback(queue_free)
