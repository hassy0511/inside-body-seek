extends "res://src/ui/flow_screen.gd"
## カルテの 画面：かいけつ → カルテの 紙 → クイズ → ほし。段ごとに 中身を 作りなおし、主ボタンへ フォーカスを 入れる。
## からだから 出る ところ（出口の ひとこと）は、この 前の たびの 画面（journey.gd）で 見せる。
## setup() の opts：
##   "guess_hit"  さいしょの よそうが あたり だった（かいけつの 段に ひとこと 出す）
##   "review"     クリアずみの カルテの 読みかえし（紙から 始まり、「つぎの カルテへ」は 出さない。「もどる」で カルテえらびへ）
## クリアの 記録は Game が する（この 画面に 入った とき）。クイズの 結果は answered で Game に わたす。
## ほしは 回を またいで たまる：ここでは SaveData.star_flags() を 読んで 出すだけ。

signal answered(correct: bool)
signal finished(go_next: bool)

const Sheet := preload("res://src/ui/karte_sheet.gd")
const PANEL_SIZE := Vector2(940, 640)
const MARKS := ["Ａ", "Ｂ", "Ｃ"]
const GREY := Color(0.47, 0.42, 0.45)   # まだの ほしの 行。「ばめん 2 が まだ」を 読める こさに
const GREEN := Color(0.3, 0.62, 0.42)
const PICO_BLUE := Color(0.3, 0.5, 0.75)

var ep: Dictionary
var opts: Dictionary = {}
var step := 0                # 0 かいけつ ／ 1 カルテの 紙 ／ 2 クイズ ／ 3 ほし
var panel: PanelContainer
var quiz_buttons: Array[Button] = []   # クイズの えらび（出した 順。テストが 見る）
var quiz_answer := -1                  # quiz_buttons の 中の 正解の 番号
var back_btn: Button = null            # 読みかえしの「もどる」（ふつうの カルテ画面には 無い）
var _vb: VBoxContainer
var _correct := false


func setup(e: Dictionary, o := {}) -> void:
	ep = e
	opts = o


func _ready() -> void:
	var box := make_stage(Color(1.0, 0.92, 0.8), PANEL_SIZE)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", T.rounded(T.CREAM, 30, 6, T.YELLOW))
	box.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	_vb = VBoxContainer.new()
	_vb.add_theme_constant_override("separation", 8)
	margin.add_child(_vb)
	step = 1 if opts.get("review", false) else 0   # 読みかえしは 紙から
	# 読みかえしは カルテえらびから 来るので、いつでも もどれる（まちがえて 押した 子が クイズを やらされない）。
	# ふつうの カルテ画面には「もどる」が 無い（もどる 先が 無い。クリアは もう 記録して ある）
	if opts.get("review", false):
		back_btn = add_back_button(func(): finished.emit(false))
		back_btn.position = Vector2(12, 16)                 # 紙（左の ふちは x＝170）に かからない 所
		back_btn.custom_minimum_size = Vector2(140, 60)
	_show()


## 中身が パネルに 入って いるか、「もどる」が 紙に かかって いないか（テストが 段ごとに 見る）
func fits() -> bool:
	if back_btn != null and back_btn.get_global_rect().grow(4.0).intersects(panel.get_global_rect()):
		return false
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


func _spacer() -> void:
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vb.add_child(sp)


## 人の 顔 ＋ 名前 ＋ ふきだし の 1 行（かいけつの 段）
func _speech(who_id: String, mood: String, face: float, text: String, font_size: int) -> void:
	var who: Dictionary = EpisodeDB.speaker(who_id)
	var col: Color = who["color"]
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	var f := T.portrait(who_id, mood, Vector2(face, face), col)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(f)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	vb.add_child(T.label(who["name"], 20, col.darkened(0.45)))
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 22, 4, col))
	bubble.add_child(T.body(text, font_size))
	vb.add_child(bubble)
	hb.add_child(vb)
	_vb.add_child(hb)


## 押しすぎ よけ つきの ボタン
func _button(text: String, font_size: int, cb: Callable) -> Button:
	var b := T.button(text, font_size)
	b.custom_minimum_size = Vector2(0, 76)
	b.pressed.connect(func():
		if not locked():
			Sfx.play("click")
			cb.call())
	return b


## 段の 主ボタン（右下。黄色）。ここへ フォーカスを 入れる
func _main_button(text: String, cb: Callable, parent: Control = null) -> void:
	var b := _button(text, 30, cb)
	b.custom_minimum_size = Vector2(340, 76)
	T.colored_button(b, T.YELLOW, T.YELLOW_DARK)
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
	var head := T.label("かいけつ！", 48, Color(0.9, 0.35, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	_vb.add_child(head)
	_vb.add_child(T.label(_title(), 26, T.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var k: Dictionary = ep["karte"]
	_spacer()
	if k.has("thanks"):
		_speech(ep["patient"], "happy", 200.0, k["thanks"], 32)
	if opts.get("guess_hit", false):
		_vb.add_child(T.label("★ きみの さいしょの よそう、あたっていたね！", 24, Color(0.75, 0.5, 0.1), HORIZONTAL_ALIGNMENT_CENTER))
	_spacer()
	_main_button("カルテを かく ▶", func(): _go(1))


# ---------------------------------------------------------------- 段 1：カルテの 紙
func _show_sheet() -> void:
	SaveData.mark_card(ep["id"], "karte")   # ずかんで 読みかえせる ように なる
	# 紙の あたま：だいめい ＋ 患者の 名前と 顔
	var who: Dictionary = EpisodeDB.speaker(ep["patient"])
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var title := T.label(_title(), 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(T.label(who["name"], 20, (who["color"] as Color).darkened(0.45)))
	top.add_child(T.portrait(ep["patient"], "happy", Vector2(52, 52), who["color"]))
	_vb.add_child(top)
	var rule := ColorRect.new()
	rule.color = T.YELLOW
	rule.custom_minimum_size = Vector2(0, 3)
	_vb.add_child(rule)
	_vb.add_child(Sheet.build(ep))
	_spacer()
	_main_button("クイズに ちょうせん！", func(): _go(2))


# ---------------------------------------------------------------- 段 2：クイズ
func _show_quiz() -> void:
	var q: Dictionary = ep["quiz"]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.add_child(T.portrait("pico", "normal", Vector2(90, 90), EpisodeDB.PICO["color"]))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	tv.add_child(T.label("クイズ", 20, PICO_BLUE))
	tv.add_child(T.body(q["q"], 34, T.INK, false))
	top.add_child(tv)
	_vb.add_child(top)
	_spacer()
	var order := [0, 1, 2]
	order.shuffle()   # えらびは 出す たびに まぜる
	quiz_buttons.clear()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	_vb.add_child(list)
	for n in order.size():
		var i: int = order[n]
		var b := T.button("%s　%s" % [MARKS[n], q["choices"][i]], 30)
		b.custom_minimum_size = Vector2(0, 88)
		b.pressed.connect(func():
			if not locked():
				_answer(i == int(q["answer"])))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		T.colored_button(b, T.SKY, Color(0.3, 0.55, 0.8))
		list.add_child(b)
		quiz_buttons.append(b)
		if i == int(q["answer"]):
			quiz_answer = n
	_spacer()
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
	# クイズの 答えの わけ（ピコの ひとこと）
	var ex := HBoxContainer.new()
	ex.add_theme_constant_override("separation", 14)
	var face := T.portrait("pico", "happy" if _correct else "normal", Vector2(76, 76), EpisodeDB.PICO["color"])
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ex.add_child(face)
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 22, 4, EpisodeDB.PICO["color"]))
	bubble.add_child(T.body(ep["quiz"].get("explain", ""), 24))
	ex.add_child(bubble)
	_vb.add_child(ex)
	_spacer()
	# ほし 3 つ ＋ ほしの わけ（横に ならべる）
	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 36)
	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_theme_constant_override("separation", 4)
	var stars := T.stars(flags, 38.0, 14.0)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sv.add_child(stars)
	sv.add_child(T.label("ほし %d こ！" % flags.count(true), 30, T.INK, HORIZONTAL_ALIGNMENT_CENTER))
	mid.add_child(sv)
	# まだの ほしは「どうすれば とれるか」を そえる（ハートは 場面ごと・回を またいで たまる）
	# ハートの ほしは とおりみちを 数えない。まだの 場面は 場所の 名前で 書く（場面の 番号は とおりみちが 入ると わかりにくい）
	var miss: Array[String] = []
	var sf := SaveData.scene_flags(id)
	var hs := SaveData.heart_scenes(id)
	for i in sf.size():
		if not sf[i]:
			miss.append(EpisodeDB.place_name(ep["scenes"][hs[i]]["place"]))
	var heart_todo := "（また こんど！）" if sf.size() <= 1 else ""
	var rows := VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 6)
	rows.add_child(_star_row(flags[0], "カルテ かんせい！", ""))
	rows.add_child(_star_row(flags[1], "ハートを へらさずに", heart_todo))
	if not flags[1] and sf.size() > 1 and not miss.is_empty():
		var todo := T.label("　　まだ： %s" % "・".join(PackedStringArray(miss)), 20, GREY)
		todo.add_theme_font_override("font", Game.font_regular)
		rows.add_child(todo)
	rows.add_child(_star_row(flags[2], "クイズに せいかい", "（また こんど！）"))
	mid.add_child(rows)
	_vb.add_child(mid)
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
	# ほしが ぽよんと 出る
	stars.pivot_offset = stars.custom_minimum_size * 0.5
	stars.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(stars, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if opts.get("review", false) and not locked():
			Sfx.play("click")
			finished.emit(false)
		get_viewport().set_input_as_handled()


func _star_row(got: bool, text: String, todo: String) -> Label:
	return T.label(("● " + text) if got else ("○ " + text + todo), 24, GREEN if got else GREY)
