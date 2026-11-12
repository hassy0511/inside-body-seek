extends "res://src/ui/flow_screen.gd"
## カルテえらび。左に カルテの 行、右に えらんだ カルテの 説明と 始める ボタン。
## - 最初に えらぶ 話：つづきが ある 話 → まだ クリアして いない 最初の 開いている 話 → 1 話
## - つづきが ある 話は「つづきから ▶」が 主ボタン（＋「さいしょから」）
## - クリアずみで クイズの ほしが まだの 話には「クイズに もういちど」（カルテの 紙と クイズだけ）
## - めぐる 場所と ミッションは 見せない（よそうの ねたばれに なる）
## 見た目は まだ 最小。患者の 顔・行の ほし などの 仕上げは docs/episodes.md 3.4 A。

const RIGHT_SIZE := Vector2(570, 570)

var selected_id := ""
var main_btn: Button = null       # しんさつ スタート！／つづきから ▶（テストが 見る）
var main_is_resume := false
var restart_btn: Button = null    # さいしょから（つづきが ある ときだけ）
var quiz_btn: Button = null       # クイズに もういちど（クリアずみで クイズの ほしが まだの ときだけ）
var rows: Dictionary = {}         # ep_id -> 行の ボタン
var _panel: PanelContainer
var _right: VBoxContainer


func _ready() -> void:
	var box := make_stage(Color(0.93, 0.95, 1.0))
	add_back_button(Game.show_title)
	var head := T.label("きょうの カルテ", 40, T.INK, HORIZONTAL_ALIGNMENT_CENTER)
	head.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	head.anchor_left = 0.5
	head.anchor_right = 0.5
	head.offset_left = -300
	head.offset_right = 300
	head.offset_top = 18
	add_child(head)

	# 左：カルテの 行（話が ふえても スクロールで 入る）
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 60)
	scroll.size = Vector2(550, 570)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for ep in EpisodeDB.EPISODES:
		var id: String = ep["id"]
		var open := SaveData.is_unlocked(id)
		var b := T.button("カルテ %d\n%s" % [ep["no"], ep["title"] if open else "？？？"], 24)
		b.custom_minimum_size = Vector2(520, 104)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if open:
			if SaveData.is_cleared(id):
				T.colored_button(b, T.YELLOW, Color(0.8, 0.6, 0.1))
			else:
				T.colored_button(b, T.SKY, Color(0.3, 0.55, 0.8))
			b.pressed.connect(func(): _select(id, true))
			b.focus_entered.connect(func(): _select(id, false))
		else:
			b.disabled = true
			b.focus_mode = Control.FOCUS_NONE
		list.add_child(b)
		rows[id] = b
	if not EpisodeDB.SEASON_COMPLETE:
		list.add_child(T.label("つづきの カルテは じゅんびちゅう！", 22, Color(0.5, 0.45, 0.5)))

	# 右：えらんだ カルテ（_select() が 作りなおす）
	_panel = PanelContainer.new()
	_panel.position = Vector2(590, 60)
	_panel.size = RIGHT_SIZE
	box.add_child(_panel)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 8)
	_panel.add_child(_right)
	_select(_default_id(), true)


## 右の パネルが 画面に 入って いるか（テストが 見る）
func fits() -> bool:
	return _panel.get_combined_minimum_size().y <= RIGHT_SIZE.y


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
	for c in _right.get_children():
		_right.remove_child(c)
		c.queue_free()
	var ep := EpisodeDB.get_episode(id)
	_right.add_child(T.label("カルテ %d" % ep["no"], 20, Color(0.5, 0.45, 0.5)))
	var title := T.label(ep["title"], 40 if String(ep["title"]).length() < 12 else 32)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right.add_child(title)
	_right.add_child(T.label("かんじゃさん： %s" % EpisodeDB.PATIENTS[ep["patient"]]["name"], 24, Color(0.9, 0.35, 0.5)))
	# そうだんの ひとこと（患者が 話す 最初の ページ）
	var line := EpisodeDB.select_line(ep)
	var who: Dictionary = EpisodeDB.speaker(line["who"])
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 22, 4, who["color"]))
	var say := T.label(line["text"], 22)
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	say.add_theme_font_override("font", Game.font_regular)
	bubble.add_child(say)
	_right.add_child(bubble)
	# むずかしさと ほし（1 行に ならべる）
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 24)
	var diff: String = ["", "かんたん", "ふつう", "むずかしい"][clampi(int(ep["difficulty"]), 1, 3)]
	info.add_child(T.label("むずかしさ： " + diff, 22))
	var flags := SaveData.star_flags(id)
	var stars := Control.new()
	stars.custom_minimum_size = Vector2(170, 46)
	stars.draw.connect(func():
		for i in 3:
			stars.draw_colored_polygon(T.star_points(Vector2(26 + i * 54, 23), 21), T.YELLOW if flags[i] else Color(0.85, 0.83, 0.85)))
	info.add_child(stars)
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
	sub.add_theme_constant_override("separation", 10)
	if main_is_resume:
		_right.add_child(T.label("ばめん %d まで おわっているよ" % int(r["cleared"]), 20, Color(0.5, 0.45, 0.5), HORIZONTAL_ALIGNMENT_CENTER))
		main_btn = _action("つづきから ▶", 34, func(): Game.resume_episode(), _right)
		restart_btn = _action("さいしょから", 22, func(): Game.start_episode(id), sub)
	else:
		main_btn = _action("しんさつ スタート！", 34, func(): Game.start_episode(id), _right)
	main_btn.custom_minimum_size = Vector2(340, 0)
	main_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	T.colored_button(main_btn, T.YELLOW, Color(0.85, 0.6, 0.1))
	if SaveData.is_cleared(id) and not flags[2]:
		quiz_btn = _action("クイズに もういちど", 22, func(): Game.review_karte(id), sub)
	if sub.get_child_count() > 0:
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
