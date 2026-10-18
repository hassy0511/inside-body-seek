class_name ValveGate
extends Node3D
## しんぞうの べん（ドア）。ひらいている ときだけ とおれる。

signal passed(gate: ValveGate)

const TouchRelay := preload("res://src/entities/touch_relay.gd")

var index := 0
var level: Node = null
var open := false
var open_time := 2.6
var close_time := 2.2
var width := 7.0
var _t := 0.0
var _body: StaticBody3D
var _flap_l: MeshInstance3D
var _flap_r: MeshInstance3D
var _area: Area3D
var _counted := false
var _hint_cd := 0.0
var _entry_side := 0.0  # ドアのどちら側から入ったか（+1 / -1）。0 は外にいる
var _inside_t := 0.0


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 8.0, 0.6)
	cs.shape = box
	cs.position = Vector3(0, 3.0, 0)
	_body.add_child(cs)
	add_child(_body)
	var mat := ModelLib.flat_material(Color(0.85, 0.2, 0.3), Color(0.5, 0.05, 0.1))
	_flap_l = _flap(mat, -1.0)
	_flap_r = _flap(mat, 1.0)
	_area = TouchRelay.new()
	_area.collision_layer = 16
	_area.collision_mask = 0
	_area.monitoring = false
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(width, 8.0, 3.0)
	acs.shape = abox
	acs.position = Vector3(0, 3.0, 0)
	_area.add_child(acs)
	add_child(_area)
	_t = -float(index) * 1.3
	add_to_group("gate")
	_apply(false, true)


func _flap(mat: Material, side: float) -> MeshInstance3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * width * 0.5, 0, 0)
	add_child(pivot)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width * 0.5, 7.0, 0.3)
	mi.mesh = bm
	mi.position = Vector3(-side * width * 0.25, 3.5, 0)
	mi.material_override = mat
	pivot.add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	_hint_cd = maxf(_hint_cd - delta, 0.0)
	_inside_t += delta
	if _inside_t > 0.3:
		_entry_side = 0.0  # ドアの範囲から出た
	var cycle := open_time + close_time
	var phase := fposmod(_t, cycle)
	var want_open := phase < open_time
	if want_open != open:
		if not want_open and _player_in_doorway():
			_t -= delta  # プレイヤーが とびらの中にいる間は しめない
		else:
			_apply(want_open)
	var target := deg_to_rad(80.0) if open else 0.0
	var pl := _flap_l.get_parent() as Node3D
	var pr := _flap_r.get_parent() as Node3D
	pl.rotation.y = lerp_angle(pl.rotation.y, -target, minf(1.0, 8.0 * delta))
	pr.rotation.y = lerp_angle(pr.rotation.y, target, minf(1.0, 8.0 * delta))


func _apply(o: bool, silent := false) -> void:
	open = o
	_body.get_child(0).set_deferred("disabled", o)
	if silent:
		return
	if o:
		Sfx.play("gate_open", 0.9 + index * 0.1)
	else:
		Sfx.play("gate_close", 0.9 + index * 0.1)


func _player_in_doorway() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return false
	var lp := to_local((p as Node3D).global_position)
	return absf(lp.z) < 1.3 and absf(lp.x) < width * 0.5 + 0.5


func on_player_touch(player: Node) -> void:
	on_player_stay(player, 0.0)


func on_player_stay(player: Node, _delta: float) -> void:
	# 「とおりぬけた」と数えるのは、ドアの手前から むこうがわへ 抜けたとき
	var lz := to_local((player as Node3D).global_position).z
	_inside_t = 0.0
	if _entry_side == 0.0 and absf(lz) > 0.2:
		_entry_side = signf(lz)
	if open:
		if not _counted and _entry_side != 0.0 and signf(lz) == -_entry_side and absf(lz) > 0.2:
			_counted = true
			passed.emit(self)
			Sfx.play("checkpoint", 1.3)
	elif _hint_cd <= 0.0:
		_hint_cd = 5.0
		Game.say("ドアが しまってる。ひらくまで まとう！", 3.0)
