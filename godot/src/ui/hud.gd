extends Control
## ゲーム中の表示：ハート・ミッション・メッセージ（ドクター・ピコ）・ポケット。

const T := preload("res://src/ui/ui_theme.gd")

var level: Node = null
var _hearts := 3
var _heart_box: Control
var _mission_box: VBoxContainer
var _mission_labels: Array[Label] = []
var _msg_panel: PanelContainer
var _msg_label: Label
var _msg_timer := 0.0
var _pocket: Label
var _stage_label: Label
var _pause_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE

	_heart_box = Control.new()
	_heart_box.position = Vector2(24, 20)
	_heart_box.custom_minimum_size = Vector2(200, 60)
	_heart_box.size = Vector2(200, 60)
	_heart_box.draw.connect(_draw_hearts)
	_heart_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heart_box)

	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -220
	top.offset_right = 220
	top.offset_top = 14
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", T.rounded(Color(1, 1, 1, 0.8), 20, 0))
	_stage_label = T.label("", 26, T.INK, HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(_stage_label)
	add_child(top)

	var mp := PanelContainer.new()
	mp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mp.anchor_left = 1.0
	mp.anchor_right = 1.0
	mp.offset_left = -520
	mp.offset_right = -24
	mp.offset_top = 110
	mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp.add_theme_stylebox_override("panel", T.rounded(Color(1, 1, 1, 0.82), 20, 0))
	_mission_box = VBoxContainer.new()
	_mission_box.add_theme_constant_override("separation", 6)
	mp.add_child(_mission_box)
	add_child(mp)

	_pause_btn = T.button("❚❚", 30)
	_pause_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pause_btn.anchor_left = 1.0
	_pause_btn.anchor_right = 1.0
	_pause_btn.offset_left = -120
	_pause_btn.offset_right = -20
	_pause_btn.offset_top = 14
	_pause_btn.offset_bottom = 98
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.pressed.connect(func(): Game.toggle_pause())
	add_child(_pause_btn)

	_pocket = T.label("", 24, T.INK)
	_pocket.position = Vector2(24, 86)
	add_child(_pocket)

	_msg_panel = PanelContainer.new()
	_msg_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_msg_panel.anchor_left = 0.5
	_msg_panel.anchor_right = 0.5
	_msg_panel.anchor_top = 1.0
	_msg_panel.anchor_bottom = 1.0
	_msg_panel.offset_left = -430
	_msg_panel.offset_right = 430
	_msg_panel.offset_top = -200
	_msg_panel.offset_bottom = -26
	_msg_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_panel.add_theme_stylebox_override("panel", T.rounded(Color(1, 1, 1, 0.92), 26, 4, T.SKY))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	# 納品された顔（ui/pico_face_normal.png）があれば それ、なければ コードで描く仮の顔
	var face: Control = T.art_rect("pico_face_normal", Vector2(90, 90))
	if face == null:
		face = Control.new()
		face.custom_minimum_size = Vector2(90, 90)
		face.draw.connect(func(): _draw_pico(face))
	hb.add_child(face)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(T.label("ドクター・ピコ", 18, Color(0.3, 0.5, 0.7)))
	_msg_label = T.label("", 30)
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_msg_label)
	hb.add_child(vb)
	_msg_panel.add_child(hb)
	_msg_panel.visible = false
	add_child(_msg_panel)


func bind_level(l: Node) -> void:
	level = l
	_stage_label.text = "%d  %s（%s）" % [l.stage["order"], l.stage["name"], l.stage["kanji"]]
	l.missions_changed.connect(_refresh_missions)
	l.hearts_changed.connect(func(h): _hearts = h; _heart_box.queue_redraw())
	_refresh_missions()


func _refresh_missions() -> void:
	for c in _mission_box.get_children():
		c.queue_free()
	_mission_labels.clear()
	if level == null:
		return
	for m in level.missions:
		var l := T.label(("● " if m.done else "○ ") + m.label(), 24, Color(0.45, 0.7, 0.5) if m.done else T.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_mission_box.add_child(l)
		_mission_labels.append(l)


func _process(delta: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			_msg_panel.visible = false
	if level and level.player:
		var n := 0
		for it in level.player.inventory:
			if it == "nutrient":
				n += 1
		_pocket.text = ("ポケット：えいよう × %d" % n) if n > 0 else ""


func is_busy() -> bool:
	return _msg_panel.visible and _msg_timer > 0.0


func say(text: String, seconds := 4.0) -> void:
	_msg_label.text = text
	_msg_panel.visible = true
	# タッチ操作のボタンと重ならないように、タッチのときは少し細くする
	var touch_on: bool = Game.touch_controls != null and is_instance_valid(Game.touch_controls) and Game.touch_controls.visible
	_msg_panel.offset_left = -360 if touch_on else -430
	_msg_panel.offset_right = 360 if touch_on else 430
	_msg_timer = seconds
	_msg_panel.scale = Vector2(0.9, 0.9)
	_msg_panel.pivot_offset = _msg_panel.size * 0.5
	var t := create_tween()
	t.tween_property(_msg_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw_hearts() -> void:
	for i in 3:
		var c := Vector2(30 + i * 56, 32)
		var col := Color(1.0, 0.35, 0.45) if i < _hearts else Color(0.85, 0.8, 0.82, 0.7)
		T.draw_heart(_heart_box, c + Vector2(2, 3), 22, Color(0, 0, 0, 0.12))
		T.draw_heart(_heart_box, c, 22, col)


static func _draw_pico(ci: Control) -> void:
	var c := Vector2(45, 48)
	ci.draw_circle(c + Vector2(0, 2), 36, Color(0.3, 0.45, 0.6, 0.25))
	ci.draw_circle(c, 34, Color(0.75, 0.92, 1.0))
	ci.draw_line(c + Vector2(0, -34), c + Vector2(0, -46), Color(0.3, 0.45, 0.6), 4)
	ci.draw_circle(c + Vector2(0, -48), 6, Color(1.0, 0.8, 0.3))
	ci.draw_circle(c + Vector2(-12, -4), 6, Color(0.2, 0.2, 0.3))
	ci.draw_circle(c + Vector2(12, -4), 6, Color(0.2, 0.2, 0.3))
	ci.draw_circle(c + Vector2(-10, -6), 2, Color.WHITE)
	ci.draw_circle(c + Vector2(14, -6), 2, Color.WHITE)
	ci.draw_arc(c + Vector2(0, 8), 10, 0.2, PI - 0.2, 12, Color(0.2, 0.2, 0.3), 3)
