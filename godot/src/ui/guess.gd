extends "res://src/ui/flow_screen.gd"
## よそうの 画面：からだの地図で「どこが あやしいか」を えらぶ。
## - go の えらびを 押す まで えらびなおせる。はずれは しかられない（ヒントが 出るだけ。ほしにも 入れない）
## - go の えらびは 押せなく ならないので、行き止まりに ならない（EpisodeDB.validate() が go を 1 つ 以上 求める）
## - さいしょに えらんだ 場所（first）を finished で 返す。あたり（hit）だったかは EpisodeDB.guess_is_hit() が 見る
## - 地図の しるしは 臓器の 位置に 置く。近すぎる しるしは おしはなして、臓器の 点と 線で つなぐ（重ならない）
## - go を えらぶと、えらぶ ボタンの あった 所に「えらんだ 場所 ＋ だれの からだに 行くか」の 箱が 出る
##   （返事と つなげて ふきだしに 入れると 入りきらない）。しゅっぱつの ひとこと（enter.say）は 次の たびの 画面（journey.gd）

signal finished(first_guess: String)
signal cancelled

## ピコの ふきだしの 中の 返事：26 px、幅 540、4 行まで（テストが 本物の フォントで 全部の えらびを はかる）
const SAY_SIZE := 26
const SAY_WIDTH := 540.0
const SAY_LINES := 4
## しゅっぱつの 箱（えらぶ ボタンの あった 所）の 文：28 px、幅 640、3 行まで
const DEPART_SIZE := 28
const DEPART_WIDTH := 640.0
const DEPART_LINES := 3
const MAP_POS := Vector2(10, 36)
const MAP_SIZE := Vector2(430, 604)
const MARK := 72.0          # 地図の しるしの 直径
const MARK_GAP := 90.0      # しるしの 中心どうしの 最小の 間（大きく した しるし 1.2 倍が となりに かからない）
const BUBBLE_SIZE := Vector2(700, 212)
const DEPART_BOX := Vector2(700, 276)   # しゅっぱつの 箱が 使える 高さ（えらぶ ボタン 3 つ分）
const LIST_Y := 258.0
const MARKS := ["Ａ", "Ｂ", "Ｃ"]
const BodyMap := preload("res://src/ui/body_map.gd")
const COLORS := [T.PINK, T.MINT, T.YELLOW]

var ep: Dictionary
var first := ""                 # さいしょの よそう（place）
var buttons: Dictionary = {}    # place -> えらぶ ボタン（テストが 見る）
var marks: Dictionary = {}      # place -> 地図の しるし
var _map: BodyMap
var _lines: Control             # 臓器の 点と、しるしへの 線
var _anchors: Dictionary = {}   # place -> 臓器の 点（地図の 中の 座標）
var _centers: Dictionary = {}   # place -> しるしの 中心
var _bubble: PanelContainer
var _face_box: Control
var _say: Label
var _depart_box: PanelContainer
var _go: Button


static func say_fits(text: String) -> bool:
	return lines_of(text, SAY_SIZE, SAY_WIDTH) <= SAY_LINES


static func depart_fits(text: String) -> bool:
	return lines_of(text, DEPART_SIZE, DEPART_WIDTH) <= DEPART_LINES


## しゅっぱつの 箱の 文（だれの からだに 行くか。はいりかたと ピコの ひとことは たびの 画面で）
static func depart_line(e: Dictionary) -> String:
	return "ミクロごうに のって、%sの からだの なかへ！" % EpisodeDB.speaker(e["patient"])["name"]


func setup(e: Dictionary) -> void:
	ep = e


func _ready() -> void:
	var box := make_stage(Color(0.93, 0.95, 1.0))
	add_back_button(func(): cancelled.emit())
	add_heading("よそうしてみよう！")
	var g: Dictionary = ep["guess"]
	_build_map(box)
	# ピコの ふきだし（最初は 問い。えらぶと 返事に かわる）
	_bubble = PanelContainer.new()
	_bubble.position = Vector2(470, 36)
	_bubble.size = BUBBLE_SIZE
	_bubble.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 30, 6, EpisodeDB.PICO["color"]))
	box.add_child(_bubble)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	_bubble.add_child(hb)
	_face_box = Control.new()
	_face_box.custom_minimum_size = Vector2(90, 90)
	_face_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_face_box)
	_set_face("normal")
	# 顔と 文は ふきだしの まん中に そろえる（問いは 1 行なので、上に よせると 下が がらんと 空く）
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)
	vb.add_child(T.label(EpisodeDB.PICO["name"], 18, Color(0.3, 0.5, 0.75)))
	_say = T.body(g["q"], SAY_SIZE)
	_say.custom_minimum_size = Vector2(SAY_WIDTH, 0)
	vb.add_child(_say)
	# えらぶ ボタン（書いた 順に 上から。まぜない）と、地図の 上の しるし
	var places: Array[String] = []
	for c in g["choices"]:
		places.append(c["place"])
	_place_marks(places)
	var i := 0
	for c in g["choices"]:
		var place: String = c["place"]
		var col: Color = COLORS[i % COLORS.size()]
		var b := T.button("%s　%s" % [MARKS[i % MARKS.size()], EpisodeDB.place_label(c)], 32)
		b.position = Vector2(470, LIST_Y + i * 96)
		b.size = Vector2(700, 84)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		T.colored_button(b, col, col.darkened(0.25))
		b.pressed.connect(func(): choose(place))
		# フォーカスが 来たら、地図の その しるしを 大きく（どこの ことか 目で つながる）
		b.focus_entered.connect(func(): _highlight(place))
		b.focus_exited.connect(func(): _highlight(""))
		b.mouse_entered.connect(func(): _highlight(place))
		# たて 1 列：ひだり・みぎ では 動かない（まかせると 左上の「もどる」に とぶ。「もどる」へは いちばん 上から うえ）
		b.focus_neighbor_left = NodePath(".")
		b.focus_neighbor_right = NodePath(".")
		box.add_child(b)
		buttons[place] = b
		_add_mark(place, MARKS[i % MARKS.size()], col)
		i += 1
	# しゅっぱつの 箱（go を えらんだ あと、えらぶ ボタンの かわりに 出る）
	_depart_box = PanelContainer.new()
	_depart_box.position = Vector2(470, LIST_Y)
	_depart_box.size = Vector2(DEPART_BOX.x, 0)   # 高さは 中身に 合わせる
	_depart_box.visible = false
	box.add_child(_depart_box)
	_go = T.button("しゅっぱつ！ ▶", 34)
	_go.position = Vector2(810, 548)
	_go.size = Vector2(360, 82)
	T.colored_button(_go, T.YELLOW, T.YELLOW_DARK)
	_go.visible = false
	_go.focus_neighbor_left = NodePath(".")
	_go.focus_neighbor_right = NodePath(".")
	_go.focus_neighbor_bottom = NodePath(".")
	_go.pressed.connect(func():
		if not locked():
			Sfx.play("click")
			finished.emit(first))
	box.add_child(_go)
	set_focus(buttons[g["choices"][0]["place"]])
	lock()


## ふきだしの ピコの 顔（"normal"／"happy"）
func _set_face(mood: String) -> void:
	for c in _face_box.get_children():
		c.queue_free()
	_face_box.add_child(T.portrait("pico", mood, Vector2(90, 90), EpisodeDB.PICO["color"]))


## からだの地図（body_map.gd：絵 か、患者ごとに コードで 描く 仮の 地図）
func _build_map(box: Control) -> void:
	_map = BodyMap.new()
	_map.setup(ep["patient"], MAP_SIZE)
	_map.position = MAP_POS
	box.add_child(_map)
	_lines = Control.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_lines)
	_map.add_child(_lines)


## しるしの 中心を 決める：臓器の 点から 始めて、近すぎる もの どうしを おしはなす（くち と はな など）
func _place_marks(places: Array[String]) -> void:
	for p in places:
		_anchors[p] = _map.to_local_pos(EpisodeDB.ORGAN_POS[p])
		_centers[p] = _anchors[p]
	for n in 30:
		for a in places:
			for b in places:
				if a >= b:
					continue
				var d: Vector2 = _centers[b] - _centers[a]
				var dist := d.length()
				if dist < MARK_GAP:
					var dir := d / dist if dist > 0.01 else Vector2.RIGHT
					_centers[a] -= dir * (MARK_GAP - dist) * 0.5
					_centers[b] += dir * (MARK_GAP - dist) * 0.5
		for p in places:
			_centers[p] = _centers[p].clamp(Vector2.ONE * MARK * 0.5, MAP_SIZE - Vector2.ONE * MARK * 0.5)


## 地図の 上の 丸い しるし（タップで えらべる。ゲームパッドの 順番は 右の 縦 1 列だけに するので フォーカスは 取らない）
func _add_mark(place: String, mark: String, col: Color) -> void:
	var m := T.button(mark, 30)
	m.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed"]:
		m.add_theme_stylebox_override(st, T.rounded(col, int(MARK * 0.5), 4, col.darkened(0.25)))
	m.add_theme_stylebox_override("disabled", T.rounded(Color(0.9, 0.88, 0.89), int(MARK * 0.5), 4, Color(0.75, 0.72, 0.74)))
	m.add_theme_color_override("font_pressed_color", T.INK)
	m.size = Vector2(MARK, MARK)
	m.pivot_offset = m.size * 0.5
	m.position = _centers[place] - m.size * 0.5
	m.pressed.connect(func(): choose(place))
	_map.add_child(m)
	marks[place] = m


## 臓器の 点と、ずらした しるしへの 線
func _draw_lines() -> void:
	var dark := Color(0.35, 0.25, 0.3)
	for p in _anchors.keys():
		var a: Vector2 = _anchors[p]
		var c: Vector2 = _centers[p]
		if a.distance_to(c) > 4.0 and marks.has(p) and marks[p].visible:
			_lines.draw_line(a, c, Color.WHITE, 7)
			_lines.draw_line(a, c, dark, 3)
			_lines.draw_circle(a, 8, Color.WHITE)
			_lines.draw_circle(a, 5, dark)


## えらぶ ボタンに フォーカスが ある 場所の しるしを 大きく する（"" で 全部 もどす）
func _highlight(place: String) -> void:
	for p in marks.keys():
		var m: Button = marks[p]
		var on: bool = p == place and not m.disabled
		m.scale = Vector2.ONE * (1.2 if on else 1.0)
		m.z_index = 1 if on else 0


## はみ出しの 説明（無ければ ""）：しるしが 重ならず 地図の 中に あり、ふきだしと しゅっぱつの 箱が 入って いるか
func overflow() -> String:
	var keys := _centers.keys()
	for i in keys.size():
		var c: Vector2 = _centers[keys[i]]
		if c.x < MARK * 0.5 - 0.5 or c.y < MARK * 0.5 - 0.5 or c.x > MAP_SIZE.x - MARK * 0.5 + 0.5 or c.y > MAP_SIZE.y - MARK * 0.5 + 0.5:
			return "しるし %s が 地図の 外" % keys[i]
		for j in range(i + 1, keys.size()):
			if c.distance_to(_centers[keys[j]]) < MARK + 2.0:
				return "しるし %s と %s が 重なる" % [keys[i], keys[j]]
	var bh := _bubble.get_combined_minimum_size().y
	if bh > BUBBLE_SIZE.y:
		return "ふきだしが 高い（%.0f px。%.0f まで）" % [bh, BUBBLE_SIZE.y]
	var dh := _depart_box.get_combined_minimum_size().y
	if dh > DEPART_BOX.y:
		return "しゅっぱつの 箱が 高い（%.0f px。%.0f まで）" % [dh, DEPART_BOX.y]
	return ""


func fits() -> bool:
	return overflow() == ""


## place を えらぶ（ボタン・地図の しるし・テストが 呼ぶ）
func choose(place: String) -> void:
	if locked() or _go.visible:
		return
	var g: Dictionary = ep["guess"]
	var c: Dictionary = {}
	var idx := 0
	for i in g["choices"].size():
		if g["choices"][i]["place"] == place:
			c = g["choices"][i]
			idx = i
	if c.is_empty() or buttons[place].disabled:
		return
	if first == "":
		first = place                    # さいしょの よそう（カルテで「あたり」か 見る）
	lock()
	_say.text = T.nobreak(c["say"])      # ふきだしには 返事だけ（しゅっぱつの ひとことは 下の 箱に 出す。つなげると 入らない）
	if c.get("go", false):
		Sfx.play("quiz_ok")
		_set_face("happy")
		for k in buttons.keys():         # えらぶ ボタンを かくして、あいた 所に「しゅっぱつ」の 箱を 出す
			buttons[k].visible = false
			marks[k].visible = k == place    # 地図には えらんだ しるしだけ のこす（色も そのまま）
			marks[k].disabled = true
		var col: Color = COLORS[idx % COLORS.size()]
		var m: Button = marks[place]
		m.add_theme_stylebox_override("disabled", T.rounded(col, int(MARK * 0.5), 4, col.darkened(0.25)))
		m.add_theme_color_override("font_disabled_color", T.INK)
		m.scale = Vector2.ONE * 1.2
		m.z_index = 1
		_lines.queue_redraw()
		_show_depart(c, idx)
		_go.visible = true
		set_focus(_go)
	else:
		Sfx.play("card")                 # 「wrong」の 音は 使わない（まちがいでは ない）
		buttons[place].disabled = true
		buttons[place].focus_mode = Control.FOCUS_NONE
		marks[place].disabled = true
		marks[place].scale = Vector2.ONE
		marks[place].z_index = 0
		# もう かんがえた しるし。ボタンの 文には 足さない（「い（胃）（…）」と かっこが ならぶと 読みにくい）
		var done := T.label("かんがえたよ", 20, Color(0.42, 0.38, 0.41), HORIZONTAL_ALIGNMENT_RIGHT)   # 灰色の ボタンの 上でも 読める こさ
		done.position = Vector2(500, 26)
		done.size = Vector2(176, 32)
		done.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buttons[place].add_child(done)
		for x in g["choices"]:           # のこりの 上から 1 つめへ フォーカス
			if not buttons[x["place"]].disabled:
				set_focus(buttons[x["place"]])
				break


## しゅっぱつの 箱：えらんだ 場所（色つきの ふだ）＋ だれの からだに 行くか
func _show_depart(c: Dictionary, idx: int) -> void:
	var col: Color = COLORS[idx % COLORS.size()]
	_depart_box.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 28, 5, col.darkened(0.25)))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_depart_box.add_child(vb)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", T.rounded(col, 22, 3, col.darkened(0.25)))
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.add_child(T.label("%s　%s" % [MARKS[idx % MARKS.size()], EpisodeDB.place_label(c)], 32))
	vb.add_child(chip)
	var depart := T.body(depart_line(ep), DEPART_SIZE)
	depart.custom_minimum_size = Vector2(DEPART_WIDTH, 0)
	vb.add_child(depart)
	_depart_box.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		get_viewport().set_input_as_handled()
