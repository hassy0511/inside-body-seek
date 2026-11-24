extends Control
## はじめての そうじゅうの てびき（ひろい 場所 ＝ のりものの そうさ。くだの 場所では 出さない）。
## HUD の ひだり（ハートの 下）に 小さく 出す。ピコの ふきだしにも ミクロごうにも かからない。
## 子どもが「むきを かえる」（ひだり／みぎ）と「すすむ」（うえ）を どちらも やったら 消えて、セーブに「見た」と 書く（もう 出さない）。
## キーは 字の やじるしで なく 形で えがく（ブラウザ版の フォントに 無い 字は 四角に 化ける）。タッチの ときは タッチの 絵。

const T := preload("res://src/ui/ui_theme.gd")
const POS := Vector2(24, 132)
const SIZE := Vector2(270, 196)   # 小さく、少し すける（ひだりの は（歯）や てきが うしろに 見える）
const KEY := 38.0
const ART_H := 88.0
const EDGE := Color(0.35, 0.25, 0.3)
const DONE := Color(0.3, 0.62, 0.42)

var touch := false
var turned := false
var forward := false
var _closing := false
var _rows: Array[Label] = []
var _art: Control


## 出す ときか：まだ 見て いない ＋ ひろい 場所（くだで ない）
static func wanted(stage: Dictionary) -> bool:
	return not SaveData.steer_guide_seen() and stage.get("kind", "arena") != "tube"


func setup(on_touch: bool) -> void:
	touch = on_touch


func _ready() -> void:
	name = "SteerGuide"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	position = POS
	size = SIZE
	var panel := PanelContainer.new()
	panel.size = SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", T.rounded(Color(1, 1, 1, 0.72), 20, 4, T.YELLOW))
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	vb.add_child(T.label("そうじゅうの しかた", 18, Color(0.55, 0.42, 0.1)))
	_art = Control.new()
	_art.custom_minimum_size = Vector2(SIZE.x - 44, ART_H)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_art)
	vb.add_child(_art)
	for t in texts():
		var l := T.label(t, 18, T.INK)
		l.add_theme_font_override("font", Game.font_regular)
		vb.add_child(l)
		_rows.append(l)


## 出す 文（テストが 文の きまりを 見る）
func texts() -> Array[String]:
	if touch:
		return ["よこに ひく：むきを かえる", "うえに ひく：まえへ すすむ"]
	return ["ひだり・みぎ：むきを かえる", "うえ：まえへ すすむ"]


func _process(delta: float) -> void:
	if _closing:
		modulate.a = maxf(modulate.a - delta * 2.5, 0.0)
		if modulate.a <= 0.0:
			queue_free()
		return
	var was := [turned, forward]
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
		turned = true
	if Input.is_action_pressed("move_up"):
		forward = true
	if [turned, forward] != was:
		_rows[0].add_theme_color_override("font_color", DONE if turned else T.INK)
		_rows[1].add_theme_color_override("font_color", DONE if forward else T.INK)
		_art.queue_redraw()
	if turned and forward:
		SaveData.mark_steer_guide_seen()
		_closing = true


func is_closing() -> bool:
	return _closing


func _draw_art() -> void:
	if touch:
		_draw_touch()
	else:
		_draw_keys()


## キーボード：← → ↑ の キーの 形（やじるしは 三角）。やった ほうは みどりの ふち
func _draw_keys() -> void:
	var w := _art.size.x
	var mid := w * 0.5
	var low := ART_H - KEY - 4.0
	_key(Vector2(mid - KEY * 1.6 - KEY * 0.5, low), Vector2.LEFT, turned)
	_key(Vector2(mid + KEY * 1.6 - KEY * 0.5, low), Vector2.RIGHT, turned)
	_key(Vector2(mid - KEY * 0.5, low - KEY - 4.0), Vector2.UP, forward)
	# まわる しるし（ミクロごうの 上から 見た 形 ＋ まわる 弧）
	var c := Vector2(mid, low + KEY * 0.5)
	_art.draw_arc(c, 18.0, PI * 0.75, PI * 2.25, 20, EDGE, 3.0, true)
	_art.draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -5), c + Vector2(0, -14), c + Vector2(7, -5)]), Color("#FCC738"))
	_art.draw_polyline(PackedVector2Array([c + Vector2(-7, -5), c + Vector2(0, -14), c + Vector2(7, -5), c + Vector2(-7, -5)]), EDGE, 2.0, true)


func _key(pos: Vector2, dir: Vector2, done: bool) -> void:
	var r := Rect2(pos, Vector2(KEY, KEY))
	_art.draw_style_box(T.rounded(Color.WHITE, 10, 4, DONE if done else EDGE), r)
	var c := r.get_center()
	var a := dir * 12.0
	var n := dir.orthogonal() * 10.0
	_art.draw_colored_polygon(PackedVector2Array([c + a, c - a * 0.6 + n, c - a * 0.6 - n]), DONE if done else EDGE)


## タッチ：ひだりの まる（スティック）と、よこ・うえへ ひく やじるしの 形
func _draw_touch() -> void:
	var c := Vector2(_art.size.x * 0.5, ART_H - 40.0)
	_art.draw_circle(c, 36.0, Color(1, 1, 1, 0.6))
	_art.draw_arc(c, 36.0, 0, TAU, 40, EDGE, 3.0, true)
	_art.draw_circle(c, 16.0, Color(0.62, 0.86, 1.0))
	_art.draw_arc(c, 16.0, 0, TAU, 24, EDGE, 3.0, true)
	for d in [Vector2.LEFT, Vector2.RIGHT]:
		_arrow(c + d * 54.0, d, turned)
	_arrow(c + Vector2.UP * 30.0, Vector2.UP, forward)


func _arrow(at: Vector2, dir: Vector2, done: bool) -> void:
	var col := DONE if done else EDGE
	var n := dir.orthogonal()
	_art.draw_line(at - dir * 14.0, at + dir * 2.0, col, 6.0, true)
	_art.draw_colored_polygon(PackedVector2Array([at + dir * 14.0, at + n * 10.0, at - n * 10.0]), col)
