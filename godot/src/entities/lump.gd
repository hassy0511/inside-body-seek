class_name FoodLump
extends Area3D
## のみこんだ ばかりの たべものの かたまり（しょくどう。カルテ 2 の「はやぐい」）。peristalsis.gd が 出して 動かす。
## やわらかい：ミクロごうが ぶつかると ぷるんと ゆれて、ミクロごうは はねかえって なみから おちる（ハートは へらない）。
## 色は 雰囲気画の かたまり（もも色 #F8BF97）。

const PEACH := Color("#F8BF97")

var peri: Node = null
var radius := 1.4
var prog := 0.0          # 道の 上の 位置（m）
var side := 0.0          # よこの ずれ（m。右が ＋）
var base_speed := 4.0
var _wobble := 0.0       # ゆれの 大きさ（ぶつかると 1）
var _t := 0.0
var _body: Node3D


func _ready() -> void:
	collision_layer = 16      # trigger（プレイヤーの Hitbox が 見る）
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = radius * 0.85
	cs.shape = s
	add_child(cs)
	_body = Node3D.new()
	add_child(_body)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PEACH
	mat.roughness = 0.45
	mat.rim_enabled = true
	mat.rim = 0.3
	# しょくどうの 光は 赤く うすぐらい：少しだけ 自分で 光らせて 雰囲気画の もも色に（測った 色は docs/art_orders/W3_01_食道_取り込みの結果.md の 4.4）
	mat.emission_enabled = true
	mat.emission = PEACH
	mat.emission_energy_multiplier = 0.25   # 0.5 だと 平らな 切りぬきに 見えた：上は 光で 明るく、下は かげで こく
	# ふぞろいな まるい かたまり（大きな 玉 1 つ ＋ 小さな こぶ 2 つ）
	for b in [[Vector3.ZERO, Vector3(1.0, 0.78, 1.08)], [Vector3(0.45, 0.25, -0.35), Vector3(0.55, 0.5, 0.55)], [Vector3(-0.5, 0.15, 0.4), Vector3(0.5, 0.45, 0.5)]]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 24
		sm.rings = 12
		mi.mesh = sm
		mi.material_override = mat
		# カメラの すぐ 近くでは 消す（よこを ぬける かたまりが 画面を ふさがない）
		mi.visibility_range_begin = 3.0
		mi.visibility_range_begin_margin = 2.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mi.position = (b[0] as Vector3) * radius
		mi.scale = (b[1] as Vector3) * radius
		_body.add_child(mi)
	add_to_group("lump")


func on_player_touch(player: Node) -> void:
	if peri != null and is_instance_valid(peri):
		peri.on_lump_touched(self, player)


func wobble() -> void:
	_wobble = 1.0


func _process(delta: float) -> void:
	_t += delta
	_wobble = maxf(_wobble - delta * 1.2, 0.0)
	var a := 0.04 + 0.22 * _wobble
	var w := sin(_t * (5.0 + 9.0 * _wobble)) * a
	_body.scale = Vector3(1.0 + w, 1.0 - w, 1.0 + w)
