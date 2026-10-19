extends Control
## タイトル画面（ending_mode = true のときは エンディング）。

const T := preload("res://src/ui/ui_theme.gd")

var ending_mode := false
var _bubbles: Array = []
var _t := 0.0
var _keyvisual: Texture2D = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 28:
		_bubbles.append({"x": randf(), "y": randf(), "r": randf_range(8, 40), "s": randf_range(0.02, 0.06)})
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.anchor_left = 0.5
	vb.anchor_right = 0.5
	vb.anchor_top = 0.5
	vb.anchor_bottom = 0.5
	vb.offset_left = -420
	vb.offset_right = 420
	vb.offset_top = -260
	vb.offset_bottom = 260
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	add_child(vb)

	# 納品された絵（docs/art_orders/W4_01_UI.md）：背景・ロゴ・はなちゃん。無ければ コードで描く仮の見た目
	_keyvisual = T.art("title_keyvisual")

	if ending_mode:
		var p := PanelContainer.new()
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 14)
		p.add_child(pv)
		var hana := T.art_rect("hana_fullbody_happy", Vector2(240, 360))
		if hana:
			hana.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
			hana.anchor_top = 1.0
			hana.anchor_bottom = 1.0
			hana.offset_left = 30
			hana.offset_right = 270
			hana.offset_top = -380
			hana.offset_bottom = -20
			add_child(hana)
			move_child(hana, 0)
		pv.add_child(T.label("おめでとう！ ぜんぶ クリア！", 40, T.INK, HORIZONTAL_ALIGNMENT_CENTER))
		var body := T.label(StageDB.STORY_ENDING, 26)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_override("font", Game.font_regular)
		pv.add_child(body)
		pv.add_child(T.label("あつめた ほし： %d / %d" % [SaveData.total_stars(), StageDB.STAGES.size() * 3], 26, T.INK, HORIZONTAL_ALIGNMENT_CENTER))
		vb.add_child(p)
		var back := T.button("タイトルへ", 30)
		back.pressed.connect(func(): Game.show_title())
		vb.add_child(back)
		back.grab_focus()
		Sfx.play("clear")
		return

	var logo := T.art_rect("title_logo", Vector2(520, 228))
	if logo:
		vb.add_child(logo)
	else:
		var title := T.label("からだのなか", 72, T.INK, HORIZONTAL_ALIGNMENT_CENTER)
		vb.add_child(title)
		var title2 := T.label("だいぼうけん", 72, Color(0.9, 0.35, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
		vb.add_child(title2)
	var sub := T.label("ちいさくなって からだのなかを たんけんしよう！", 24, Color(0.45, 0.35, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	if _keyvisual:
		# 納品された背景の上でも読めるように、白い ふちを付ける
		sub.add_theme_color_override("font_color", Color.WHITE)
		sub.add_theme_color_override("font_outline_color", Color(0.3, 0.15, 0.25))
		sub.add_theme_constant_override("outline_size", 8)
	vb.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	vb.add_child(sp)

	var start := T.button("はじめる", 36, 320)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(func(): Sfx.play("click"); Game.show_stage_select())
	vb.add_child(start)
	var zukan := T.button("ずかん", 30, 320)
	zukan.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	T.colored_button(zukan, T.MINT, Color(0.35, 0.7, 0.5))
	zukan.pressed.connect(func(): Sfx.play("click"); Game.show_zukan())
	vb.add_child(zukan)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	var touch := CheckButton.new()
	touch.text = "タッチそうさ"
	touch.button_pressed = Game.touch_effective()
	touch.toggled.connect(func(on): SaveData.set_setting("touch", "on" if on else "off"))
	hb.add_child(touch)
	var reset := T.button("きろくを けす", 20)
	T.colored_button(reset, Color(0.92, 0.9, 0.9), Color(0.7, 0.65, 0.68))
	reset.pressed.connect(_confirm_reset)
	hb.add_child(reset)
	vb.add_child(hb)
	var stars := T.label("あつめた ほし： %d / %d" % [SaveData.total_stars(), StageDB.STAGES.size() * 3], 22, Color(0.75, 0.55, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	if _keyvisual:
		stars.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
		stars.add_theme_color_override("font_outline_color", Color(0.3, 0.15, 0.25))
		stars.add_theme_constant_override("outline_size", 8)
	vb.add_child(stars)
	start.grab_focus()
	_add_pod_preview()


func _add_pod_preview() -> void:
	var model := ModelLib.character("pod", 0.7)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	svc.anchor_left = 1.0
	svc.anchor_top = 1.0
	svc.anchor_right = 1.0
	svc.anchor_bottom = 1.0
	svc.offset_left = -360
	svc.offset_top = -360
	svc.offset_right = -10
	svc.offset_bottom = -10
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv := SubViewport.new()
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.size = Vector2i(Vector2(350, 350) * T.window_scale(self))
	svc.add_child(sv)
	var cam := Camera3D.new()
	cam.position = Vector3(0.6, 0.8, -3.4)
	cam.look_at_from_position(cam.position, Vector3(0, 0, 0), Vector3.UP)
	cam.fov = 40
	sv.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	sv.add_child(light)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.9, 0.95)
	we.environment = e
	sv.add_child(we)
	var pivot := Node3D.new()
	ModelLib.fit(model, 1.0)
	pivot.add_child(model)
	sv.add_child(pivot)
	var tw := create_tween().set_loops()
	tw.tween_property(pivot, "rotation:y", TAU, 7.0).from(0.0)
	add_child(svc)
	move_child(svc, 0)


func _confirm_reset() -> void:
	# ゲームと同じ見た目の かくにん画面（「やめる」が最初に選ばれている）
	var prev := get_viewport().gui_get_focus_owner()
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.1, 0.15, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -130
	panel.offset_bottom = 130
	ov.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)
	var msg := T.label("ほしや ずかんの きろくを ぜんぶ けします。\nいいですか？", 26, T.INK, HORIZONTAL_ALIGNMENT_CENTER)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(msg)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 24)
	var no := T.button("やめる", 28, 200)
	var yes := T.button("けす", 28, 200)
	T.colored_button(yes, Color(0.92, 0.9, 0.9), Color(0.7, 0.65, 0.68))
	no.pressed.connect(func():
		ov.queue_free()
		if is_instance_valid(prev):
			prev.grab_focus())
	yes.pressed.connect(func(): SaveData.reset(); Game.show_title())
	hb.add_child(no)
	hb.add_child(yes)
	vb.add_child(hb)
	Game.add_overlay(ov)
	no.grab_focus()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var sz := size
	if _keyvisual:
		# 画面いっぱいに（縦横比を保って はみ出す側を切る）
		var ts := _keyvisual.get_size()
		var k := maxf(sz.x / ts.x, sz.y / ts.y)
		var dst := Rect2((sz - ts * k) * 0.5, ts * k)
		draw_texture_rect(_keyvisual, dst, false)
		return
	draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 0.85, 0.88))
	draw_rect(Rect2(0, sz.y * 0.6, sz.x, sz.y * 0.4), Color(1.0, 0.78, 0.84))
	for b in _bubbles:
		b["y"] -= b["s"] * get_process_delta_time() * 1.0
		if b["y"] < -0.1:
			b["y"] = 1.1
			b["x"] = randf()
		var p := Vector2(b["x"] * sz.x + sin(_t + b["r"]) * 10.0, b["y"] * sz.y)
		draw_circle(p, b["r"], Color(1, 1, 1, 0.35))
		draw_arc(p, b["r"], 0, TAU, 32, Color(1, 1, 1, 0.6), 2)
