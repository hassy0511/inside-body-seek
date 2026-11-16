extends "res://src/ui/flow_screen.gd"
## はなしの 画面（そうだん・あとの はなし の 両方）。1 ページずつ ボタンで 進む。
## 左に 話す 人の 絵（T.portrait）、右に 名前と ふきだし。ふきだしを タップしても 次へ。
## setup() の opts：
##   "banner"      上の 大きな 見出し（「い（胃）は げんき！」「ピコッと はっけん！」）
##   "last_label"  さいごの ページの ボタンの 文（既定「つぎへ ▶」）
##   "can_cancel"  最初の ページで もどれるか（もどる → cancelled）
##   "start_page"  何ページ目から 出すか（よそうから もどった とき ＝ さいごの ページ）
##   "mood"        患者の 顔（"sick"／"happy"）。ピコは 見出しが ある とき（はっけん）だけ "happy"
## 背景は consult_bg.png が あれば それ、無ければ コードで 描く しんりょうじょ。

signal finished
signal cancelled

## ふきだし（770×320）の 中の 文：32 px、幅 726、6 行まで（テストが 本物の フォントで はかる）
const TEXT_SIZE := 32
const TEXT_WIDTH := 726.0
const TEXT_LINES := 6
const BUBBLE_SIZE := Vector2(770, 320)
const PORTRAIT_POS := Vector2(30, 110)
const PORTRAIT_SIZE := Vector2(300, 400)

var lines: Array = []
var opts: Dictionary = {}
var page := 0
var _box: Control
var _backdrop: Panel
var _portrait: Control = null
var _portrait_key := ""
var _name: Label
var _name_chip: PanelContainer
var _bubble: PanelContainer
var _tail: Control
var _text: Label
var _dots: Label
var _next: Button
var _back: Button
var _color := Color.WHITE


static func text_fits(text: String) -> bool:
	return lines_of(text, TEXT_SIZE, TEXT_WIDTH) <= TEXT_LINES


func setup(l: Array, o := {}) -> void:
	lines = l
	opts = o


func _ready() -> void:
	_box = make_stage(Color(1.0, 0.96, 0.9))
	_add_background()
	# 「← もどる」：もどれる 画面の 最初の ページと、2 ページ目から（1 ページ もどる）に 出す
	_back = add_back_button(_on_back)
	var banner: String = opts.get("banner", "")
	if banner != "":
		# 見出しは 青（赤に しない：まちがいの 色に 見せない）。白い ふだに のせて ぽよんと 出す
		var bp := PanelContainer.new()
		bp.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 30, 5, Color(0.55, 0.78, 0.95)))
		bp.add_child(T.label(banner, 44, Color(0.25, 0.5, 0.75), HORIZONTAL_ALIGNMENT_CENTER))
		_box.add_child(bp)
		bp.size = bp.get_combined_minimum_size() + Vector2(40, 0)
		bp.position = Vector2((1180 - bp.size.x) * 0.5, 4)
		bp.pivot_offset = bp.size * 0.5
		bp.scale = Vector2(0.7, 0.7)
		create_tween().tween_property(bp, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play("card")
	# 絵の うしろの 台紙（話す 人の 色）
	_backdrop = Panel.new()
	_backdrop.position = PORTRAIT_POS
	_backdrop.size = PORTRAIT_SIZE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_backdrop)
	# 名前と ページの まるは 白い ふだに のせる（背景の 絵の 上でも 読める）
	_name_chip = PanelContainer.new()
	_name_chip.position = Vector2(386, 100)
	_name_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = T.label("", 24)
	_name_chip.add_child(_name)
	_box.add_child(_name_chip)
	_bubble = PanelContainer.new()
	_bubble.position = Vector2(370, 152)
	_bubble.size = BUBBLE_SIZE
	# ふきだしを タップしても 次へ
	_bubble.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_next())
	_box.add_child(_bubble)
	# ふきだしの しっぽ（絵の ほうへ）
	_tail = Control.new()
	_tail.position = Vector2(336, 250)
	_tail.size = Vector2(44, 60)
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tail.draw.connect(func():
		_tail.draw_colored_polygon(PackedVector2Array([Vector2(40, 0), Vector2(0, 30), Vector2(40, 60)]), _color)
		_tail.draw_colored_polygon(PackedVector2Array([Vector2(44, 8), Vector2(12, 30), Vector2(44, 52)]), Color.WHITE))
	_box.add_child(_tail)
	_text = T.body("", TEXT_SIZE)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_text)
	var dots_chip := PanelContainer.new()
	dots_chip.position = Vector2(386, 480)
	dots_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots_chip.add_theme_stylebox_override("panel", _chip_style(Color(1, 1, 1, 0.85), Color.TRANSPARENT))
	_dots = T.label("", 22, Color(0.5, 0.45, 0.5))
	dots_chip.add_child(_dots)
	_box.add_child(dots_chip)
	_next = T.button("つぎへ ▶", 30)
	_next.position = Vector2(820, 548)
	_next.size = Vector2(320, 78)
	T.colored_button(_next, T.YELLOW, T.YELLOW_DARK)
	_next.pressed.connect(_on_next)
	_box.add_child(_next)
	page = clampi(int(opts.get("start_page", 0)), 0, lines.size() - 1)
	_show()


## 背景：納品された 絵（consult_bg.png）を 全面に。無ければ かべ ＋ ゆか ＋ まどの 仮の しんりょうじょ
func _add_background() -> void:
	var bg := Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := T.art("consult_bg")
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(tr)
	else:
		bg.draw.connect(func():
			var s := bg.size
			var floor_y := s.y * 0.76
			bg.draw_rect(Rect2(0, floor_y, s.x, s.y - floor_y), Color(0.98, 0.88, 0.76))
			bg.draw_rect(Rect2(0, floor_y, s.x, 8), Color(0.93, 0.8, 0.66))
			# まど（右上）
			var win := Rect2(s.x - 250, 30, 190, 84)
			bg.draw_style_box(T.rounded(Color(0.8, 0.93, 1.0), 16, 6, Color.WHITE), win)
			bg.draw_line(win.position + Vector2(win.size.x * 0.5, 4), win.position + Vector2(win.size.x * 0.5, win.size.y - 4), Color.WHITE, 6))
	add_child(bg)
	move_child(bg, 1)   # 背景色の 上、入れ物の 下


## ページを 出す（出す たびに「つぎへ」へ フォーカス ＋ 押しすぎ よけ）
func _show() -> void:
	var id: String = lines[page]["who"]
	var who: Dictionary = EpisodeDB.speaker(id)
	_color = who["color"]
	var mood: String = opts.get("mood", "sick")
	if id == "pico":
		mood = "happy" if opts.get("banner", "") != "" else "normal"
	# 絵は 話す 人（と 顔）が 変わった ときだけ 作りなおす
	var key := "%s:%s" % [id, mood]
	if key != _portrait_key:
		_portrait_key = key
		if _portrait != null:
			_portrait.queue_free()
		_portrait = T.portrait(id, mood, PORTRAIT_SIZE, _color, true)
		_portrait.position = PORTRAIT_POS
		_box.add_child(_portrait)
		_box.move_child(_portrait, _backdrop.get_index() + 1)
		_backdrop.add_theme_stylebox_override("panel", T.rounded(_color.lerp(Color.WHITE, 0.55), 40, 5, Color.WHITE))
	_name.text = who["name"]
	_name.add_theme_color_override("font_color", _color.darkened(0.5))
	_name_chip.add_theme_stylebox_override("panel", _chip_style(Color.WHITE, _color))
	_name_chip.size = Vector2.ZERO   # 名前の 長さに 合わせて ちぢむ
	_bubble.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 30, 6, _color))
	_tail.queue_redraw()
	_text.text = T.nobreak(lines[page]["text"])
	var dots := ""
	for i in lines.size():
		dots += ("● " if i == page else "○ ")
	_dots.text = dots.strip_edges()
	_dots.get_parent().visible = lines.size() > 1
	_dots.get_parent().size = Vector2.ZERO
	_next.text = opts.get("last_label", "つぎへ ▶") if page == lines.size() - 1 else "つぎへ ▶"
	_back.visible = page > 0 or opts.get("can_cancel", false)
	set_focus(_next)
	lock()


## 名前・ページの まるの 小さい ふだ
func _chip_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := T.rounded(bg, 18, 3 if border.a > 0.0 else 0, border)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


## ふきだしの 中身が 箱に 入って いるか（テストが 見る）
func fits() -> bool:
	return _bubble.get_combined_minimum_size().y <= BUBBLE_SIZE.y


func _on_next() -> void:
	if locked():
		return
	Sfx.play("click")
	if page + 1 < lines.size():
		page += 1
		_show()
	else:
		finished.emit()


## もどる：1 ページ もどる（読みなおせる）。最初の ページなら、もどれる 画面の ときだけ cancelled
func _on_back() -> void:
	if page > 0:
		page -= 1
		_show()
	elif opts.get("can_cancel", false):
		cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
