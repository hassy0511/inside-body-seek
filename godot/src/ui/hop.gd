extends "res://src/ui/flow_screen.gd"
## みちの ちず：場面と 場面の あいだに 出る（とおりみちの あと、ふつうの 場面は あとの はなしの あと）。
## 患者の からだの地図に 入口から さいごの 場所までの みち 全体を えがき、とおった ところに しるし。
## 「いま ここ」（おえた 場所）から「つぎは ここ」（つぎの 場所）へ ミクロごうが みちに そって 動く（見せるだけ）。
## 右には とおる 場所の ならび（route_line.gd）と ピコの ひとこと（EpisodeDB.hop_say）。ボタン 1 つで 進む。
## from ＝ -1 は 入口（遊びなおしで「とおりみちを とばす」を えらんだ とき：入口から さいしょの ふつうの 場面へ）。
## - ボタンは はじめから 押せて フォーカスが ある。動きの とちゅうでも よい。時間で 勝手に 進まない

signal finished

const BodyMap := preload("res://src/ui/body_map.gd")
const RouteLine := preload("res://src/ui/route_line.gd")
const Journey := preload("res://src/ui/journey.gd")
## ピコの ふきだしの 文：28 px、幅 430、5 行まで（テストが 本物の フォントで はかる）
const SAY_SIZE := 28
const SAY_WIDTH := 430.0
const SAY_LINES := 5
const MAP_POS := Vector2(0, 34)
const MAP_SIZE := Vector2(560, 560)
const PANEL_X := 600.0
const ROW_POS := Vector2(600, 34)
const ROW_SIZE := Vector2(580, 200)
const BUBBLE_POS := Vector2(600, 250)
const BUBBLE_W := 580.0
const SPEED := 150.0        # ミクロごうの 速さ（px／秒）
const SMALL := 0.5
const YELLOW := Color(1.0, 0.86, 0.35)
const BLUE := Color(0.3, 0.62, 0.9)

var ep: Dictionary
var from := -1
var to := 0
var trip: Dictionary = {}
var button: Button
var line: Control             # route_line（テストが 見る）
var say_text := ""
var _map: BodyMap
var _fx: Control
var _bubble: PanelContainer
var _all := PackedVector2Array()    # みち 全体（入れ物の 中の 座標）
var _hop := PackedVector2Array()    # いまから 動く ところ（from → to）
var _done_i := 0                    # _all の 中で ここまでは とおった
var _now_chip: PanelContainer
var _next_chip: PanelContainer
var _t := 0.0
var _frozen := false
var _heading := 0.0
var _flip := 1.0


static func say_fits(text: String) -> bool:
	return lines_of(text, SAY_SIZE, SAY_WIDTH) <= SAY_LINES


func setup(e: Dictionary, from_scene: int, to_scene: int) -> void:
	ep = e
	from = from_scene
	to = to_scene
	trip = EpisodeDB.trip(ep)
	say_text = EpisodeDB.hop_say(ep, from, to)


func _ready() -> void:
	var box := make_stage(Color(0.93, 0.95, 1.0))
	add_heading("みちの ちず")
	_map = BodyMap.new()
	_map.setup(ep["patient"], MAP_SIZE)
	_map.position = MAP_POS
	box.add_child(_map)
	_build_paths()
	_fx = Control.new()
	_fx.position = MAP_POS
	_fx.size = MAP_SIZE
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	box.add_child(_fx)
	# 地図の 上の ふだ：「いま ここ」は 点の ひだり、「つぎは ここ」は 点の みぎ（2 つの 点が ちかくても 重ならない）
	_now_chip = _chip("いま ここ", YELLOW, YELLOW.darkened(0.3), T.INK)
	box.add_child(_now_chip)
	_next_chip = _chip("つぎは ここ", BLUE, BLUE.darkened(0.3), Color.WHITE)
	box.add_child(_next_chip)
	_place_chips()
	# 右上：とおる 場所の ならび
	var row := PanelContainer.new()
	row.position = ROW_POS
	row.size = ROW_SIZE
	row.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 26, 5, (EpisodeDB.speaker(ep["patient"])["color"] as Color)))
	box.add_child(row)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	row.add_child(rv)
	var who: String = EpisodeDB.speaker(ep["patient"])["name"]
	rv.add_child(T.label("%sの からだの なかの みち" % who, 20, (EpisodeDB.speaker(ep["patient"])["color"] as Color).darkened(0.5)))
	line = RouteLine.new()
	# とばした ときは 入口が「いま ここ」（地図の ふだと そろえる。入口が さいしょの 場所の ときだけ ならびに ある）
	var stops := EpisodeDB.stops(ep)
	var cur := from
	if from < 0 and not stops.is_empty() and stops[0] == trip.get("entry", ""):
		cur = 0
	line.setup(stops, cur, to, ROW_SIZE.x - 44.0)
	rv.add_child(line)
	# 右なか：ピコの ひとこと
	_bubble = PanelContainer.new()
	_bubble.position = BUBBLE_POS
	_bubble.size = Vector2(BUBBLE_W, 0)
	_bubble.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 30, 6, EpisodeDB.PICO["color"]))
	box.add_child(_bubble)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 14)
	_bubble.add_child(bh)
	var pico := T.portrait("pico", "happy", Vector2(90, 90), EpisodeDB.PICO["color"])
	pico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bh.add_child(pico)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 2)
	bh.add_child(tv)
	tv.add_child(T.label(EpisodeDB.PICO["name"], 18, Color(0.3, 0.5, 0.75)))
	var say := T.body(say_text, SAY_SIZE)
	say.custom_minimum_size = Vector2(SAY_WIDTH, 0)
	tv.add_child(say)
	# 右下：ボタン（はじめから 押せる）
	button = T.button("しゅっぱつ！ ▶", 32)
	button.position = Vector2(810, 548)
	button.size = Vector2(370, 82)
	T.colored_button(button, T.YELLOW, T.YELLOW_DARK)
	for side in ["left", "right", "top", "bottom"]:
		button.set("focus_neighbor_" + side, NodePath("."))
	button.pressed.connect(func():
		if not locked():
			Sfx.play("click")
			finished.emit())
	box.add_child(button)
	set_focus(button)
	lock()


## 地図の 上の みち（入れ物の 中の 座標）
func _build_paths() -> void:
	var pts: PackedVector2Array = trip.get("points", PackedVector2Array())
	var at: Dictionary = trip.get("at", {})
	for p in pts:
		_all.append(_map.to_local_pos(p))
	if _all.is_empty():
		_all.append(MAP_SIZE * 0.5)   # データの まちがい（validate() が 止める）。それでも 画面は 出す
	var a: int = clampi(at.get(from, 0), 0, _all.size() - 1)
	var b: int = clampi(at.get(to, _all.size() - 1), a, _all.size() - 1)
	_done_i = a
	_hop = _all.slice(a, b + 1)
	if _hop.size() < 1:
		_hop.append(_all[a])


## いまの 点（おえた 場所 か 入口）と つぎの 点
func now_point() -> Vector2:
	return _hop[0]


func next_point() -> Vector2:
	return _hop[_hop.size() - 1]


## ミクロごうの 動く みち（テストが 見る）
func hop_points() -> PackedVector2Array:
	return _hop


func _travel() -> float:
	return maxf(0.8, Journey._length(_hop) / SPEED)


## 動きが おわる 時刻（0.4 秒 まって から 動く）
func rest_time() -> float:
	return 0.4 + _travel() + 0.3


## 撮影用：動きを frac（0〜1）の 所で 止める
func freeze_at(frac: float) -> void:
	_frozen = true
	_t = clampf(frac, 0.0, 1.0) * rest_time()
	_fx.queue_redraw()


func _process(delta: float) -> void:
	super(delta)
	if not _frozen:
		_t += delta
	_fx.queue_redraw()


func _chip(text: String, bg: Color, border: Color, ink: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := T.rounded(bg, 18, 3, border)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(T.label(text, 22, ink))
	return p


func _place_chips() -> void:
	for pair in [[_now_chip, now_point(), -1.0], [_next_chip, next_point(), 1.0]]:
		var c: PanelContainer = pair[0]
		var pt: Vector2 = pair[1] + MAP_POS
		var side: float = pair[2]
		c.size = Vector2.ZERO
		var cs := c.get_combined_minimum_size()
		var x := pt.x + 30.0 if side > 0.0 else pt.x - 30.0 - cs.x
		x = clampf(x, MAP_POS.x + 4.0, MAP_POS.x + MAP_SIZE.x - cs.x - 4.0)
		var y := pt.y - cs.y * 0.5
		# 2 つの 点が たてに ちかい とき：「いま ここ」は 少し 上、「つぎは ここ」は 少し 下へ
		if now_point().distance_to(next_point()) < 60.0:
			y += side * 14.0
		c.position = Vector2(x, y)


# ---------------------------------------------------------------- えがく
func _draw_fx() -> void:
	var dark := Color(0.35, 0.25, 0.3)
	var f := Journey._ease(clampf((_t - 0.4) / _travel(), 0.0, 1.0))
	# みち 全体（点線）、とおった ところ（きいろ）、いま 動く ところ（きいろが のびる）
	if _all.size() >= 2:
		_dotted(_all)
		var passed := _all.slice(0, _done_i + 1)
		if passed.size() >= 2:
			_fx.draw_polyline(passed, dark, 13, true)
			_fx.draw_polyline(passed, YELLOW, 8, true)
		if _hop.size() >= 2 and f > 0.0:
			var part := Journey._part(_hop, f)
			if part.size() >= 2:
				_fx.draw_polyline(part, dark, 13, true)
				_fx.draw_polyline(part, YELLOW, 8, true)
	# 場面の 場所の しるし（とおった：きいろ、いま：きいろの 二重、つぎ：あおの 輪が ひかる、まだ：しろ）
	var at: Dictionary = trip.get("at", {})
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	for i in ep["scenes"].size():
		if not at.has(i) or at[i] >= _all.size():
			continue
		var p: Vector2 = _all[at[i]]
		var col := Color(1, 1, 1, 0.95)
		if (from >= 0 and i <= from) or (from < 0 and i < to):
			col = YELLOW
		_fx.draw_circle(p, 13.0, dark)
		_fx.draw_circle(p, 9.0, col)
		if i == to:
			_fx.draw_arc(p, 20.0 + 6.0 * pulse, 0, TAU, 40, dark, 7, true)
			_fx.draw_arc(p, 20.0 + 6.0 * pulse, 0, TAU, 40, BLUE, 4, true)
	if from < 0:
		# 入口の 点
		_fx.draw_arc(now_point(), 16.0, 0, TAU, 32, dark, 6, true)
		_fx.draw_arc(now_point(), 16.0, 0, TAU, 32, YELLOW, 3, true)
	# ミクロごう
	var pos := Journey._at(_hop, f)
	var moving := f > 0.0 and f < 1.0
	if moving and _hop.size() >= 2:
		var ahead := Journey._at(_hop, minf(f + 0.02, 1.0)) - pos
		if ahead.length() > 0.01:
			if absf(ahead.x) > 0.15:
				_flip = 1.0 if ahead.x > 0.0 else -1.0
			var target := clampf(atan2(ahead.y, absf(ahead.x)), -1.2, 1.2) * _flip
			_heading = lerp_angle(_heading, target, 0.25)
	else:
		_heading = lerp_angle(_heading, 0.0, 0.12)
		pos.y += sin(_t * 3.0) * 1.5
	_fx.draw_circle(pos, 30.0, Color(1, 1, 1, 0.55))
	Journey.draw_ship(_fx, pos, SMALL, _heading, _flip, _t)


func _dotted(p: PackedVector2Array) -> void:
	var total := Journey._length(p)
	var d := 0.0
	while d <= total:
		var q := Journey._at(p, d / maxf(total, 0.001))
		_fx.draw_circle(q, 5.5, Color(0.35, 0.25, 0.3))
		_fx.draw_circle(q, 3.5, Color(1, 1, 1, 0.95))
		d += 16.0


## はみ出しの 説明（無ければ ""）：ふきだしが ボタンに かからない・ならびが 箱に 入る・道と ふだが 地図の 中
func overflow() -> String:
	var bh := _bubble.get_combined_minimum_size().y
	if BUBBLE_POS.y + bh > button.position.y - 8.0:
		return "ふきだしが 高い（%.0f px）" % bh
	var rh: float = line.get_parent().get_parent().get_combined_minimum_size().y
	if rh > ROW_SIZE.y:
		return "とおる 場所の ならびが 高い（%.0f px）" % rh
	if not line.fits():
		return "とおる 場所の 名前が ならびに 入らない"
	var area := Rect2(Vector2.ZERO, MAP_SIZE).grow(-10.0)
	for p in _all:
		if not area.has_point(p):
			return "道の 点 %s が 地図の 外" % p
	for c in [_now_chip, _next_chip]:
		if not Rect2(MAP_POS, MAP_SIZE).encloses(Rect2(c.position, c.get_combined_minimum_size())):
			return "地図の ふだが 地図の 外"
	return ""


func fits() -> bool:
	return overflow() == ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()   # もどる 先は 無い
