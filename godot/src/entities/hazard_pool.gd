class_name HazardPool
extends Area3D
## いえきの いけ。入ると おそくなって、ハートが 1 つ へる（いけを 出て 1 びょう たつまで もう へらない。player.gd の pool_hurt）。
##
## 見た目：マーカーの 高さに 平らな 水面（光らない 琥珀色。ゴールの 黄色と まぎれない）。
## ゆかの くぼみ と ふちは 場所の モデルに ある（blender/stage_stomach.py の POOL_*）。くぼみの 坂が 水面を
## よこぎる ところが ちょうど 半径 radius なので、水の ふち ＝ 半径 radius。水面の 円は それより 少し 大きく、
## はみ出した ぶんは ふちの 下に かくれる。
## あぶない ところ：ミクロごうの まんなかが 水の ふち（radius）より 内がわに 入った とき だけ。
## （当たりの 円柱を SHIP_R だけ 小さく する。ミクロごうの 当たりは 半径 SHIP_R の 球）
## いけを 出さない 場面（とおりみち）では、くぼみは からの まま（ゆかの 色の ふちと 少し こい 底）。

## player.gd の Hitbox の 半径
const SHIP_R := 0.7
## 水面の 円の 大きさ（radius より 外は ふちの 下に かくれる）
const SURFACE_OVER := 0.35
const AMBER := Color("#F5981F")

var radius := 5.0
var level: Node = null
var kind := "acid"
var _warn_cd := 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = maxf(radius - SHIP_R, 0.3)
	s.height = 3.0
	cs.shape = s
	cs.position = Vector3(0, 1.0, 0)
	add_child(cs)
	_mesh = MeshInstance3D.new()
	_mesh.name = "Juice"
	_mesh.mesh = _disc(radius + SURFACE_OVER)
	_mesh.material_override = _material()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	add_to_group("hazard")


func _process(delta: float) -> void:
	_warn_cd = maxf(_warn_cd - delta, 0.0)
	# ゆっくり まわす：円なので ふちは うごかず、中の うすい もようだけが ながれる
	_mesh.rotation.y += delta * 0.06


## 場所の "look" の "juice"（無ければ 琥珀色）。光らない：場所の 面と 同じ ねんどの 見えかた
func _material() -> Material:
	var stage: Dictionary = level.stage if level != null and level.get("stage") is Dictionary else {}
	var look: Dictionary = stage.get("look", {})
	var surf: Dictionary = look.get("surfaces", {})
	if surf.has("juice"):
		return StageLook.material(String(stage.get("id", "")), "juice", surf["juice"], look)
	var m := ModelLib.flat_material(AMBER)
	m.roughness = 0.6
	return m


## 平らな 円（上向き）。頂点の 色で うすい うずの もよう（雰囲気画の 水面の 明るい むら）
static func _disc(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 10
	var seg := 64
	var pts: Array = []
	for i in rings + 1:
		var row: Array = []
		var rr := r * float(i) / rings
		for j in seg:
			var a := TAU * j / seg
			var p := Vector3(cos(a) * rr, 0.0, sin(a) * rr)
			var swirl := 0.5 + 0.5 * sin(a * 2.0 + rr * 0.9) * sin(rr * 0.7 + 0.5)
			var k := 0.95 + 0.08 * swirl
			row.append([p, Color(k, k, k * 0.98)])
		pts.append(row)
	for i in rings:
		for j in seg:
			var j2 := (j + 1) % seg
			for v in [pts[i][j], pts[i + 1][j], pts[i + 1][j2], pts[i][j], pts[i + 1][j2], pts[i][j2]]:
				st.set_color(v[1])
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	return st.commit()


func on_player_stay(player: Node, _delta: float) -> void:
	player.speed_mult = minf(player.speed_mult, 0.55)
	if _warn_cd <= 0.0:
		_warn_cd = 6.0
		Game.say("いえきだ！ はやく いけから でよう！", 2.5)
	if player.has_method("pool_hurt"):
		player.pool_hurt(global_position)
