extends Control
## ものしりカード。ゲームを止めて 1 枚見せる。「わかった！」で閉じる。

signal closed

const T := preload("res://src/ui/ui_theme.gd")

var _panel: PanelContainer
var _btn: Button
var _done := false


func _ready() -> void:
	if _btn:
		_btn.grab_focus()


func setup(card: Dictionary, image_kind := "") -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.1, 0.15, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -440
	_panel.offset_right = 440
	_panel.offset_top = -230
	_panel.offset_bottom = 230
	_panel.add_theme_stylebox_override("panel", T.rounded(T.CREAM, 30, 6, T.YELLOW))
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	margin.add_child(hb)

	var pic := _make_picture(image_kind)
	if pic:
		hb.add_child(pic)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	hb.add_child(vb)
	var tag := T.label("ものしりカード", 18, Color(0.75, 0.5, 0.2))
	vb.add_child(tag)
	var title := T.label(card.get("title", ""), 40, T.INK)
	vb.add_child(title)
	var body := T.label(card.get("text", ""), 25, T.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_override("font", Game.font_regular)
	vb.add_child(body)
	_btn = T.button("わかった！", 30, 240)
	_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_btn.pressed.connect(close)
	vb.add_child(_btn)

	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.7, 0.7)
	var t := create_tween()
	t.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_picture(kind: String) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(260, 300)
	var model_name := kind
	if kind == "stage" or kind == "goal" or kind == "":
		model_name = "pico"
	if kind == "nutrient":
		model_name = "nutrient_a"
	var model := ModelLib.instance("characters/" + model_name)
	if model == null and ModelLib.PLACEHOLDER_COLORS.has(model_name):
		model = ModelLib.placeholder(model_name, 0.7)
	if model == null:
		var circle := Control.new()
		circle.custom_minimum_size = Vector2(260, 300)
		circle.draw.connect(func():
			circle.draw_circle(Vector2(130, 150), 90, T.PINK_LIGHT)
			circle.draw_circle(Vector2(130, 150), 72, T.PINK))
		return circle
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sv := SubViewport.new()
	sv.transparent_bg = true
	sv.size = Vector2i(260, 300)
	sv.own_world_3d = true
	svc.add_child(sv)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.6, 3.6)
	cam.look_at_from_position(cam.position, Vector3(0, 0.1, 0), Vector3.UP)
	cam.fov = 40
	sv.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 35, 0)
	sv.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 0.95)
	e.ambient_light_energy = 1.0
	env.environment = e
	sv.add_child(env)
	var pivot := Node3D.new()
	ModelLib.fit(model, 1.1)
	pivot.add_child(model)
	sv.add_child(pivot)
	var spin := create_tween().set_loops()
	spin.tween_property(pivot, "rotation:y", TAU, 6.0).from(0.0)
	box.add_child(svc)
	return box


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if _done:
		return
	_done = true
	Sfx.play("click")
	var t := create_tween()
	t.tween_property(_panel, "scale", Vector2(0.8, 0.8), 0.12)
	t.tween_callback(func():
		closed.emit()
		queue_free())
