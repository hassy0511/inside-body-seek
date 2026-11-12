extends "res://src/ui/flow_screen.gd"
## よそうの 画面：からだの地図で「どこが あやしいか」を えらぶ。
## - go の えらびを 押す まで えらびなおせる。はずれは しかられない（ヒントが 出るだけ。ほしにも 入れない）
## - go の えらびは 押せなく ならないので、行き止まりに ならない（EpisodeDB.validate() が go を 1 つ 以上 求める）
## - さいしょに えらんだ 場所（first）を finished で 返す。あたり（hit）だったかは EpisodeDB.guess_is_hit() が 見る
## 見た目は まだ 最小。仕上げ（見出し「よそうしてみよう！」・地図の しるしの 重なり など）は docs/episodes.md 3.4 C。

signal finished(first_guess: String)
signal cancelled

## ピコの ふきだしの 中の 返事：26 px、幅 540、4 行まで（テストが 本物の フォントで 全部の えらびを はかる）
const SAY_SIZE := 26
const SAY_WIDTH := 540.0
const SAY_LINES := 4
## しゅっぱつの 箱（えらぶ ボタンの あった 所）：28 px、幅 640、3 行まで
const DEPART_SIZE := 28
const DEPART_WIDTH := 640.0
const DEPART_LINES := 3
const MAP_SIZE := Vector2(440, 620)
const MARKS := ["Ａ", "Ｂ", "Ｃ"]

var ep: Dictionary
var first := ""                 # さいしょの よそう（place）
var buttons: Dictionary = {}    # place -> えらぶ ボタン（テストが 見る）
var _map: Control
var _say: Label
var _depart: Label
var _go: Button


static func say_fits(text: String) -> bool:
	return lines_of(text, SAY_SIZE, SAY_WIDTH) <= SAY_LINES


static func depart_fits(text: String) -> bool:
	return lines_of(text, DEPART_SIZE, DEPART_WIDTH) <= DEPART_LINES


func setup(e: Dictionary) -> void:
	ep = e


func _ready() -> void:
	var box := make_stage(Color(0.93, 0.95, 1.0))
	add_back_button(func(): cancelled.emit())
	var g: Dictionary = ep["guess"]
	var colors := [T.PINK, T.MINT, T.YELLOW]
	_build_map(box)
	# ピコの ふきだし（最初は 問い。えらぶと 返事に かわる）
	var bubble := PanelContainer.new()
	bubble.position = Vector2(480, 10)
	bubble.size = Vector2(690, 210)
	bubble.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 30, 6, EpisodeDB.PICO["color"]))
	box.add_child(bubble)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	bubble.add_child(hb)
	var face: Control = T.art_rect("pico_face_normal", Vector2(90, 90))
	if face == null:
		face = Control.new()
		face.custom_minimum_size = Vector2(90, 90)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(face)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)
	vb.add_child(T.label(EpisodeDB.PICO["name"], 18, Color(0.3, 0.5, 0.75)))
	_say = T.label(g["q"], SAY_SIZE)
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say.custom_minimum_size = Vector2(SAY_WIDTH, 0)
	_say.add_theme_font_override("font", Game.font_regular)
	vb.add_child(_say)
	# えらぶ ボタン（書いた 順に 上から。まぜない）と、地図の 上の しるし
	var i := 0
	for c in g["choices"]:
		var place: String = c["place"]
		var col: Color = colors[i % colors.size()]
		var b := T.button("%s　%s" % [MARKS[i % MARKS.size()], EpisodeDB.place_label(c)], 32)
		b.position = Vector2(480, 240 + i * 98)
		b.size = Vector2(690, 84)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		T.colored_button(b, col, col.darkened(0.25))
		b.pressed.connect(func(): choose(place))
		box.add_child(b)
		buttons[place] = b
		_add_mark(place, MARKS[i % MARKS.size()], col)
		i += 1
	# しゅっぱつの 箱（go を えらんだ あと、えらぶ ボタンの かわりに 出る）
	_depart = T.label("", DEPART_SIZE)
	_depart.position = Vector2(500, 250)
	_depart.size = Vector2(DEPART_WIDTH, 0)
	_depart.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_depart.add_theme_font_override("font", Game.font_regular)
	_depart.visible = false
	box.add_child(_depart)
	_go = T.button("しゅっぱつ！ ▶", 34)
	_go.position = Vector2(830, 552)
	_go.size = Vector2(340, 80)
	T.colored_button(_go, T.YELLOW, Color(0.85, 0.6, 0.1))
	_go.visible = false
	_go.pressed.connect(func():
		if not locked():
			Sfx.play("click")
			finished.emit(first))
	box.add_child(_go)
	set_focus(buttons[g["choices"][0]["place"]])
	lock()


## からだの地図。絵は bodymap_<患者>.png → bodymap_hana.png → 仮の SVG の 順。どれも 無ければ コードで 描く
func _build_map(box: Control) -> void:
	_map = Control.new()
	_map.position = Vector2(10, 10)
	_map.size = MAP_SIZE
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_map)
	var tex: Texture2D = T.art("bodymap_%s" % ep["patient"])
	if tex == null:
		tex = T.art("bodymap_hana")
	if tex == null and ResourceLoader.exists("res://assets/ui/body_map.svg"):
		tex = load("res://assets/ui/body_map.svg")
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map.add_child(tr)
	else:
		_map.draw.connect(_draw_body)


## 地図の 上の 丸い しるし（タップで えらべる。ゲームパッドの 順番は 右の 縦 1 列だけに するので フォーカスは 取らない）
func _add_mark(place: String, mark: String, col: Color) -> void:
	var m := T.button(mark, 30)
	m.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled"]:
		m.add_theme_stylebox_override(st, T.rounded(col, 38, 3, col.darkened(0.25)))
	m.size = Vector2(76, 76)
	m.position = EpisodeDB.ORGAN_POS[place] * MAP_SIZE - Vector2(38, 38)
	m.pressed.connect(func(): choose(place))
	_map.add_child(m)


## 絵が 無い ときの 簡単な からだの 絵
func _draw_body() -> void:
	var w := _map.size.x
	var h := _map.size.y
	var skin := Color(1.0, 0.9, 0.8)
	_map.draw_circle(Vector2(w * 0.5, h * 0.12), w * 0.17, skin)
	_map.draw_rect(Rect2(w * 0.3, h * 0.25, w * 0.4, h * 0.5), Color(0.75, 0.88, 1.0))
	_map.draw_rect(Rect2(w * 0.12, h * 0.28, w * 0.16, h * 0.4), skin)
	_map.draw_rect(Rect2(w * 0.72, h * 0.28, w * 0.16, h * 0.4), skin)
	_map.draw_rect(Rect2(w * 0.32, h * 0.75, w * 0.15, h * 0.22), Color(0.5, 0.6, 0.9))
	_map.draw_rect(Rect2(w * 0.53, h * 0.75, w * 0.15, h * 0.22), Color(0.5, 0.6, 0.9))


## place を えらぶ（ボタン・地図の しるし・テストが 呼ぶ）
func choose(place: String) -> void:
	if locked() or _go.visible:
		return
	var g: Dictionary = ep["guess"]
	var c: Dictionary = {}
	for x in g["choices"]:
		if x["place"] == place:
			c = x
	if c.is_empty() or buttons[place].disabled:
		return
	if first == "":
		first = place                    # さいしょの よそう（カルテで「あたり」か 見る）
	lock()
	_say.text = c["say"]                 # ふきだしには 返事だけ（しゅっぱつの ひとことは 下の 箱に 出す。つなげると 入らない）
	if c.get("go", false):
		Sfx.play("quiz_ok")
		for k in buttons.keys():         # えらぶ ボタンを かくして、あいた 所に「しゅっぱつ」の 箱を 出す
			buttons[k].visible = false
		_depart.text = "%s\n%s" % [EpisodeDB.place_label(c), g["depart"]]
		_depart.visible = true
		_go.visible = true
		set_focus(_go)
	else:
		Sfx.play("card")                 # 「wrong」の 音は 使わない（まちがいでは ない）
		buttons[place].disabled = true
		buttons[place].focus_mode = Control.FOCUS_NONE
		# もう かんがえた しるし。ボタンの 文には 足さない（「い（胃）（…）」と かっこが ならぶと 読みにくい）
		var done := T.label("かんがえたよ", 20, Color(0.55, 0.52, 0.54), HORIZONTAL_ALIGNMENT_RIGHT)
		done.position = Vector2(490, 26)
		done.size = Vector2(176, 32)
		done.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buttons[place].add_child(done)
		for x in g["choices"]:           # のこりの 上から 1 つめへ フォーカス
			if not buttons[x["place"]].disabled:
				set_focus(buttons[x["place"]])
				break


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		get_viewport().set_input_as_handled()
