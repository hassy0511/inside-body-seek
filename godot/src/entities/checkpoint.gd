class_name Checkpoint
extends Area3D
## チェックポイント（はた）。さわると ここから再開できる。

signal activated(cp: Checkpoint)

var active := false
var level: Node = null
var _flag: MeshInstance3D
var _pole: MeshInstance3D
## 旗と さおの こさ（0 ＝ 見えない）。カメラが 近づくと うすく する（テストも 見る）
var flag_alpha := 1.0


## 最初の物理フレームで ゆかの高さに合わせる
func _physics_process(_delta: float) -> void:
	ModelLib.snap_to_floor(self, 0.0)
	set_physics_process(false)


## カメラからの きょりで 旗を うすく して 消す（FLAG_FADE_FAR m より 遠いと そのまま、FLAG_HIDE_NEAR m より 近いと 見えない）。
## 道の まん中の 旗を 船が とおりすぎると、うしろの カメラと 船の あいだに 入って、さおが 画面の 上から 下まで 船を よこぎった
## （はじめは 3 m いないで 描かない だけに した。それでは 消える 直前に 大きく うつった）
const FLAG_FADE_FAR := 7.0
const FLAG_HIDE_NEAR := 4.0


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
	_pole = pole
	_flag = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 0.9, 0.08)
	_flag.mesh = bm
	_flag.position = Vector3(0.7, 2.5, 0)
	_flag.material_override = ModelLib.flat_material(Color(0.7, 0.7, 0.75))
	add_child(_flag)
	add_to_group("checkpoint")


static func flag_alpha_at(dist: float) -> float:
	return smoothstep(FLAG_HIDE_NEAR, FLAG_FADE_FAR, dist)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var a := flag_alpha_at(cam.global_position.distance_to(global_position + Vector3.UP * 2.0))
	if not is_equal_approx(a, flag_alpha):
		flag_alpha = a
		_apply_alpha()


func _apply_alpha() -> void:
	for mi in [_pole, _flag]:
		if mi == null:
			continue
		mi.visible = flag_alpha > 0.01
		var m := mi.material_override as StandardMaterial3D
		if m != null:
			m.albedo_color.a = flag_alpha
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if flag_alpha < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED


func on_player_touch(_player: Node) -> void:
	if active:
		return
	active = true
	_flag.material_override = ModelLib.flat_material(Color(0.3, 0.9, 0.5), Color(0.2, 0.8, 0.3))
	_apply_alpha()
	Sfx.play("checkpoint")
	activated.emit(self)
