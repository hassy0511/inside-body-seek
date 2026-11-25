extends "res://src/ui/flow_screen.gd"
## みつけた ものしりカード：場面を クリアした あと、その 場面で はじめて みつけた カードが あれば 出る（Game の "cards" フェーズ）。
## カードは 小さい タイル（絵と だいめい）で ならべる。主ボタン「つぎへ ▶」に フォーカスが あり、読まずに 進んで よい。
## タイルを えらぶと その カードを 大きく 開き（card.gd）、とじると この 画面の 同じ タイルに もどる。
## 読まなかった カードも ずかんに 入って いる（まだ 開いて いない しるし つき）。
## とおりみちの 場面では 出さない。みつけた カードが 無ければ 出さない。時間で 勝手に 進まない

signal finished

const CardPopup := preload("res://src/ui/card.gd")
const TILE := Vector2(184, 262)
const PIC := Vector2(132, 132)
const TITLE_SIZE := 22       # だいめいの 字（ことばの とちゅうで 折れない ように、入らなければ TITLE_MIN まで 小さく する）
const TITLE_MIN := 18
const TITLE_LINES := 3
const GAP := 12.0
const MAX_TILES := 6          # 1 列に ならぶ 数（どの 場面でも これより 多くは みつからない。テストが 見る）
const ROW_Y := 168.0
const SAY_TEXT := "えらぶと よめるよ。あとで ずかんでも よめるよ。"

var stage_id := ""
var keys: Array = []
var tiles: Array[Button] = []    # テストが 押す
var button: Button               # 主ボタン「つぎへ ▶」
var popup: Control = null        # いま 開いて いる カード（テストが 見る）
var _titles: Array[Label] = []
var _bubble: PanelContainer


func setup(sid: String, found: Array) -> void:
	stage_id = sid
	keys = found.duplicate()


func _ready() -> void:
	var box := make_stage(Color(1.0, 0.97, 0.9))
	add_heading("みつけた ものしりカード")
	# ピコの ひとこと（読むのは じぶんで えらぶ）
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 26, 4, EpisodeDB.PICO["color"]))
	_bubble.position = Vector2(190, 56)
	_bubble.size = Vector2(800, 0)
	box.add_child(_bubble)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 14)
	_bubble.add_child(bh)
	var pico := T.portrait("pico", "happy", Vector2(70, 70), EpisodeDB.PICO["color"])
	pico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bh.add_child(pico)
	var say := T.body(SAY_TEXT, 28)
	say.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	say.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bh.add_child(say)
	# タイルの ならび（まんなかに よせる）
	var n := keys.size()
	var row_w := n * TILE.x + maxf(n - 1, 0) * GAP
	var x0 := (1180.0 - row_w) * 0.5
	for i in n:
		var key: String = keys[i]
		var card := StageDB.card(stage_id, key)
		var b := Button.new()
		b.name = "Tile_%s" % key
		b.position = Vector2(x0 + i * (TILE.x + GAP), ROW_Y)
		b.size = TILE
		b.custom_minimum_size = TILE
		_style_tile(b, false)
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.position = Vector2(10, 10)
		vb.size = Vector2(TILE.x - 20, TILE.y - 20)
		vb.add_theme_constant_override("separation", 6)
		b.add_child(vb)
		var pic := CardPopup.picture(key, stage_id, PIC)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(pic)
		var tt := String(card.get("title", ""))
		var title := T.label(breakable(tt), title_size(tt), T.INK)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.custom_minimum_size = Vector2(TILE.x - 20, 0)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(title)
		_titles.append(title)
		b.pressed.connect(func(): open(i))
		box.add_child(b)
		tiles.append(b)
	# 右下：主ボタン（はじめから 押せる。読まなくても 進める）
	button = T.button("つぎへ ▶", 32)
	button.position = Vector2(810, 548)
	button.size = Vector2(370, 82)
	T.colored_button(button, T.YELLOW, T.YELLOW_DARK)
	button.pressed.connect(func():
		if not locked() and popup == null:
			lock()
			Sfx.play("click")
			finished.emit())
	box.add_child(button)
	# 矢印の 行き先：タイルの 下は 主ボタン、主ボタンの 上と ひだりは タイル。はしでは とまる
	for i in tiles.size():
		var b := tiles[i]
		b.focus_neighbor_bottom = b.get_path_to(button)
		b.focus_neighbor_top = NodePath(".")
		b.focus_neighbor_left = NodePath(".") if i == 0 else b.get_path_to(tiles[i - 1])
		b.focus_neighbor_right = b.get_path_to(button) if i == tiles.size() - 1 else b.get_path_to(tiles[i + 1])
	button.focus_neighbor_right = NodePath(".")
	button.focus_neighbor_bottom = NodePath(".")
	if tiles.is_empty():
		button.focus_neighbor_top = NodePath(".")
		button.focus_neighbor_left = NodePath(".")
	else:
		button.focus_neighbor_top = button.get_path_to(tiles[tiles.size() - 1])
		button.focus_neighbor_left = button.get_path_to(tiles[tiles.size() - 1])
	set_focus(button)
	lock()


## だいめいの 折れて よい ところ：空白の あと・「（」の 前・ひらがなと カタカナの さかい（「かぜ｜ウイルス｜だいおう」）。
## ほかの 字の あいだは 折らない（T.nobreak）。タイルは せまいので、ことばの さかいで 2〜3 行に する
static func segments(title: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for i in title.length():
		var ch := title[i]
		if cur != "" and (ch == "（" or _script(ch) * _script(cur[cur.length() - 1]) < 0):
			out.append(cur)
			cur = ""
		if ch == " " or ch == "　":
			if cur != "":
				out.append(cur + ch)
			cur = ""
			continue
		cur += ch
	if cur != "":
		out.append(cur)
	return out


## ひらがな ＝ 1、カタカナ（ー を ふくむ）＝ -1、ほか ＝ 0
static func _script(ch: String) -> int:
	var c := ch.unicode_at(0)
	if c >= 0x3041 and c <= 0x309F:
		return 1
	if c >= 0x30A0 and c <= 0x30FF:
		return -1
	return 0


## 画面に 出す 形：かたまりの 中は T.nobreak（折れない）、かたまりの あいだは 折れて よい
static func breakable(title: String) -> String:
	var out := ""
	for seg in segments(title):
		out += T.nobreak(seg)
	return out


## だいめいの 字の 大きさ：どの かたまりも 1 行に 入る 大きさ（TITLE_SIZE から TITLE_MIN まで）
static func title_size(title: String) -> int:
	var parts := segments(title)
	var size := TITLE_SIZE
	while size > TITLE_MIN:
		var ok := true
		for p in parts:
			if Game.font_bold.get_string_size(p.strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > TILE.x - 20.0:
				ok = false
		if ok:
			break
		size -= 1
	return size


func _style_tile(b: Button, opened: bool) -> void:
	var border := T.MINT.darkened(0.2) if opened else T.YELLOW_DARK
	var bg := Color(0.95, 1.0, 0.96) if opened else T.CREAM
	b.add_theme_stylebox_override("normal", T.rounded(bg, 22, 4, border))
	b.add_theme_stylebox_override("hover", T.rounded(bg.lightened(0.3), 22, 4, border))
	b.add_theme_stylebox_override("pressed", T.rounded(T.YELLOW, 22, 4, border))
	b.add_theme_stylebox_override("focus", T.rounded(Color.TRANSPARENT, 24, 6, T.FOCUS))


## i 番めの カードを 大きく 開く。とじたら その タイルに フォーカスを もどす
func open(i: int) -> void:
	if locked() or popup != null or i < 0 or i >= tiles.size():
		return
	var key: String = keys[i]
	Sfx.play("card")
	var p := CardPopup.new()
	p.setup(StageDB.card(stage_id, key), key, stage_id)
	Game.add_overlay(p)
	popup = p
	SaveData.open_card(stage_id, key)
	p.closed.connect(func():
		popup = null
		_style_tile(tiles[i], true)
		lock()
		set_focus(tiles[i]))


## はみ出し（テストが 見る）
func overflow() -> String:
	if keys.size() > MAX_TILES:
		return "カードが %d まい（%d まいまで）" % [keys.size(), MAX_TILES]
	for i in _titles.size():
		var l := _titles[i]
		if l.get_line_count() > TITLE_LINES:
			return "タイル %s の だいめいが %d 行" % [keys[i], l.get_line_count()]
		var tt := String(StageDB.card(stage_id, keys[i]).get("title", ""))
		for p in segments(tt):
			if Game.font_bold.get_string_size(p.strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size(tt)).x > TILE.x - 20.0:
				return "タイル %s の だいめいが ことばの とちゅうで 折れる（%s）" % [keys[i], p]
	if _bubble.get_combined_minimum_size().y > ROW_Y - 56.0 - 8.0:
		return "ふきだしが 高い"
	return ""


func fits() -> bool:
	return overflow() == ""
