class_name ModelLib
## GLB モデルの読み込み。無ければ色つきの代わりの形（プレースホルダー）を返す。
## Blender スクリプトを直したら godot/assets/models/ の GLB を上書きするだけで差し替わる。

const DIR := "res://assets/models/"

const PLACEHOLDER_COLORS := {
	"pod": Color(0.95, 0.95, 1.0), "pico": Color(0.6, 0.9, 1.0),
	"mushiba": Color(0.25, 0.22, 0.3), "pylori": Color(0.55, 0.4, 0.75), "akudama": Color(0.6, 0.2, 0.7),
	"virus": Color(0.4, 0.8, 0.4), "boss_virus": Color(0.3, 0.7, 0.3), "cholesterol": Color(0.95, 0.85, 0.3),
	"rbc": Color(0.85, 0.15, 0.2), "wbc": Color(0.98, 0.98, 0.95), "zendama": Color(0.4, 0.85, 0.5),
	"wallcell": Color(1.0, 0.75, 0.55), "villus": Color(0.5, 0.85, 0.5), "nutrient": Color(1.0, 0.9, 0.3),
	"neuron": Color(0.9, 0.8, 1.0), "heart_item": Color(1.0, 0.4, 0.5), "food": Color(0.8, 0.6, 0.3),
}


static func instance(name: String) -> Node3D:
	var path := DIR + name + ".glb"
	if ResourceLoader.exists(path):
		var ps = load(path)
		if ps is PackedScene:
			var n: Node = ps.instantiate()
			if n is Node3D:
				return n
	return null


## キャラクターモデル。無ければ球のプレースホルダー。
static func character(kind: String, radius := 0.6) -> Node3D:
	var n := instance("characters/" + kind)
	if n != null:
		return n
	return placeholder(kind, radius)


static func placeholder(kind: String, radius := 0.6) -> Node3D:
	var root := Node3D.new()
	root.name = "Placeholder_" + kind
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = flat_material(PLACEHOLDER_COLORS.get(kind, Color(0.8, 0.8, 0.8)))
	root.add_child(mi)
	# 目（どっちが前かわかるように）
	for sx in [-0.35, 0.35]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = radius * 0.18
		em.height = radius * 0.36
		eye.mesh = em
		eye.material_override = flat_material(Color(0.1, 0.1, 0.15))
		eye.position = Vector3(sx * radius, radius * 0.3, -radius * 0.85)
		root.add_child(eye)
	return root


static func flat_material(color: Color, emission: Color = Color.BLACK, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.roughness = 0.85
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 1.2
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## モデルの大きさを「だいたいこの半径」に合わせる
static func fit(n: Node3D, target_radius: float) -> void:
	var aabb := _aabb(n)
	if aabb.size.length() < 0.001:
		return
	var r := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)) * 0.5
	if r > 0.001:
		n.scale = Vector3.ONE * (target_radius / r)


static func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [[n, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		if node is Node3D and node != n:
			xf = xf * (node as Node3D).transform
		if node is MeshInstance3D:
			var b: AABB = xf * (node as MeshInstance3D).get_aabb()
			if first:
				box = b
				first = false
			else:
				box = box.merge(b)
		for c in node.get_children():
			stack.append([c, xf])
	return box
