extends "res://src/ui/flow_screen.gd"
## カルテえらび。左に カルテの 行（患者の 顔・番号・だいめい・ほし）、右に えらんだ カルテの 説明と 始める ボタン。
## - 最初に えらぶ 話：つづきが ある 話 → まだ クリアして いない 最初の 開いている 話 → 1 話
## - つづきが ある 話は「つづきから ▶」が 主ボタン（＋「さいしょから」）
## - クリアずみで クイズの ほしが まだの 話には「クイズに もういちど」（カルテの 紙と クイズだけ）
## - めぐる 場所と ミッションは 見せない（よそうの ねたばれに なる）
## 患者の 絵は T.portrait()（絵が 無い 患者は コードで 描く 仮の 顔）。

const ROW_SIZE := Vector2(540, 104)
const RIGHT_SIZE := Vector2(570, 580)
const DIFFICULTY := ["", "かんたん", "ふつう", "むずかしい"]

var selected_id := ""
var main_btn: Button = null       # しんさつ スタート！／つづきから ▶（テストが 見る）
var main_is_resume := false
var restart_btn: Button = null    # さいしょから（つづきが ある ときだけ）
var quiz_btn: Button = null       # クイズに もういちど（クリアずみで クイズの ほしが まだの ときだけ）
var rows: Dictionary = {}         # ep_id -> 行の ボタン
var _row_boxes: Dictionary = {}   # ep_id -> 行の 中身（はみ出しの 検査用）
var _panel: PanelContainer
var _right: VBoxContainer


func _ready() -> void:
	var box := make_stage(Color(0.93, 0.95, 1.0))
	add_back_button(Game.show_title)
	add_heading("きょうの カルテ")

	# 左：カルテの 行（話が ふえても スクロールで 入る）
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 54)
	scroll.size = Vector2(562, 516)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	# 行の まわりに すきま（フォーカスの わくが スクロールの ふちで 切れない ように）
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	scroll.add_child(pad)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	pad.add_child(list)
	for ep in EpisodeDB.EPISODES:
		list.add_child(_make_row(ep))
	if not EpisodeDB.SEASON_COMPLETE:
		list.add_child(T.label("つづきの カルテは じゅんびちゅう！", 22, T.GREY))
	# 左下：あつめた ほしの 数
	var total := PanelContainer.new()
	total.position = Vector2(22, 584)
	total.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 24, 3, T.YELLOW))
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	total.add_child(th)
	var one := Control.new()
	one.custom_minimum_size = Vector2(30, 30)
	one.draw.connect(func(): one.draw_colored_polygon(T.star_points(Vector2(15, 16), 15), T.YELLOW))
	th.add_child(one)
	th.add_child(T.label("あつめた ほし　%d / %d" % [SaveData.total_stars(), EpisodeDB.EPISODES.size() * 3], 22))
	box.add_child(total)

	# 右：えらんだ カルテ（_select() が 作りなおす）
	_panel = PanelContainer.new()
	_panel.position = Vector2(596, 54)
	_panel.size = RIGHT_SIZE
	box.add_child(_panel)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 8)
	_panel.add_child(_right)
	_select(_default_id(), true)


## カルテの 行：患者の 顔 ／「カルテ 1」＋ ほし ／ だいめい。まだ 開いて いない 行は「？？？」で 押せない
func _make_row(ep: Dictionary) -> Button:
	var id: String = ep["id"]
	var open := SaveData.is_unlocked(id)
	var cleared := SaveData.is_cleared(id)
	var b := Button.new()
	b.custom_minimum_size = ROW_SIZE
	rows[id] = b
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 16
	hb.offset_right = -16
	hb.offset_top = 10
	hb.offset_bottom = -10
	hb.add_theme_constant_override("separation", 14)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	_row_boxes[id] = hb
	var who: Dictionary = EpisodeDB.speaker(ep["patient"])
	if open:
		var face := T.portrait(ep["patient"], "happy" if cleared else "sick", Vector2(76, 76), who["color"])
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(face)
	else:
		var q := Control.new()
		q.custom_minimum_size = Vector2(76, 76)
		q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q.draw.connect(func(): q.draw_circle(q.size * 0.5, 34, Color(0.8, 0.78, 0.8)))
		hb.add_child(q)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)
	var ink := T.INK if open else Color(0.55, 0.52, 0.54)
	var no := T.label("カルテ %d" % ep["no"], 20, ink.lightened(0.25))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(no)
	if open:
		# ほしは 白い ふだの 上に（クリアずみの 行は 黄色なので、じかに 置くと 見えない）
		var pill := PanelContainer.new()
		var sb := T.rounded(Color.WHITE, 16, 0)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		pill.add_theme_stylebox_override("panel", sb)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(T.stars(SaveData.star_flags(id), 12.0))
		top.add_child(pill)
	# だいめい：長い ものは 小さい 字で 2 行まで
	var title_text: String = ep["title"] if open else "？？？"
	var title := T.body(title_text, 24 if title_text.length() <= 17 else 20, ink, false)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title)
	if open:
		b.pressed.connect(func(): _select(id, true))
		b.focus_entered.connect(func(): _select(id, false))
	else:
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
	return b


## 行の 色：クリアずみ ＝ 黄色、開いている ＝ 水色、まだ ＝ 灰色（テーマの disabled）。えらんだ 行は ふちを 太く こく
func _style_rows() -> void:
	for id in rows.keys():
		var b: Button = rows[id]
		if b.disabled:
			continue
		var bg := T.YELLOW if SaveData.is_cleared(id) else T.SKY
		var border := T.YELLOW_DARK if SaveData.is_cleared(id) else Color(0.3, 0.55, 0.8)
		var w := 6 if id == selected_id else 3
		if id == selected_id:
			border = border.darkened(0.25)
		b.add_theme_stylebox_override("normal", T.rounded(bg, 22, w, border))
		b.add_theme_stylebox_override("hover", T.rounded(bg.lightened(0.12), 22, w, border))
		b.add_theme_stylebox_override("pressed", T.rounded(bg.darkened(0.08), 22, w, border))


## 右の パネルと 行の 中身が はみ出して いないか（テストが 見る）
func fits() -> bool:
	if _panel.get_combined_minimum_size().y > RIGHT_SIZE.y:
		return false
	for id in _row_boxes.keys():
		var m: Vector2 = _row_boxes[id].get_combined_minimum_size()
		if m.x > ROW_SIZE.x - 32.0 or m.y > ROW_SIZE.y - 20.0:
			return false
	return true


## 最初に えらぶ 話：つづきが ある 話 → まだ クリアして いない 最初の 開いている 話 → 1 話
func _default_id() -> String:
	var r := SaveData.resume()
	if not r.is_empty() and SaveData.is_unlocked(r["ep"]):
		return r["ep"]
	for id in EpisodeDB.ids():
		if SaveData.is_unlocked(id) and not SaveData.is_cleared(id):
			return id
	return EpisodeDB.ids()[0]


## 話を えらんで 右の パネルを 作りなおす。go_to_start なら 主ボタンへ フォーカスを 移す
## （行に フォーカスが 来た だけの ときは うばわない：上下で 行を 見て まわれる）
func _select(id: String, go_to_start: bool) -> void:
	if id == selected_id and not go_to_start:
		return
	if selected_id != "":
		Sfx.play("click", 1.1)
	selected_id = id
	_style_rows()
	for c in _right.get_children():
		_right.remove_child(c)
		c.queue_free()
	var ep := EpisodeDB.get_episode(id)
	var who: Dictionary = EpisodeDB.speaker(ep["patient"])
	var col: Color = who["color"]
	var cleared := SaveData.is_cleared(id)
	var flags := SaveData.star_flags(id)
	# 上：患者の 顔 ＋ 番号・だいめい・患者の 名前
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	_right.add_child(head)
	# 右は そうだんの ひとこと（こまって いる とき）なので、顔は いつも sick。げんきに なった 顔は 左の 行に 出る
	head.add_child(T.portrait(ep["patient"], "sick", Vector2(120, 120), col))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 0)
	head.add_child(hv)
	hv.add_child(T.label("カルテ %d" % ep["no"], 20, T.GREY))
	hv.add_child(T.body(ep["title"], 36 if String(ep["title"]).length() < 12 else 28, T.INK, false))
	hv.add_child(T.label("かんじゃさん： %s" % who["name"], 22, col.darkened(0.45)))
	# そうだんの ひとこと（患者が 話す 最初の ページ）
	var line := EpisodeDB.select_line(ep)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 22, 4, EpisodeDB.speaker(line["who"])["color"]))
	bubble.add_child(T.body(line["text"], 22))
	_right.add_child(bubble)
	# むずかしさと ほし（1 行に ならべる）
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 20)
	var diff := T.label("むずかしさ： " + DIFFICULTY[clampi(int(ep["difficulty"]), 1, 3)], 22)
	diff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(diff)
	info.add_child(T.stars(flags, 20.0, 10.0))
	_right.add_child(info)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.add_child(sp)

	var r := SaveData.resume()
	main_is_resume = not r.is_empty() and r["ep"] == id
	restart_btn = null
	quiz_btn = null
	# 主ボタンの 下に、小さい ボタンを 横に ならべる（さいしょから・クイズに もういちど）
	var sub := HBoxContainer.new()
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	sub.add_theme_constant_override("separation", 12)
	if main_is_resume:
		_right.add_child(T.label("ばめん %d まで おわっているよ" % int(r["cleared"]), 20, T.GREY, HORIZONTAL_ALIGNMENT_CENTER))
		main_btn = _action("つづきから ▶", 34, func(): Game.resume_episode(), _right)
		restart_btn = _action("さいしょから", 22, func(): Game.start_episode(id), sub)
	else:
		main_btn = _action("しんさつ スタート！", 34, func(): Game.start_episode(id), _right)
	main_btn.custom_minimum_size = Vector2(360, 78)
	main_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	T.colored_button(main_btn, T.YELLOW, T.YELLOW_DARK)
	if cleared and not flags[2]:
		quiz_btn = _action("クイズに もういちど", 22, func(): Game.review_karte(id), sub)
	if sub.get_child_count() > 0:
		for c in sub.get_children():
			c.custom_minimum_size = Vector2(0, 60)
		_right.add_child(sub)
	else:
		sub.free()   # 使わなかった 入れ物を のこさない
	# ゲームパッド：行 → みぎ で 主ボタン、主ボタン → ひだり で えらんだ 行
	main_btn.focus_neighbor_left = main_btn.get_path_to(rows[id])
	for k in rows.keys():
		rows[k].focus_neighbor_right = rows[k].get_path_to(main_btn)
	focus_target = main_btn
	if go_to_start:
		main_btn.grab_focus()
		lock()


## 右の パネルの ボタン（押しすぎ よけ つき）
func _action(text: String, font_size: int, cb: Callable, parent: Control) -> Button:
	var b := T.button(text, font_size)
	b.pressed.connect(func():
		if not locked():
			Sfx.play("click")
			cb.call())
	parent.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Sfx.play("click")
		Game.show_title()
		get_viewport().set_input_as_handled()
