extends Control
## からだの地図（よそうの 画面と たびの 画面が 使う）。
## 絵は T.bodymap(who)（bodymap_<who>.png、はなちゃんだけ 仮の SVG）。無ければ コードで 描く 仮の 地図：
## 患者の 色の 服、大人（おとうさん・おじいちゃん）は えりの ある 服・ベルト・長ズボン・茶色の くつ・大人の かみがた、
## 子どもは 半ズボンと はだの ひざ・ほっぺ。かみと 服は 発注書の 人物の 説明に 合わせた（W1_02 2 章）。
## 体の 配置と 臓器の 位置は 4 人 同じ（docs/art_orders/W1_02_患者さんたち.md 4.3・4.4。臓器は EpisodeDB.ORGAN_POS）。
## 絵の 比は 22：31。area（入れ物の 中の わく）に たてよこの 比を 保って 中央に 置く。点の 位置は point() で 聞く。

const T := preload("res://src/ui/ui_theme.gd")
const ASPECT := 22.0 / 31.0
const ADULTS := ["papa", "jiji"]
const LINE := Color(0.35, 0.29, 0.33)
const SKIN := Color(1.0, 0.89, 0.78)

var who := ""
var area := Rect2()          # 絵を 置く わく（入れ物の 中の 座標）。空なら 入れ物 全体
var _tex: Texture2D = null


func setup(patient: String, box: Vector2, inner := Rect2()) -> void:
	who = patient
	size = box
	custom_minimum_size = box
	area = inner if inner.size != Vector2.ZERO else Rect2(Vector2.ZERO, box)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = T.bodymap(who)
	if _tex != null:
		var tr := TextureRect.new()
		tr.texture = _tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = image_rect().position
		tr.size = image_rect().size
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)


## 絵が 実際に 出ている わく。ORGAN_POS などの 0〜1 は この わくの 中の 位置
func image_rect() -> Rect2:
	var ratio := ASPECT
	if _tex == null:
		_tex = T.bodymap(who)
	if _tex != null:
		ratio = _tex.get_size().x / _tex.get_size().y
	var k := minf(area.size.x / ratio, area.size.y)
	var s := Vector2(k * ratio, k)
	return Rect2(area.position + (area.size - s) * 0.5, s)


## 地図の 0〜1 の 位置 → 入れ物の 中の 座標
func to_local_pos(p: Vector2) -> Vector2:
	var r := image_rect()
	return r.position + p * r.size


## 臓器・道の 点（EpisodeDB.map_point）の 入れ物の 中の 座標
func point(key: String) -> Vector2:
	return to_local_pos(EpisodeDB.map_point(key))


func is_drawn() -> bool:
	return T.bodymap(who) == null


func _draw() -> void:
	if T.bodymap(who) != null:
		return
	draw_body(self, image_rect(), who)


# ---------------------------------------------------------------- コードで 描く 仮の 地図
## r の 中に、患者 who の からだの地図を 描く（ほかの 画面でも 使える ように static）
static func draw_body(ci: CanvasItem, r: Rect2, patient: String) -> void:
	var W := r.size.x
	var H := r.size.y
	var P := func(x: float, y: float) -> Vector2: return r.position + Vector2(W * x, H * y)
	var col: Color = EpisodeDB.speaker(patient)["color"] if EpisodeDB.PATIENTS.has(patient) else Color(0.8, 0.8, 0.85)
	var adult: bool = ADULTS.has(patient)
	var shirt := col.lerp(Color.WHITE, 0.45)
	var pants := Color(0.36, 0.42, 0.62) if patient != "jiji" else Color(0.55, 0.47, 0.4)
	if not adult:
		pants = Color(0.42, 0.52, 0.85)
	var lw := maxf(2.0, W * 0.007)
	# あし（大人は 長ズボン、子どもは 半ズボン ＋ はだの ひざ）
	for sx in [-1.0, 1.0]:
		var x0: float = 0.5 + sx * 0.093
		var leg := Rect2(P.call(x0 - 0.066, 0.70), Vector2(W * 0.132, H * 0.262))
		if adult:
			ci.draw_style_box(T.rounded(pants, int(W * 0.05), int(lw), LINE), leg)
		else:
			ci.draw_style_box(T.rounded(SKIN, int(W * 0.05), int(lw), LINE), leg)
			ci.draw_style_box(T.rounded(pants, int(W * 0.04), int(lw), LINE), Rect2(leg.position, Vector2(leg.size.x, H * 0.1)))
		_ellipse(ci, P.call(x0, 0.968), W * 0.08, H * 0.016, Color(0.45, 0.33, 0.28) if adult else Color(1.0, 0.82, 0.48), LINE, lw)
	# うで（大人は 長そで、子どもは 半そで）。手は はだ
	for sx in [-1.0, 1.0]:
		var sh: Vector2 = P.call(0.5 + sx * 0.193, 0.323)
		var hand: Vector2 = P.call(0.5 + sx * 0.314, 0.653)
		var ar := W * 0.042
		_capsule(ci, sh, hand, ar, SKIN, LINE, lw)
		_capsule(ci, sh, sh.lerp(hand, 0.55 if patient == "papa" else (0.88 if adult else 0.3)), ar + lw * 0.5, shirt, LINE, lw)
		ci.draw_circle(hand, ar * 1.05, SKIN)
		ci.draw_arc(hand, ar * 1.05, 0, TAU, 20, LINE, lw, true)
	# どう（服）。大人は えりと ベルト、おじいちゃんは カーディガンの 中に クリーム色の シャツ
	ci.draw_rect(Rect2(P.call(0.462, 0.25), Vector2(W * 0.076, H * 0.058)), SKIN)
	ci.draw_style_box(T.rounded(shirt, int(W * 0.11), int(lw), LINE), Rect2(P.call(0.291, 0.298), Vector2(W * 0.418, H * 0.428)))
	if patient == "jiji":
		ci.draw_colored_polygon(PackedVector2Array([P.call(0.44, 0.30), P.call(0.56, 0.30), P.call(0.53, 0.72), P.call(0.47, 0.72)]), Color(1.0, 0.96, 0.86))
		for sx in [-1.0, 1.0]:
			ci.draw_line(P.call(0.5 + sx * 0.06, 0.30), P.call(0.5 + sx * 0.03, 0.722), col.darkened(0.3), W * 0.012)
	if adult:
		ci.draw_rect(Rect2(P.call(0.325, 0.688), Vector2(W * 0.35, H * 0.016)), Color(0.4, 0.3, 0.26))
	if adult:
		for sx in [-1.0, 1.0]:
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.318), P.call(0.5 + sx * 0.09, 0.296), P.call(0.5 + sx * 0.06, 0.345)]), Color.WHITE)
			ci.draw_polyline(PackedVector2Array([P.call(0.5, 0.318), P.call(0.5 + sx * 0.09, 0.296), P.call(0.5 + sx * 0.06, 0.345), P.call(0.5, 0.318)]), LINE, lw * 0.7, true)
	_draw_head(ci, P, W, H, patient, col, lw)
	_draw_organs(ci, P, W, H, lw)


## あたま・かみ・顔
static func _draw_head(ci: CanvasItem, P: Callable, W: float, H: float, patient: String, col: Color, lw: float) -> void:
	var c: Vector2 = P.call(0.5, 0.153)
	var rad := W * 0.164
	var hair := Color("#7A4935") if patient == "papa" else Color(0.28, 0.22, 0.2)
	var grey := Color(0.9, 0.9, 0.92)
	for sx in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(sx * rad * 1.02, rad * 0.12), rad * 0.2 + lw, LINE)
		ci.draw_circle(c + Vector2(sx * rad * 1.02, rad * 0.12), rad * 0.2, SKIN)
	# かみの うしろがわ（顔の 外に 出る ぶん）
	match patient:
		"papa":
			_arc_poly(ci, c, rad * 1.07, PI + 0.15, TAU - 0.15, hair)
		"kenta":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI + 0.05 + (PI - 0.1) * i / 12.0
				pts.append(c + Vector2(cos(a), sin(a)) * rad * (1.2 if i % 2 == 1 else 1.04))
			pts.append(c + Vector2(rad * 0.9, -rad * 0.05))
			pts.append(c + Vector2(-rad * 0.9, -rad * 0.05))
			ci.draw_colored_polygon(pts, hair)
		"jiji":   # ふんわりした 白っぽい グレーの かみ（はげに しない）
			for i in 7:
				var a := PI + 0.1 + (PI - 0.2) * i / 6.0
				_ellipse(ci, c + Vector2(cos(a), sin(a)) * rad * 0.95, rad * 0.3, rad * 0.26, grey, LINE, lw)
		_:
			_arc_poly(ci, c, rad * 1.08, PI - 0.2, TAU + 0.2, col.darkened(0.45))
	ci.draw_circle(c, rad + lw, LINE)
	ci.draw_circle(c, rad, SKIN)
	# まえがみ
	match patient:
		"papa":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-rad * 0.98, -rad * 0.15), c + Vector2(-rad * 0.85, -rad * 0.62), c + Vector2(-rad * 0.35, -rad * 0.98), c + Vector2(rad * 0.4, -rad * 0.97), c + Vector2(rad * 0.88, -rad * 0.6), c + Vector2(rad * 0.98, -rad * 0.15), c + Vector2(rad * 0.7, -rad * 0.5), c + Vector2(-rad * 0.1, -rad * 0.62), c + Vector2(-rad * 0.6, -rad * 0.45)]), hair)
		"kenta":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-rad * 0.95, -rad * 0.2), c + Vector2(-rad * 0.6, -rad * 0.92), c + Vector2(rad * 0.6, -rad * 0.92), c + Vector2(rad * 0.95, -rad * 0.2), c + Vector2(rad * 0.5, -rad * 0.45), c + Vector2(rad * 0.2, -rad * 0.3), c + Vector2(-rad * 0.15, -rad * 0.48), c + Vector2(-rad * 0.5, -rad * 0.32)]), hair)
		"jiji":
			_arc_poly(ci, c, rad, PI + 0.35, TAU - 0.35, grey)
		_:
			_arc_poly(ci, c, rad, PI + 0.3, TAU - 0.3, col.darkened(0.45))
	var dark := Color(0.27, 0.2, 0.25)
	var ey := c.y
	for sx in [-1.0, 1.0]:
		var e := Vector2(c.x + sx * W * 0.068, ey)
		ci.draw_circle(e, W * 0.016, dark)
		ci.draw_circle(e + Vector2(W * 0.005, -W * 0.005), W * 0.005, Color.WHITE)
		# まゆ（おじいちゃんは 白）
		var bc := Color(0.92, 0.92, 0.94) if patient == "jiji" else dark
		ci.draw_line(e + Vector2(-W * 0.03, -W * 0.045), e + Vector2(W * 0.03, -W * 0.05), bc, W * (0.014 if patient in ADULTS else 0.009))
		if patient == "jiji":   # 目じりの わらいじわ
			ci.draw_arc(e + Vector2(sx * W * 0.03, 0), W * 0.018, -0.6 if sx > 0 else PI - 0.6, 0.6 if sx > 0 else PI + 0.6, 6, Color(0.7, 0.5, 0.45), lw * 0.7)
		if not (patient in ADULTS):
			ci.draw_circle(e + Vector2(sx * W * 0.03, W * 0.045), W * 0.022, Color(1.0, 0.6, 0.65, 0.45))
	# はな・くち（くちは ORGAN_POS の くち（0.23）の 所）
	ci.draw_arc(P.call(0.5, 0.183), W * 0.014, 0.3, PI - 0.3, 10, Color(0.75, 0.5, 0.45), lw)
	var m: Vector2 = P.call(0.5, 0.222)
	var mouth := PackedVector2Array()
	for i in 11:
		var a := PI * i / 10.0
		mouth.append(m + Vector2(cos(a) * W * 0.04, sin(a) * W * 0.03))
	ci.draw_colored_polygon(mouth, Color(0.75, 0.3, 0.35))


## 臓器（4 人 同じ 位置・同じ 色。服の 上に すけて 見える ように 少し うすく）
static func _draw_organs(ci: CanvasItem, P: Callable, W: float, H: float, lw: float) -> void:
	var a := 0.9
	_ellipse(ci, P.call(0.5, 0.085), W * 0.108, H * 0.05, Color(0.95, 0.68, 0.78, a), LINE, lw * 0.6)
	for k in 3:
		ci.draw_arc(P.call(0.45 + k * 0.05, 0.08 + (k % 2) * 0.012), W * 0.025, 0.3, PI - 0.3, 8, Color(0.77, 0.43, 0.58), lw * 0.6)
	for sx in [-1.0, 1.0]:   # はい（肺）：ORGAN_POS の 点（0.34）は 左の はいの 中。形の まん中は もう少し 内がわ
		_ellipse(ci, P.call(0.5 + sx * 0.11, 0.425), W * 0.092, H * 0.083, Color(0.97, 0.72, 0.78, a), LINE, lw * 0.6)
	var eso := Color(0.93, 0.6, 0.53)
	ci.draw_polyline(PackedVector2Array([P.call(0.5, 0.245), P.call(0.5, 0.42), P.call(0.53, 0.47), P.call(0.55, 0.5)]), eso, W * 0.03, true)
	T.draw_heart(ci, P.call(0.58, 0.402), W * 0.058, Color(0.9, 0.3, 0.38))
	_ellipse(ci, P.call(0.58, 0.54), W * 0.1, H * 0.058, Color(1.0, 0.72, 0.45, a), LINE, lw * 0.6)
	for k in 3:
		var y := 0.62 + k * 0.035
		var pts := PackedVector2Array()
		for i in 17:
			var x := 0.36 + 0.28 * i / 16.0
			pts.append(P.call(x, y + sin(i * 0.8 + k) * 0.008))
		ci.draw_polyline(pts, eso, W * 0.035, true)
	# けっかん：画面の 左の うでに 赤と 青の 帯
	var sh: Vector2 = P.call(0.5 - 0.193, 0.33)
	var hand: Vector2 = P.call(0.5 - 0.314, 0.63)
	var n := (hand - sh).normalized().orthogonal() * W * 0.011
	ci.draw_line(sh + n, hand + n, Color(0.86, 0.25, 0.32), W * 0.02)
	ci.draw_line(sh - n, hand - n, Color(0.35, 0.5, 0.85), W * 0.02)


## 円の 一部を 弦で 切った 形（かみ）
static func _arc_poly(ci: CanvasItem, c: Vector2, rad: float, a0: float, a1: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var a := a0 + (a1 - a0) * i / 24.0
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	ci.draw_colored_polygon(pts, col)


## a から b への 太い 棒（はしは まるい）。r ＝ 太さの 半分
static func _capsule(ci: CanvasItem, a: Vector2, b: Vector2, r: float, col: Color, line_col: Color, lw: float) -> void:
	var n := (b - a).normalized().orthogonal()
	var base := atan2(n.y, n.x)
	var pts := PackedVector2Array()
	for i in 13:   # a の まわりは n → 外がわ → -n、b の まわりは -n → 外がわ → n
		var ang := base - PI * i / 12.0
		pts.append(a + Vector2(cos(ang), sin(ang)) * r)
	for i in 13:
		var ang := base + PI - PI * i / 12.0
		pts.append(b + Vector2(cos(ang), sin(ang)) * r)
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, line_col, lw, true)


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, line_col := Color.TRANSPARENT, lw := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)
	if lw > 0.0 and line_col.a > 0.0:
		pts.append(pts[0])
		ci.draw_polyline(pts, line_col, lw, true)
