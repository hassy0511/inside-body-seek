class_name Neuron
extends Area3D
## しんけいさいぼう。ひかる／さわる。

signal touched(n: Neuron)

var index := 0
var level: Node = null
var model: Node3D
var _lit := 0.0
var _glow: OmniLight3D
var _color := Color(0.9, 0.85, 1.0)
var _touch_cd := 0.0

const PALETTE := [Color(1.0, 0.4, 0.4), Color(1.0, 0.85, 0.3), Color(0.4, 0.9, 0.5), Color(0.4, 0.7, 1.0), Color(0.9, 0.5, 1.0), Color(1.0, 0.6, 0.3)]


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 2.0
	cs.shape = s
	cs.position = Vector3(0, 1.0, 0)
	add_child(cs)
	_color = PALETTE[index % PALETTE.size()]
	model = ModelLib.character("neuron", 1.6)
	add_child(model)
	_glow = OmniLight3D.new()
	_glow.light_color = _color
	_glow.light_energy = 0.0
	_glow.omni_range = 9.0
	_glow.position = Vector3(0, 2.5, 0)
	add_child(_glow)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.6
	tm.outer_radius = 2.0
	ring.mesh = tm
	ring.position = Vector3(0, 0.1, 0)
	ring.material_override = ModelLib.flat_material(_color, _color * 0.6, 0.8)
	add_child(ring)
	add_to_group("neuron")


func _process(delta: float) -> void:
	_touch_cd = maxf(_touch_cd - delta, 0.0)
	if _lit > 0.0:
		_lit -= delta
		_glow.light_energy = 3.0 * clampf(_lit / 0.5, 0.0, 1.0)
		model.scale = Vector3.ONE * (1.0 + 0.2 * clampf(_lit, 0.0, 1.0))
	else:
		_glow.light_energy = 0.0
		model.scale = Vector3.ONE


func light_up(seconds := 0.6) -> void:
	_lit = seconds
	Sfx.play("beep", 0.8 + index * 0.12)


func on_player_touch(_player: Node) -> void:
	if _touch_cd > 0.0:
		return
	_touch_cd = 0.8
	touched.emit(self)
