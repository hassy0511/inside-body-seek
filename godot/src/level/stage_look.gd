class_name StageLook
## 場所の 見た目：光・きり・面の 材質と 画像・小さな 動き（あわ、ゆれる のどちんこ）。Level が 呼ぶ。
##
## 場所の 辞書（StageDB）の "look" に 書いた 分だけ 変わる。"look" が 無い 場所は いままでと 同じ 見た目。
##
## 光と 空気（environment()）：
##   "background": Color          はいけいの 色（既定：fog）
##   "ambient_energy": 0.55       まわりの 明るさ（キャラクター用。色は 場所の "ambient"）
##   "fog_color": Color           きりの 色（既定：fog を 少し 暗く）
##   "fog_depth": [はじまり m, おわり m]   きりを「きょりで 決まる」形に する（近くは きりなし）。無ければ いままでの きり
##   "fog_curve": 1.0             fog_depth の かかりかた（大きいほど 遠くで 急に こく なる）
##   "tonemap": "filmic"          "linear"／"reinhard"／"filmic"／"aces"、"exposure": 0.9、"white": 1.0
##   "sun": Vector3(-55, 30, 0)   たいようの 向き（度）、"sun_energy": 0.75、"sun_color": Color
##   "shadows": false             たいようの かげ。"shadow_opacity": 1.0、"shadow_blur": 1.0、"shadow_distance": 100.0、"shadow_size": 4096
##   "glow": 0.0                  光る ものの にじみ（0 で なし）、"glow_bloom": 0.0、"glow_threshold": 1.0
## 面（apply()）：GLB の マテリアル名「Stage<役わり>」（StageFloor、StageWall …）ごとに
##   "surfaces": {"floor": {"color": Color, "tile": 4.0, "rim": 0.12, "shadow": false, "glow": 0.0}, ...}
##   画像 res://assets/textures/stages/tex_<場所の id>_<役わり>.png が あれば 自動で はる（色は 画像の 色に なる）。
##   "shadow": true の 面は かげを 落とす。"glow" が 0 より 大きい 面は 光る 面（光・きりを 受けない）。
##   "hemi_up"／"hemi_down": Color   上向き／下向きの 面の まわりの 明るさ（場所 ぜんたい）
##   "light_gain": 1.0、"light_wrap": 0.6   たいようの 光を 面が 受ける 強さと、かげの さかいの やわらかさ
##   "lamp_gain": 1.0             ミクロごうの ライトを 面が 受ける 強さ（light_gain に かける）
##   "fill": Vector3（度）、"fill_energy": 0.4、"fill_color": Color   面だけを てらす 2 つめの 光（かげなし。キャラクターには 当たらない）
## 動き（apply() の 中）：
##   "sway": {"NC_Uvula": [ゆれる 角度（度）, 1 往復の 秒]}
##   "bubbles": {"count": 14, "center": Vector3, "extents": Vector3, "size": [0.2, 0.6], "color": Color}

const TEX_DIR := "res://assets/textures/stages/"
const ClayShader := preload("res://assets/shaders/stage_clay.gdshader")
const GlowShader := preload("res://assets/shaders/stage_glow.gdshader")
const BubbleShader := preload("res://assets/shaders/stage_bubble.gdshader")
## 場所の 面だけが 入る 描画レイヤー（"fill" の 光は ここだけを てらす）
const STAGE_LAYER := 2
const TONEMAPS := {
	"linear": Environment.TONE_MAPPER_LINEAR, "reinhard": Environment.TONE_MAPPER_REINHARDT,
	"filmic": Environment.TONE_MAPPER_FILMIC, "aces": Environment.TONE_MAPPER_ACES,
}


## 光・きり・たいようを 作って level に 付ける
static func environment(level: Node3D, stage: Dictionary) -> void:
	var look: Dictionary = stage.get("look", {})
	var fog: Color = stage.get("fog", Color(0.9, 0.7, 0.7))
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = look.get("background", fog)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = stage.get("ambient", Color(1, 0.9, 0.9))
	e.ambient_light_energy = float(look.get("ambient_energy", 0.55))
	e.fog_enabled = true
	e.fog_light_color = look.get("fog_color", fog.darkened(0.1))
	e.fog_density = float(stage.get("fog_density", 0.015)) * 0.6
	e.fog_sky_affect = 0.0
	if look.has("fog_depth"):
		e.fog_mode = Environment.FOG_MODE_DEPTH
		e.fog_depth_begin = float(look["fog_depth"][0])
		e.fog_depth_end = float(look["fog_depth"][1])
		e.fog_depth_curve = float(look.get("fog_curve", 1.0))
		e.fog_density = 1.0
	e.tonemap_mode = TONEMAPS.get(look.get("tonemap", "filmic"), Environment.TONE_MAPPER_FILMIC)
	e.tonemap_exposure = float(look.get("exposure", 0.9))
	e.tonemap_white = float(look.get("white", 1.0))
	var glow := float(look.get("glow", 0.0))
	if glow > 0.0:
		e.glow_enabled = true
		e.glow_intensity = glow
		e.glow_bloom = float(look.get("glow_bloom", 0.0))
		e.glow_hdr_threshold = float(look.get("glow_threshold", 1.0))
		e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	we.environment = e
	level.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = look.get("sun", Vector3(-55, 30, 0))
	sun.light_energy = float(look.get("sun_energy", 0.75))
	sun.light_color = look.get("sun_color", Color(1.0, 0.97, 0.9))
	sun.shadow_enabled = bool(look.get("shadows", false))
	if sun.shadow_enabled:
		sun.shadow_opacity = float(look.get("shadow_opacity", 1.0))
		sun.shadow_blur = float(look.get("shadow_blur", 1.0))
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = float(look.get("shadow_distance", 100.0))
		sun.shadow_bias = 0.08
		sun.shadow_normal_bias = 2.0
		RenderingServer.directional_shadow_atlas_set_size(int(look.get("shadow_size", 4096)), true)
	level.add_child(sun)
	if look.has("fill"):
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = look["fill"]
		fill.light_energy = float(look.get("fill_energy", 0.4))
		fill.light_color = look.get("fill_color", Color(1.0, 0.95, 0.9))
		fill.shadow_enabled = false
		fill.light_cull_mask = STAGE_LAYER
		level.add_child(fill)


## GLB の 面に 材質を つけ、小さな 動きを 足す。"look" に "surfaces" が 無ければ 何も しない
static func apply(env: Node3D, stage: Dictionary) -> void:
	var look: Dictionary = stage.get("look", {})
	var surfaces: Dictionary = look.get("surfaces", {})
	if not surfaces.is_empty():
		var made := {}
		for n in env.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var casts := false
			for i in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(i)
				var role := role_of(src.resource_name if src != null else "")
				if not surfaces.has(role):
					continue
				if not made.has(role):
					made[role] = material(String(stage["id"]), role, surfaces[role], look)
				mi.set_surface_override_material(i, made[role])
				casts = casts or bool(surfaces[role].get("shadow", false))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.layers |= STAGE_LAYER
	var sway: Dictionary = look.get("sway", {})
	for node_name in sway.keys():
		var node := env.find_child(String(node_name), true, false) as Node3D
		if node != null:
			_sway(node, deg_to_rad(float(sway[node_name][0])), float(sway[node_name][1]))
	if look.has("bubbles"):
		env.add_child(_bubbles(look["bubbles"]))


## マテリアル名「StageFloor」→ 役わり "floor"（ちがう 名前は ""）
static func role_of(material_name: String) -> String:
	return material_name.substr(5).to_lower() if material_name.begins_with("Stage") else ""


## 役わりの 画像（tex_<場所>_<役わり>.png）。無ければ null
static func texture(stage_id: String, role: String) -> Texture2D:
	var path := "%stex_%s_%s.png" % [TEX_DIR, stage_id, role]
	if ResourceLoader.exists(path):
		var t := load(path)
		if t is Texture2D:
			return t
	return null


static func material(stage_id: String, role: String, s: Dictionary, look: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var color: Color = s.get("color", Color.WHITE)
	if float(s.get("glow", 0.0)) > 0.0:
		m.shader = GlowShader
		m.set_shader_parameter("tint", color)
		m.set_shader_parameter("energy", float(s["glow"]))
		return m
	m.shader = ClayShader
	var tex := texture(stage_id, role)
	if tex != null:
		color = s.get("tex_tint", Color.WHITE)
		m.set_shader_parameter("tex", tex)
		m.set_shader_parameter("tex_amount", 1.0)
		m.set_shader_parameter("tile", float(s.get("tile", 4.0)))
	m.set_shader_parameter("tint", color)
	var up: Color = look.get("hemi_up", Color(0.6, 0.6, 0.6))
	var down: Color = look.get("hemi_down", Color(0.45, 0.45, 0.45))
	m.set_shader_parameter("hemi_up", Vector3(up.r, up.g, up.b))
	m.set_shader_parameter("hemi_down", Vector3(down.r, down.g, down.b))
	m.set_shader_parameter("rim", float(s.get("rim", 0.12)))
	m.set_shader_parameter("light_gain", float(look.get("light_gain", 1.0)))
	m.set_shader_parameter("light_wrap", float(look.get("light_wrap", 0.6)))
	m.set_shader_parameter("lamp_gain", float(look.get("lamp_gain", 1.0)))
	return m


## ゆっくり 左右に ゆらす（原点が ねもとの 部品）
static func _sway(node: Node3D, angle: float, seconds: float) -> void:
	node.rotation.z = -angle
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "rotation:z", angle, seconds * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "rotation:z", -angle, seconds * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tw2 := node.create_tween().set_loops()
	tw2.tween_property(node, "rotation:x", angle * 0.5, seconds * 0.37).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(node, "rotation:x", -angle * 0.5, seconds * 0.37).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## ゆっくり のぼる 大きめの あわを 少しだけ
static func _bubbles(b: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Bubbles"
	p.amount = int(b.get("count", 14))
	p.lifetime = float(b.get("life", 14.0))
	p.preprocess = p.lifetime
	p.position = b.get("center", Vector3.ZERO)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = b.get("extents", Vector3(10, 3, 10))
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.6
	var size: Array = b.get("size", [0.2, 0.6])
	p.scale_amount_min = float(size[0])
	p.scale_amount_max = float(size[1])
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.12, 0.85, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 16
	sm.rings = 8
	p.mesh = sm
	var m := ShaderMaterial.new()
	m.shader = BubbleShader
	var c: Color = b.get("color", Color(1.0, 0.95, 0.95))
	m.set_shader_parameter("tint", Color(c.r, c.g, c.b))
	m.set_shader_parameter("alpha", c.a)
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
