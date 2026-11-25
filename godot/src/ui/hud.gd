extends Control
## ゲーム中の表示：ハート・ミッション・メッセージ（ドクター・ピコ）・ポケット。

const T := preload("res://src/ui/ui_theme.gd")
const CardPopup := preload("res://src/ui/card.gd")
## ものしりカードを みつけた ときの 小さい しらせ（チップ）。ひだりうえ、ハートと ポケットの 下（CHIP_POS）。
## はじめての そうじゅうの てびきが 出て いる ときは その みぎ（CHIP_POS_GUIDE）。ピコの ふきだしは 4 行で y 413 まで
## のびるので、ひだりの まんなかには 置かない。幅は CHIP_MAX_W まで（ミッションの わく（x 760〜）に とどかない）、
## てびきの みぎでは CHIP_MAX_W_GUIDE まで。ながい だいめいは その 幅に 入らない ときだけ 字を 小さく する。
## ゲームは 止めない。本文は 出さない（読むのは クリアの あとの「みつけた ものしりカード」と ずかん）
const CHIP_POS := Vector2(24, 132)
const CHIP_POS_GUIDE := Vector2(304, 132)
const CHIP_MAX_W := 640.0
const CHIP_MAX_W_GUIDE := 440.0
const CHIP_TITLE_SIZE := 26
const CHIP_PIC := 64.0
const CHIP_SECONDS := 2.5
## 上の 題（だれの からだの どこか）：26 px、幅 TITLE_WIDTH まで（テストが 全部の 話と 場所で はかる）
const TITLE_SIZE := 26
const TITLE_WIDTH := 650.0
const TITLE_FACE := 40.0

var level: Node = null
var _hearts := 3
var _heart_box: Control
var _mission_box: VBoxContainer
var _mission_labels: Array[Label] = []
var _msg_panel: PanelContainer
var _msg_label: Label
var _msg_timer := 0.0
var _msg_hold := 0.0     # 物語の ひとことが 出てから、ほかの 文に 上書きさせない 残り時間
var _pocket: Label
var _stage_label: Label
var _title_face: Control
var _pause_btn: Button
var _top: PanelContainer
var _mission_panel: PanelContainer
var _chip: PanelContainer = null
var _chip_timer := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE

	_heart_box = Control.new()
	_heart_box.position = Vector2(24, 20)
	_heart_box.custom_minimum_size = Vector2(200, 60)
	_heart_box.size = Vector2(200, 60)
	_heart_box.draw.connect(_draw_hearts)
	_heart_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heart_box)

	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -350
	top.offset_right = 350
	top.offset_top = 14
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", T.rounded(Color(1, 1, 1, 0.8), 20, 0))
	var th := HBoxContainer.new()
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_theme_constant_override("separation", 10)
	th.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(th)
	_title_face = Control.new()   # 患者の 顔（カルテの 場面だけ）
	_title_face.custom_minimum_size = Vector2(TITLE_FACE, TITLE_FACE)
	_title_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_face.visible = false
	th.add_child(_title_face)
	_stage_label = T.label("", TITLE_SIZE, T.INK, HORIZONTAL_ALIGNMENT_CENTER)
	th.add_child(_stage_label)
	add_child(top)
	_top = top

	var mp := PanelContainer.new()
	mp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mp.anchor_left = 1.0
	mp.anchor_right = 1.0
	mp.offset_left = -520
	mp.offset_right = -24
	mp.offset_top = 110
	mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp.add_theme_stylebox_override("panel", T.rounded(Color(1, 1, 1, 0.82), 20, 0))
	_mission_box = VBoxContainer.new()
	_mission_box.add_theme_constant_override("separation", 6)
	mp.add_child(_mission_box)
	add_child(mp)
	_mission_panel = mp

	_pause_btn = T.button("", 30)
	_pause_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pause_btn.anchor_left = 1.0
	_pause_btn.anchor_right = 1.0
	_pause_btn.offset_left = -120
	_pause_btn.offset_right = -20
	_pause_btn.offset_top = 14
	_pause_btn.offset_bottom = 98
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.pressed.connect(func(): Game.toggle_pause())
	add_child(_pause_btn)
	# 一時停止の しるし（たての 棒 2 本）は、字で なく 形で 描く。
	# ブラウザ版には パソコンの フォントの 代わりが 無いので、記号の 字は 四角に 化ける
	for x in [-14.0, 5.0]:
		var bar := ColorRect.new()
		bar.color = T.INK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		bar.offset_left = x
		bar.offset_right = x + 9.0
		bar.offset_top = -16.0
		bar.offset_bottom = 16.0
		_pause_btn.add_child(bar)

	_pocket = T.label("", 24, T.INK)
	_pocket.position = Vector2(24, 86)
	add_child(_pocket)

	_msg_panel = PanelContainer.new()
	_msg_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_msg_panel.anchor_left = 0.5
	_msg_panel.anchor_right = 0.5
	_msg_panel.anchor_top = 1.0
	_msg_panel.anchor_bottom = 1.0
	_msg_panel.offset_left = -430
	_msg_panel.offset_right = 430
	_msg_panel.offset_top = -200
	_msg_panel.offset_bottom = -26
	_msg_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_panel.add_theme_stylebox_override("panel", T.rounded(Color(1, 1, 1, 0.92), 26, 4, T.SKY))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	# 納品された顔（ui/pico_face_normal.png）があれば それ、なければ コードで描く仮の顔
	hb.add_child(T.portrait("pico", "normal", Vector2(90, 90), EpisodeDB.PICO["color"]))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(T.label("ドクター・ピコ", 18, Color(0.3, 0.5, 0.7)))
	_msg_label = T.label("", 30)
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_msg_label)
	hb.add_child(vb)
	_msg_panel.add_child(hb)
	_msg_panel.visible = false
	add_child(_msg_panel)


func bind_level(l: Node) -> void:
	level = l
	_stage_label.text = title_text(l.stage)
	var ep := EpisodeDB.get_episode(l.stage["ep"]) if l.stage.has("ep") else {}
	if not ep.is_empty():
		var who: Dictionary = EpisodeDB.speaker(ep["patient"])
		_title_face.add_child(T.portrait(ep["patient"], "sick", Vector2(TITLE_FACE, TITLE_FACE), who["color"]))
		_title_face.visible = true
	l.missions_changed.connect(_refresh_missions)
	l.hearts_changed.connect(func(h): _hearts = h; _heart_box.queue_redraw())
	_refresh_missions()


## 上の 題：カルテの 場面は「おとうさんの しょくどう（食道）」（だれの からだか。2 話の しょくどうを
## 1 話の はなちゃんの 中と 思わない ように）。場所モード（テスト）は 場所の 名前だけ
static func title_text(stage: Dictionary) -> String:
	var place := "%s（%s）" % [stage["name"], stage["kanji"]]
	if not stage.has("ep"):
		return place
	var ep := EpisodeDB.get_episode(stage["ep"])
	if ep.is_empty():
		return place
	return "%sの %s" % [EpisodeDB.speaker(ep["patient"])["name"], place]


## 題が 1 行で 入るか（本物の フォントで はかる）
static func title_fits(text: String) -> bool:
	var f: Font = Game.font_bold
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x <= TITLE_WIDTH - TITLE_FACE - 10.0


func title_label() -> Label:
	return _stage_label


func _refresh_missions() -> void:
	for c in _mission_box.get_children():
		c.queue_free()
	_mission_labels.clear()
	if level == null:
		return
	for m in level.missions:
		var l := T.body(("● " if m.done else "○ ") + m.label(), 24, Color(0.45, 0.7, 0.5) if m.done else T.INK, false)
		_mission_box.add_child(l)
		_mission_labels.append(l)


func _process(delta: float) -> void:
	_msg_hold = maxf(_msg_hold - delta, 0.0)
	if _chip != null and is_instance_valid(_chip):
		_chip_timer -= delta
		if _chip_timer <= 0.0:
			_chip.queue_free()
			_chip = null
		elif _chip_timer < 0.3:
			_chip.modulate.a = _chip_timer / 0.3
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			_msg_panel.visible = false
	if level and level.player:
		var n := 0
		for it in level.player.inventory:
			if it == "nutrient":
				n += 1
		_pocket.text = ("ポケット：えいよう × %d" % n) if n > 0 else ""


func is_busy() -> bool:
	return _msg_panel.visible and _msg_timer > 0.0


## ピコの ひとことを 出す。出せたら true。
## hold > 0 は 物語の ひとこと：出てから hold 秒は、hold なしの 文（とっさの ひとこと・ヒント）に 上書きさせない。
func say(text: String, seconds := 4.0, hold := 0.0) -> bool:
	if hold <= 0.0 and _msg_hold > 0.0 and is_busy():
		return false
	_msg_hold = hold
	_msg_label.text = T.nobreak(text)   # ことばの 途中で 折らない
	_msg_panel.visible = true
	# タッチ操作のボタンと重ならないように、タッチのときは少し細くする
	var touch_on: bool = Game.touch_controls != null and is_instance_valid(Game.touch_controls) and Game.touch_controls.visible
	_msg_panel.offset_left = -360 if touch_on else -430
	_msg_panel.offset_right = 360 if touch_on else 430
	_msg_timer = seconds
	_msg_panel.scale = Vector2(0.9, 0.9)
	_msg_panel.pivot_offset = _msg_panel.size * 0.5
	var t := create_tween()
	t.tween_property(_msg_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true


## ものしりカードを みつけた しらせ：カードの 絵と だいめいだけ、CHIP_SECONDS 秒。つぎが 来たら 入れかえる
func show_card_chip(card: Dictionary, key: String, stage_id: String) -> void:
	if _chip != null and is_instance_valid(_chip):
		_chip.queue_free()
	var chip := PanelContainer.new()
	chip.name = "CardChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := get_node_or_null("SteerGuide")
	var by_guide: bool = g != null and g.visible and not g.is_queued_for_deletion()
	chip.position = CHIP_POS_GUIDE if by_guide else CHIP_POS
	var max_w := CHIP_MAX_W_GUIDE if by_guide else CHIP_MAX_W
	chip.add_theme_stylebox_override("panel", T.rounded(Color(T.CREAM, 0.94), 18, 4, T.YELLOW))
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 10)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 6)
	chip.add_child(m)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 10)
	m.add_child(hb)
	hb.add_child(CardPopup.picture(key, stage_id, Vector2(CHIP_PIC, CHIP_PIC)))
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	vb.add_child(T.label("ものしりカード　みつけた！", 18, Color(0.75, 0.5, 0.2)))
	var title := T.label(String(card.get("title", "")), CHIP_TITLE_SIZE, T.INK)
	title.name = "Title"
	vb.add_child(title)
	hb.add_child(vb)
	add_child(chip)
	# ながい だいめいは 字を 小さく して 幅に 入れる（本物の フォントで はかる）
	var size := CHIP_TITLE_SIZE
	while size > 18 and chip.get_combined_minimum_size().x > max_w:
		size -= 2
		title.add_theme_font_size_override("font_size", size)
	chip.reset_size()
	_chip = chip
	_chip_timer = CHIP_SECONDS
	chip.modulate.a = 0.0
	var t := chip.create_tween()
	t.tween_property(chip, "modulate:a", 1.0, 0.15)


## いま 出て いる しらせ（無ければ null。テストが 重なりを 見る）
func card_chip() -> Control:
	return _chip if _chip != null and is_instance_valid(_chip) and not _chip.is_queued_for_deletion() else null


## しらせが 重なっては いけない HUD の 部品の 画面の 上の 四角（見えている ものだけ）。テストが 使う
func hud_rects() -> Dictionary:
	var out := {"hearts": _heart_box.get_global_rect(), "title": _top.get_global_rect(), "pause": _pause_btn.get_global_rect()}
	if _mission_box.get_child_count() > 0:
		out["missions"] = _mission_panel.get_global_rect()
	if _pocket.text != "":
		out["pocket"] = _pocket.get_global_rect()
	if _msg_panel.visible:
		out["pico"] = _msg_panel.get_global_rect()
	var g := get_node_or_null("SteerGuide")
	if g != null and g.visible:
		out["guide"] = (g as Control).get_global_rect()
	var tc: Control = Game.touch_controls
	if tc != null and is_instance_valid(tc) and tc.visible:
		out.merge(tc.button_rects())
	return out


func _draw_hearts() -> void:
	for i in 3:
		var c := Vector2(30 + i * 56, 32)
		var col := Color(1.0, 0.35, 0.45) if i < _hearts else Color(0.85, 0.8, 0.82, 0.7)
		T.draw_heart(_heart_box, c + Vector2(2, 3), 22, Color(0, 0, 0, 0.12))
		T.draw_heart(_heart_box, c, 22, col)
