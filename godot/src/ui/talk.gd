extends "res://src/ui/flow_screen.gd"
## はなしの 画面（そうだん・あとの はなし の 両方）。1 ページずつ ボタンで 進む。
## setup() の opts：
##   "banner"      上の 大きな 見出し（「い（胃）は げんき！」「ピコッと はっけん！」）
##   "last_label"  さいごの ページの ボタンの 文（既定「つぎへ ▶」）
##   "can_cancel"  最初の ページで もどれるか（もどる → cancelled）
##   "start_page"  何ページ目から 出すか（よそうから もどった とき ＝ さいごの ページ）
##   "mood"        患者の 顔（"sick"／"happy"）。絵の 口が できたら 使う
## 見た目は まだ 最小（話す 人の 名前・ふきだし・ページの まる）。人物の 絵と 仕上げは docs/episodes.md 3.4 B。

signal finished
signal cancelled

## ふきだし（770×320）の 中の 文：32 px、幅 726、6 行まで（テストが 本物の フォントで はかる）
const TEXT_SIZE := 32
const TEXT_WIDTH := 726.0
const TEXT_LINES := 6

var lines: Array = []
var opts: Dictionary = {}
var page := 0
var _name: Label
var _bubble: PanelContainer
var _text: Label
var _dots: Label
var _next: Button


static func text_fits(text: String) -> bool:
	return lines_of(text, TEXT_SIZE, TEXT_WIDTH) <= TEXT_LINES


func setup(l: Array, o := {}) -> void:
	lines = l
	opts = o


func _ready() -> void:
	var box := make_stage(Color(1.0, 0.96, 0.9))
	if opts.get("can_cancel", false):
		add_back_button(_on_back)
	var banner: String = opts.get("banner", "")
	if banner != "":
		# 見出しは 青（赤に しない：まちがいの 色に 見せない）
		var bl := T.label(banner, 48, Color(0.25, 0.5, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
		bl.position = Vector2(0, 6)
		bl.size = Vector2(1180, 80)
		box.add_child(bl)
		Sfx.play("card")
	_name = T.label("", 24)
	_name.position = Vector2(370, 112)
	box.add_child(_name)
	_bubble = PanelContainer.new()
	_bubble.position = Vector2(370, 150)
	_bubble.size = Vector2(770, 320)
	# ふきだしを タップしても 次へ
	_bubble.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_next())
	box.add_child(_bubble)
	_text = T.label("", TEXT_SIZE)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	_text.add_theme_font_override("font", Game.font_regular)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_text)
	_dots = T.label("", 20, Color(0.6, 0.55, 0.58))
	_dots.position = Vector2(370, 484)
	box.add_child(_dots)
	_next = T.button("つぎへ ▶", 30)
	_next.position = Vector2(860, 548)
	_next.size = Vector2(280, 76)
	T.colored_button(_next, T.YELLOW, Color(0.85, 0.6, 0.1))
	_next.pressed.connect(_on_next)
	box.add_child(_next)
	page = clampi(int(opts.get("start_page", 0)), 0, lines.size() - 1)
	_show()


## ページを 出す（出す たびに「つぎへ」へ フォーカス ＋ 押しすぎ よけ）
func _show() -> void:
	var who: Dictionary = EpisodeDB.speaker(lines[page]["who"])
	var col: Color = who["color"]
	_name.text = who["name"]
	_name.add_theme_color_override("font_color", col.darkened(0.45))
	_bubble.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 30, 6, col))
	_text.text = lines[page]["text"]
	var dots := ""
	for i in lines.size():
		dots += ("● " if i == page else "○ ")
	_dots.text = dots.strip_edges() if lines.size() > 1 else ""
	_next.text = opts.get("last_label", "つぎへ ▶") if page == lines.size() - 1 else "つぎへ ▶"
	set_focus(_next)
	lock()


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
