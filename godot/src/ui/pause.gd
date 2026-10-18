extends Control
## ポーズ画面。つづける／もういちど／ステージえらびへ、音のおおきさ、タッチそうさ。

const T := preload("res://src/ui/ui_theme.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.1, 0.15, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -230
	panel.offset_bottom = 230
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)
	vb.add_child(T.label("ちょっと きゅうけい", 34, T.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var b1 := T.button("つづける", 30)
	b1.pressed.connect(func(): Game.toggle_pause())
	vb.add_child(b1)
	var b2 := T.button("さいしょから やりなおす", 26)
	b2.pressed.connect(func(): get_tree().paused = false; queue_free(); Game.retry_stage())
	vb.add_child(b2)
	var b3 := T.button("ステージえらびへ", 26)
	b3.pressed.connect(func(): get_tree().paused = false; queue_free(); Game.show_stage_select())
	vb.add_child(b3)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.add_child(T.label("おと", 24))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(SaveData.setting("volume", 0.8))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(240, 30)
	sl.value_changed.connect(func(v): Sfx.set_volume(v); SaveData.set_setting("volume", v))
	hb.add_child(sl)
	vb.add_child(hb)
	var cb := CheckButton.new()
	cb.text = "タッチそうさを つかう"
	cb.button_pressed = SaveData.setting("touch", "auto") == "on"
	cb.toggled.connect(func(on):
		SaveData.set_setting("touch", "on" if on else "off")
		if Game.touch_controls:
			Game.touch_controls.visible = Game.touch_controls.should_show())
	vb.add_child(cb)
	b1.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Game.toggle_pause()
		get_viewport().set_input_as_handled()
