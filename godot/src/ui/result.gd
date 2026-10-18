extends Control
## けっか画面：ほし → まとめカード → クイズ → つぎへ。

signal finished(stars: int, go_next: bool)

const T := preload("res://src/ui/ui_theme.gd")

var stage: Dictionary
var no_damage := false
var quiz_correct := false
var _vb: VBoxContainer
var _panel: PanelContainer
var _phase := 0


func setup(s: Dictionary, nd: bool) -> void:
	stage = s
	no_damage = nd


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(1.0, 0.92, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -470
	_panel.offset_right = 470
	_panel.offset_top = -300
	_panel.offset_bottom = 300
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_panel.add_child(margin)
	_vb = VBoxContainer.new()
	_vb.add_theme_constant_override("separation", 14)
	margin.add_child(_vb)
	_show_stars()


func _clear() -> void:
	for c in _vb.get_children():
		c.queue_free()


func stars_count() -> int:
	return 1 + (1 if no_damage else 0) + (1 if quiz_correct else 0)


func _show_stars() -> void:
	_phase = 0
	_clear()
	_vb.add_child(T.label("ステージ クリア！", 48, Color(0.9, 0.35, 0.5), HORIZONTAL_ALIGNMENT_CENTER))
	_vb.add_child(T.label("%s（%s）　%s" % [stage["name"], stage["kanji"], stage["title"]], 26, T.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var stars := Control.new()
	stars.custom_minimum_size = Vector2(0, 120)
	var shown := [true, no_damage, false]
	stars.draw.connect(func():
		var cx := stars.size.x * 0.5
		for i in 3:
			var c := Vector2(cx + (i - 1) * 120, 60)
			stars.draw_colored_polygon(T.star_points(c + Vector2(3, 4), 46), Color(0, 0, 0, 0.1))
			stars.draw_colored_polygon(T.star_points(c, 46), T.YELLOW if shown[i] else Color(0.88, 0.86, 0.87)))
	_vb.add_child(stars)
	var lines := VBoxContainer.new()
	lines.add_child(T.label("● クリア！", 24, Color(0.45, 0.7, 0.5)))
	lines.add_child(T.label(("● ハートを へらさずに クリア！" if no_damage else "○ ハートを へらさずに クリア（こんどは がんばろう）"), 24, Color(0.45, 0.7, 0.5) if no_damage else Color(0.6, 0.55, 0.58)))
	lines.add_child(T.label("○ クイズに せいかい（このあと！）", 24, Color(0.6, 0.55, 0.58)))
	_vb.add_child(lines)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vb.add_child(sp)
	var btn := T.button("つぎへ ▶", 32, 260)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.pressed.connect(_show_summary)
	_vb.add_child(btn)
	btn.grab_focus()
	Sfx.play("clear")
	if Game.testing:
		_show_summary.call_deferred()


func _show_summary() -> void:
	_phase = 1
	_clear()
	var card: Dictionary = stage["summary"]
	SaveData.mark_card(stage["id"], "summary")
	_vb.add_child(T.label("ものしりカード", 18, Color(0.75, 0.5, 0.2)))
	_vb.add_child(T.label(card["title"], 40))
	var body := T.label(card["text"], 26)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font", Game.font_regular)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vb.add_child(body)
	var btn := T.button("クイズに ちょうせん！", 30, 320)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.pressed.connect(_show_quiz)
	_vb.add_child(btn)
	btn.grab_focus()
	if Game.testing:
		_show_quiz.call_deferred()


func _show_quiz() -> void:
	_phase = 2
	_clear()
	var q: Dictionary = stage["quiz"]
	_vb.add_child(T.label("クイズ", 18, Color(0.3, 0.5, 0.75)))
	var ql := T.label(q["q"], 34)
	ql.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vb.add_child(ql)
	var choices: Array = q["choices"].duplicate()
	var order := [0, 1, 2]
	order.shuffle()
	var first: Button = null
	for i in order:
		var b := T.button(["Ａ", "Ｂ", "Ｃ"][order.find(i)] + "　" + choices[i], 28)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		T.colored_button(b, T.SKY, Color(0.3, 0.55, 0.8))
		b.pressed.connect(func(): _answer(i == int(q["answer"]), q.get("explain", "")))
		_vb.add_child(b)
		if first == null:
			first = b
	if first:
		first.grab_focus()
	if Game.testing:
		(func(): _answer(true, q.get("explain", ""))).call_deferred()


func _answer(correct: bool, explain: String) -> void:
	_phase = 3
	quiz_correct = correct
	_clear()
	Sfx.play("quiz_ok" if correct else "wrong")
	_vb.add_child(T.label("せいかい！" if correct else "ざんねん！", 48, Color(0.9, 0.35, 0.5) if correct else Color(0.4, 0.5, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	var ex := T.label(explain, 26)
	ex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ex.add_theme_font_override("font", Game.font_regular)
	_vb.add_child(ex)
	var stars := Control.new()
	stars.custom_minimum_size = Vector2(0, 110)
	var n := stars_count()
	stars.draw.connect(func():
		var cx := stars.size.x * 0.5
		for i in 3:
			var c := Vector2(cx + (i - 1) * 120, 55)
			stars.draw_colored_polygon(T.star_points(c, 44), T.YELLOW if i < n else Color(0.88, 0.86, 0.87)))
	_vb.add_child(stars)
	_vb.add_child(T.label("ほし %d こ ゲット！" % n, 28, T.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vb.add_child(sp)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 20)
	var back := T.button("ステージえらびへ", 26)
	back.pressed.connect(func(): finished.emit(stars_count(), false))
	hb.add_child(back)
	var next_id := StageDB.next_stage_id(stage["id"])
	var nxt := T.button("つぎの ステージへ ▶" if next_id != "" else "エンディングへ ▶", 30)
	T.colored_button(nxt, T.YELLOW, Color(0.85, 0.6, 0.1))
	nxt.pressed.connect(func(): finished.emit(stars_count(), true))
	hb.add_child(nxt)
	_vb.add_child(hb)
	nxt.grab_focus()
	if Game.testing:
		(func(): finished.emit(stars_count(), false)).call_deferred()
