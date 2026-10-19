extends Control
## ステージえらび。からだの絵の上に 番号ボタン。右に ステージの説明と「スタート」。

const T := preload("res://src/ui/ui_theme.gd")

## からだの絵の中での位置（0〜1）
const ORGAN_POS := {
	"brain": Vector2(0.50, 0.085), "nose": Vector2(0.62, 0.17), "mouth": Vector2(0.50, 0.23),
	"esophagus": Vector2(0.50, 0.33), "lungs": Vector2(0.34, 0.42), "heart": Vector2(0.58, 0.40), "heart2": Vector2(0.72, 0.47),
	"stomach": Vector2(0.58, 0.54), "intestine": Vector2(0.50, 0.66), "vessel": Vector2(0.20, 0.58),
}

var selected := ""
var _info: VBoxContainer
var _start_btn: Button
var _buttons: Dictionary = {}
var _map: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.93, 0.95, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var back := T.button("← もどる", 24)
	back.position = Vector2(24, 20)
	back.pressed.connect(func(): Sfx.play("click"); Game.show_title())
	add_child(back)
	var head := T.label("どこへ いく？", 40, T.INK, HORIZONTAL_ALIGNMENT_CENTER)
	head.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	head.anchor_left = 0.5
	head.anchor_right = 0.5
	head.offset_left = -300
	head.offset_right = 300
	head.offset_top = 18
	add_child(head)

	# 画面の横幅が変わっても まんなかに まとまるように、横ならびの入れ物に入れる
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 0.0
	row.anchor_bottom = 0.0
	row.offset_left = -570
	row.offset_right = 570
	row.offset_top = 80
	row.offset_bottom = 700
	row.add_theme_constant_override("separation", 60)
	add_child(row)
	_map = Control.new()
	_map.custom_minimum_size = Vector2(440, 620)
	_map.size = Vector2(440, 620)
	_map.draw.connect(_draw_body)
	row.add_child(_map)
	var tex_path := "res://assets/ui/body_map.svg"
	if ResourceLoader.exists(tex_path):
		var tr := TextureRect.new()
		tr.texture = load(tex_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map.add_child(tr)

	var first_unlocked := ""
	for s in StageDB.STAGES:
		var id: String = s["id"]
		var b := Button.new()
		b.text = str(s["order"])
		b.custom_minimum_size = Vector2(62, 62)
		b.add_theme_font_size_override("font_size", 28)
		var unlocked := SaveData.is_unlocked(id)
		var cleared := SaveData.is_cleared(id)
		var col := T.YELLOW if cleared else (T.SKY if unlocked else Color(0.85, 0.85, 0.87))
		var border := Color(0.8, 0.6, 0.1) if cleared else (Color(0.3, 0.55, 0.8) if unlocked else Color(0.6, 0.6, 0.62))
		T.colored_button(b, col, border)
		b.add_theme_stylebox_override("normal", T.rounded(col, 31, 3, border))
		b.add_theme_stylebox_override("hover", T.rounded(col.lightened(0.1), 31, 3, border))
		b.add_theme_stylebox_override("pressed", T.rounded(border, 31, 3, border))
		b.add_theme_stylebox_override("focus", T.outline(Color(0.9, 0.3, 0.5), 31, 5))
		b.disabled = not unlocked
		if not unlocked:
			b.focus_mode = Control.FOCUS_NONE
		var p: Vector2 = ORGAN_POS.get(id, Vector2(0.5, 0.5))
		b.position = Vector2(p.x * _map.size.x - 31, p.y * _map.size.y - 31)
		b.focus_entered.connect(func(): if selected != id: _select(id, false))
		b.pressed.connect(func(): _select(id, true))
		_map.add_child(b)
		_buttons[id] = b
		if unlocked and not cleared and first_unlocked == "":
			first_unlocked = id
	if first_unlocked == "":
		first_unlocked = StageDB.STAGES[0]["id"]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 560)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(panel)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 10)
	panel.add_child(_info)
	_select(first_unlocked, true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Sfx.play("click")
		Game.show_title()
		get_viewport().set_input_as_handled()


func _select(id: String, go_to_start := false) -> void:
	selected = id
	Sfx.play("click", 1.1)
	var s := StageDB.get_stage(id)
	for c in _info.get_children():
		c.queue_free()
	_info.add_child(T.label("ステージ %d" % s["order"], 20, Color(0.5, 0.45, 0.5)))
	_info.add_child(T.label("%s（%s）" % [s["name"], s["kanji"]], 44, T.INK))
	_info.add_child(T.label(s["title"], 26, Color(0.9, 0.35, 0.5)))
	var diff: String = ["", "かんたん", "ふつう", "むずかしい"][int(s["difficulty"])]
	_info.add_child(T.label("むずかしさ： " + diff, 22))
	var stars := Control.new()
	stars.custom_minimum_size = Vector2(200, 50)
	var n := SaveData.stars(id)
	stars.draw.connect(func():
		for i in 3:
			var c := Vector2(30 + i * 56, 25)
			stars.draw_colored_polygon(T.star_points(c, 22), T.YELLOW if i < n else Color(0.85, 0.83, 0.85)))
	_info.add_child(stars)
	_info.add_child(T.label("ミッション", 22, Color(0.5, 0.45, 0.5)))
	for m in s["missions"]:
		var l := T.label("・" + m["text"], 22)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info.add_child(l)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.add_child(sp)
	_start_btn = T.button("スタート！", 36, 300)
	_start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	T.colored_button(_start_btn, T.YELLOW, Color(0.85, 0.6, 0.1))
	_start_btn.disabled = not SaveData.is_unlocked(id)
	_start_btn.pressed.connect(func(): Sfx.play("click"); Game.start_stage(id))
	_info.add_child(_start_btn)
	# ゲームパッド：番号ボタン → みぎ で スタート、スタート → ひだり で いまの番号へ
	if _buttons.has(id):
		_start_btn.focus_neighbor_left = _start_btn.get_path_to(_buttons[id])
		for k in _buttons.keys():
			_buttons[k].focus_neighbor_right = _buttons[k].get_path_to(_start_btn)
	if go_to_start and not _start_btn.disabled:
		_start_btn.grab_focus()
	for k in _buttons.keys():
		_buttons[k].scale = Vector2.ONE * (1.15 if k == id else 1.0)
		_buttons[k].pivot_offset = Vector2(31, 31)


func _draw_body() -> void:
	# SVG が無いときの 簡単な からだの絵
	if _map.get_child_count() > 0 and _map.get_child(0) is TextureRect:
		return
	var w := _map.size.x
	var h := _map.size.y
	var skin := Color(1.0, 0.9, 0.8)
	_map.draw_circle(Vector2(w * 0.5, h * 0.12), w * 0.17, skin)
	_map.draw_rect(Rect2(w * 0.3, h * 0.25, w * 0.4, h * 0.5), Color(0.75, 0.88, 1.0))
	_map.draw_rect(Rect2(w * 0.12, h * 0.28, w * 0.16, h * 0.4), skin)
	_map.draw_rect(Rect2(w * 0.72, h * 0.28, w * 0.16, h * 0.4), skin)
	_map.draw_rect(Rect2(w * 0.32, h * 0.75, w * 0.15, h * 0.22), Color(0.5, 0.6, 0.9))
	_map.draw_rect(Rect2(w * 0.53, h * 0.75, w * 0.15, h * 0.22), Color(0.5, 0.6, 0.9))
