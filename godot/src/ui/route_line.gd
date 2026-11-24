extends Control
## とおる 場所の ならび（電車の 路線図の ように 左から 右へ）。みちの ちず（hop.gd）・出口の たびの 画面（journey.gd）が 使う。
## カルテの 紙の「とおった みち」は 1 行の inline()（文字 ＋ やじるしの 形）。
## やじるしや しるしは 形で えがく（ブラウザ版の フォントに 無い 字は 四角に 化ける）。
## - current ＝ いま いる 場所（-1 なら なし）、next ＝ つぎの 場所（-1 なら なし）。current より 前と、current と next の あいだは「とおった」（とばす ときに いっきに とおる 所）
## - done ＝ ぜんぶ とおった（出口の 画面）

const T := preload("res://src/ui/ui_theme.gd")
const TAG_H := 34.0           # 上の ふだ（いま ここ／つぎは ここ）の 高さ
const LINE_Y := TAG_H + 24.0  # 線の 高さ（上から）
const PASSED := Color(1.0, 0.8, 0.25)
const NOW := Color(1.0, 0.86, 0.35)
const NEXT := Color(0.3, 0.62, 0.9)
const EDGE := Color(0.35, 0.25, 0.3)
const FUTURE := Color(0.85, 0.85, 0.9)

var places: Array[String] = []
var current := -1
var next := -1
var done := false
var tags := true
## 大きさ（ふだ なしの ときは 小さめ：出口の 画面の すきまに 入れる）
var DOT := 15.0
var NAME_SIZE := 20
var KANJI_SIZE := 18
var _t := 0.0
var names: Array[Label] = []     # 場所の 名前（テストが 見る）


func setup(p: Array[String], cur: int, nxt: int, width: float, all_done := false, with_tags := true) -> void:
	places = p
	current = cur
	next = nxt
	done = all_done
	tags = with_tags
	if not tags:
		DOT = 12.0
		NAME_SIZE = 18
		KANJI_SIZE = 16
	custom_minimum_size = Vector2(width, height())
	size = custom_minimum_size


func height() -> float:
	return _line_y() + DOT + 6.0 + NAME_SIZE * 1.45 + KANJI_SIZE * 1.45 + 4.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := _step()
	for i in places.size():
		var st: Dictionary = StageDB.get_stage(places[i]) if StageDB.stage_ids().has(places[i]) else {"name": places[i], "kanji": ""}
		var col := T.INK if (done or i <= next or (next < 0 and i <= current)) else Color(0.45, 0.42, 0.46)
		var n := T.label(st["name"], NAME_SIZE, col, HORIZONTAL_ALIGNMENT_CENTER)
		n.position = Vector2(_x(i) - w * 0.5, _line_y() + DOT + 4.0)
		n.size = Vector2(w, NAME_SIZE * 1.45)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(n)
		names.append(n)
		if st["kanji"] != "":
			var k := T.label("（%s）" % st["kanji"], KANJI_SIZE, col, HORIZONTAL_ALIGNMENT_CENTER)
			k.add_theme_font_override("font", Game.font_regular)
			k.position = Vector2(_x(i) - w * 0.5, _line_y() + DOT + 4.0 + NAME_SIZE * 1.45)
			k.size = Vector2(w, KANJI_SIZE * 1.45)
			k.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(k)
	if tags:
		if current >= 0 and current < places.size():
			add_child(_tag("いま ここ", NOW.darkened(0.25), _x(current)))
		if next >= 0 and next < places.size():
			add_child(_tag("つぎは ここ", NEXT, _x(next)))


## 場所 1 つぶんの 幅
func _step() -> float:
	return size.x / maxf(places.size(), 1)


func _x(i: int) -> float:
	return _step() * (i + 0.5)


func _line_y() -> float:
	return LINE_Y if tags else DOT + 6.0


## 名前が 場所 1 つぶんの 幅に 入るか（テストと 画面が 見る）
func fits() -> bool:
	var w := _step() - 4.0
	for i in places.size():
		var st: Dictionary = StageDB.get_stage(places[i]) if StageDB.stage_ids().has(places[i]) else {"name": places[i], "kanji": ""}
		if Game.font_bold.get_string_size(st["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x > w:
			return false
		if Game.font_regular.get_string_size("（%s）" % st["kanji"], HORIZONTAL_ALIGNMENT_LEFT, -1, KANJI_SIZE).x > w:
			return false
	return true


func _tag(text: String, col: Color, x: float) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := T.rounded(col, 16, 3, col.darkened(0.3))
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := T.label(text, 20, Color.WHITE if col == NEXT else T.INK)
	p.add_child(l)
	var w := p.get_combined_minimum_size().x
	p.position = Vector2(clampf(x - w * 0.5, 0.0, size.x - w), 0.0)
	return p


func _process(delta: float) -> void:
	_t += delta
	if tags and next >= 0:
		queue_redraw()


func _draw() -> void:
	var y := _line_y()
	var n := places.size()
	# 線：とおった ところは きいろ、これからは うすい 灰色。あいだに やじるしの 形
	for i in range(1, n):
		var a := Vector2(_x(i - 1) + DOT, y)
		var b := Vector2(_x(i) - DOT, y)
		var passed := done or i <= current or (next >= 0 and i < next)
		var col := PASSED if passed else FUTURE
		draw_line(a, b, EDGE, 10.0, true)
		draw_line(a, b, col, 6.0, true)
		var m := (a + b) * 0.5
		var tri := PackedVector2Array([m + Vector2(-7, -9), m + Vector2(9, 0), m + Vector2(-7, 9)])
		draw_colored_polygon(tri, EDGE if passed else Color(0.6, 0.58, 0.62))
	# 場所の まる
	for i in n:
		var c := Vector2(_x(i), y)
		var fill := FUTURE
		var r := DOT
		if done or i < current or (next >= 0 and i < next):
			fill = PASSED
		if i == current:
			fill = NOW
			r = DOT + 4.0
		draw_circle(c, r + 3.0, EDGE)
		draw_circle(c, r, fill)
		if i == current:
			draw_circle(c, r * 0.4, EDGE)
		if i == next:
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			draw_circle(c, r, Color.WHITE)
			draw_arc(c, r + 6.0 + 4.0 * pulse, 0, TAU, 32, NEXT, 4.0, true)
			draw_circle(c, r * 0.45, NEXT)


## カルテの 紙の 1 行：「くち（口）→ しょくどう（食道）→ い（胃）」。やじるしは 形
static func inline(p: Array[String], font_size: int, color: Color) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	for i in p.size():
		if i > 0:
			var arrow := Control.new()
			arrow.custom_minimum_size = Vector2(font_size * 0.8, font_size * 1.2)
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			arrow.draw.connect(func():
				var s := arrow.size
				var m := Vector2(s.x * 0.5, s.y * 0.55)
				var h := font_size * 0.3
				arrow.draw_colored_polygon(PackedVector2Array([m + Vector2(-h, -h), m + Vector2(h, 0), m + Vector2(-h, h)]), color))
			hb.add_child(arrow)
		var name := EpisodeDB.place_name(p[i])
		var l := T.label(name if name != "" else p[i], font_size, color)
		l.add_theme_font_override("font", Game.font_regular)
		hb.add_child(l)
	return hb
