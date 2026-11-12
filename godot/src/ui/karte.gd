extends "res://src/ui/flow_screen.gd"
## カルテの 画面：かいけつ → カルテの 紙 → クイズ → ほし。段ごとに 中身を 作りなおし、主ボタンへ フォーカスを 入れる。
## setup() の opts：
##   "guess_hit"  さいしょの よそうが あたり だった（かいけつの 段に ひとこと 出す）
##   "review"     クリアずみの カルテの 読みかえし（紙から 始まり、「つぎの カルテへ」は 出さない）
## クリアの 記録は Game が する（この 画面に 入った とき）。クイズの 結果は answered で Game に わたす。
## ほしは 回を またいで たまる：ここでは SaveData.star_flags() を 読んで 出すだけ。
## 見た目は まだ 最小。患者の 顔・挿絵 などの 仕上げは docs/episodes.md 3.4 D。

signal answered(correct: bool)
signal finished(go_next: bool)

const Sheet := preload("res://src/ui/karte_sheet.gd")
const PANEL_SIZE := Vector2(940, 640)
const MARKS := ["Ａ", "Ｂ", "Ｃ"]
const GREY := Color(0.6, 0.55, 0.58)
const GREEN := Color(0.45, 0.7, 0.5)

var ep: Dictionary
var opts: Dictionary = {}
var step := 0                # 0 かいけつ ／ 1 カルテの 紙 ／ 2 クイズ ／ 3 ほし
var panel: PanelContainer
var quiz_buttons: Array[Button] = []   # クイズの えらび（出した 順。テストが 見る）
var quiz_answer := -1                  # quiz_buttons の 中の 正解の 番号
var _vb: VBoxContainer
var _correct := false


func setup(e: Dictionary, o := {}) -> void:
	ep = e
	opts = o


func _ready() -> void:
	var box := make_stage(Color(1.0, 0.92, 0.8), PANEL_SIZE)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	_vb = VBoxContainer.new()
	_vb.add_theme_constant_override("separation", 10)
	margin.add_child(_vb)
	step = 1 if opts.get("review", false) else 0   # 読みかえしは 紙から
	_show()


## 中身が パネルに 入って いるか（テストが 段ごとに 見る）
func fits() -> bool:
	return panel.get_combined_minimum_size().y <= PANEL_SIZE.y


func _show() -> void:
	for c in _vb.get_children():
		_vb.remove_child(c)
		c.queue_free()
	match step:
		0: _show_solved()
		1: _show_sheet()
		2: _show_quiz()
		3: _show_stars()


func _go(next_step: int) -> void:
	step = next_step
	_show()


func _title() -> String:
	return "カルテ %d　%s" % [ep["no"], ep["title"]]


func _body(text: String, font_size: int) -> Label:
	var l := T.label(text, font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Game.font_regular)
	return l


func _spacer() -> void:
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vb.add_child(sp)


## 押しすぎ よけ つきの ボタン
func _button(text: String, font_size: int, cb: Callable) -> Button:
	var b := T.button(text, font_size)
	b.pressed.connect(func():
		if not locked():
			Sfx.play("click")
			cb.call())
	return b


## 段の 主ボタン（右下。黄色）。ここへ フォーカスを 入れる
func _main_button(text: String, cb: Callable, parent: Control = null) -> void:
	var b := _button(text, 30, cb)
	b.custom_minimum_size = Vector2(320, 0)
	T.colored_button(b, T.YELLOW, Color(0.85, 0.6, 0.1))
	if parent == null:
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		_vb.add_child(b)
	else:
		parent.add_child(b)
	set_focus(b)
	lock()


# ---------------------------------------------------------------- 段 0：かいけつ
func _show_solved() -> void:
	Sfx.play("clear")
	_vb.add_child(T.label("かいけつ！", 48, Color(0.9, 0.35, 0.5), HORIZONTAL_ALIGNMENT_CENTER))
	_vb.add_child(T.label(_title(), 26, T.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var k: Dictionary = ep["karte"]
	if k.has("thanks"):
		var who: Dictionary = EpisodeDB.speaker(ep["patient"])
		_vb.add_child(T.label(who["name"], 22, (who["color"] as Color).darkened(0.45)))
		_vb.add_child(_body(k["thanks"], 28))
	if k.has("exit"):
		_vb.add_child(T.label(EpisodeDB.PICO["name"], 22, Color(0.3, 0.5, 0.75)))
		_vb.add_child(_body(k["exit"], 24))
	if opts.get("guess_hit", false):
		_vb.add_child(T.label("★ きみの さいしょの よそう、あたっていたね！", 24, Color(0.75, 0.55, 0.2), HORIZONTAL_ALIGNMENT_CENTER))
	_spacer()
	_main_button("カルテを かく ▶", func(): _go(1))


# ---------------------------------------------------------------- 段 1：カルテの 紙
func _show_sheet() -> void:
	SaveData.mark_card(ep["id"], "karte")   # ずかんで 読みかえせる ように なる
	_vb.add_child(T.label(_title(), 26))
	_vb.add_child(Sheet.build(ep))
	_spacer()
	_main_button("クイズに ちょうせん！", func(): _go(2))


# ---------------------------------------------------------------- 段 2：クイズ
func _show_quiz() -> void:
	var q: Dictionary = ep["quiz"]
	_vb.add_child(T.label("クイズ", 18, Color(0.3, 0.5, 0.75)))
	var ql := T.label(q["q"], 34)
	ql.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vb.add_child(ql)
	var order := [0, 1, 2]
	order.shuffle()   # えらびは 出す たびに まぜる
	quiz_buttons.clear()
	for n in order.size():
		var i: int = order[n]
		var b := T.button("%s　%s" % [MARKS[n], q["choices"][i]], 28)
		b.pressed.connect(func():
			if not locked():
				_answer(i == int(q["answer"])))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		T.colored_button(b, T.SKY, Color(0.3, 0.55, 0.8))
		_vb.add_child(b)
		quiz_buttons.append(b)
		if i == int(q["answer"]):
			quiz_answer = n
	set_focus(quiz_buttons[0])
	lock()


func _answer(correct: bool) -> void:
	_correct = correct
	Sfx.play("quiz_ok" if correct else "wrong")
	answered.emit(correct)   # Game が 記録する（1 回 とった ほしは 消えない）
	_go(3)


# ---------------------------------------------------------------- 段 3：ほし
func _show_stars() -> void:
	var id: String = ep["id"]
	var flags := SaveData.star_flags(id)
	_vb.add_child(T.label("せいかい！" if _correct else "おしい！", 44, Color(0.9, 0.35, 0.5) if _correct else Color(0.4, 0.5, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	_vb.add_child(_body(ep["quiz"].get("explain", ""), 24))
	var stars := Control.new()
	stars.custom_minimum_size = Vector2(0, 84)
	stars.draw.connect(func():
		var cx := stars.size.x * 0.5
		for i in 3:
			stars.draw_colored_polygon(T.star_points(Vector2(cx + (i - 1) * 100, 42), 36), T.YELLOW if flags[i] else Color(0.88, 0.86, 0.87)))
	_vb.add_child(stars)
	# ほしの わけ。まだの ほしは「どうすれば とれるか」を そえる（ハートは 場面ごと・回を またいで たまる）
	var miss: Array[String] = []
	var sf := SaveData.scene_flags(id)
	for i in sf.size():
		if not sf[i]:
			miss.append(str(i + 1))
	var heart_todo := "（また こんど！）" if sf.size() <= 1 else "（ばめん %s が まだ）" % "・".join(PackedStringArray(miss))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	rows.add_child(_star_row(flags[0], "カルテ かんせい！", ""))
	rows.add_child(_star_row(flags[1], "ハートを へらさずに", heart_todo))
	rows.add_child(_star_row(flags[2], "クイズに せいかい", "（また こんど！）"))
	_vb.add_child(rows)
	_vb.add_child(T.label("ほし %d こ！" % flags.count(true), 28, T.INK, HORIZONTAL_ALIGNMENT_CENTER))
	_spacer()
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 20)
	_vb.add_child(hb)
	var review: bool = opts.get("review", false)
	var has_next: bool = EpisodeDB.next_id(id) != ""
	var to_select := func(): finished.emit(false)
	if not review and (has_next or EpisodeDB.SEASON_COMPLETE):
		hb.add_child(_button("カルテえらびへ", 26, to_select))
		_main_button("つぎの カルテへ ▶" if has_next else "エンディングへ ▶", func(): finished.emit(true), hb)
	else:
		_main_button("カルテえらびへ", to_select, hb)


func _star_row(got: bool, text: String, todo: String) -> Label:
	return T.label(("● " + text) if got else ("○ " + text + todo), 22, GREEN if got else GREY)
