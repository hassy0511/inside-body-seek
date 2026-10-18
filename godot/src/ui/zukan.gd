extends Control
## ずかん：見た ものしりカードを ステージごとに ならべる。

const T := preload("res://src/ui/ui_theme.gd")
const CardPopup := preload("res://src/ui/card.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.95, 1.0, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var back := T.button("← もどる", 24)
	back.position = Vector2(24, 20)
	back.pressed.connect(func(): Sfx.play("click"); Game.show_title())
	add_child(back)
	var head := T.label("からだの ずかん", 40, T.INK, HORIZONTAL_ALIGNMENT_CENTER)
	head.set_anchors_preset(Control.PRESET_CENTER_TOP)
	head.anchor_left = 0.5
	head.anchor_right = 0.5
	head.offset_left = -300
	head.offset_right = 300
	head.offset_top = 18
	add_child(head)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_top = 90
	sc.offset_left = 40
	sc.offset_right = -40
	sc.offset_bottom = -20
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 12)
	sc.add_child(vb)
	var seen_total := 0
	var total := 0
	var first_btn: Button = null
	for s in StageDB.STAGES:
		var sid: String = s["id"]
		vb.add_child(T.label("%d  %s（%s）" % [s["order"], s["name"], s["kanji"]], 28, Color(0.9, 0.35, 0.5)))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		var keys: Array = s["cards"].keys()
		keys.append("summary")
		for key in keys:
			var card: Dictionary = s["summary"] if key == "summary" else s["cards"][key]
			var seen := SaveData.card_seen(sid, key)
			total += 1
			if seen:
				seen_total += 1
			var b := T.button(card["title"] if seen else "？？？", 22)
			if seen:
				T.colored_button(b, T.CREAM, T.PINK)
				b.pressed.connect(func(): _open(card, key))
			else:
				b.disabled = true
			flow.add_child(b)
			if first_btn == null and seen:
				first_btn = b
		vb.add_child(flow)
	head.text = "からだの ずかん　（%d / %d）" % [seen_total, total]
	if first_btn:
		first_btn.grab_focus()
	else:
		back.grab_focus()


func _open(card: Dictionary, key: String) -> void:
	Sfx.play("card")
	var p := CardPopup.new()
	p.setup(card, key)
	Game.overlay_layer.add_child(p)
