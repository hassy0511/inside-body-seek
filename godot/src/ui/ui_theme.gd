## 子ども向けの まるい UI テーマをコードで作る。
const INK := Color(0.27, 0.16, 0.22)
const PINK := Color(1.0, 0.72, 0.8)
const PINK_LIGHT := Color(1.0, 0.84, 0.88)
const PINK_DARK := Color(0.93, 0.55, 0.68)
const CREAM := Color(1.0, 0.98, 0.95)
const SKY := Color(0.62, 0.86, 1.0)
const MINT := Color(0.6, 0.9, 0.75)
const YELLOW := Color(1.0, 0.86, 0.35)
const YELLOW_DARK := Color(0.85, 0.6, 0.1)
const GREY := Color(0.5, 0.45, 0.5)
## フォーカスの わくの 色：黄色・ピンク・水色・みどり どの ボタンの 上でも 見える こい 色
const FOCUS := Color(0.36, 0.26, 0.72)
## 行の 途中で 切らない しるし（WORD JOINER）。nobreak() が 字の 間に はさむ
const WJ := "\u2060"
const BREAK_AFTER := [" ", "　", "\n", "。", "、", "！", "？", "…"]


static func build(bold: Font, regular: Font) -> Theme:
	var t := Theme.new()
	t.default_font = bold
	t.default_font_size = 26
	# Button
	t.set_stylebox("normal", "Button", rounded(PINK, 22, 3, PINK_DARK))
	t.set_stylebox("hover", "Button", rounded(PINK_LIGHT, 22, 3, PINK_DARK))
	t.set_stylebox("pressed", "Button", rounded(PINK_DARK, 22, 3, PINK_DARK))
	t.set_stylebox("disabled", "Button", rounded(Color(0.88, 0.86, 0.87), 22, 3, Color(0.75, 0.72, 0.74)))
	t.set_stylebox("focus", "Button", focus_ring(22))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.52, 0.54))
	t.set_font_size("font_size", "Button", 30)
	# Panel
	t.set_stylebox("panel", "Panel", rounded(Color(1, 1, 1, 0.94), 28, 4, PINK))
	t.set_stylebox("panel", "PanelContainer", rounded(Color(1, 1, 1, 0.94), 28, 4, PINK))
	# Label
	t.set_color("font_color", "Label", INK)
	t.set_font("font", "Label", bold)
	# RichTextLabel
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("normal_font", "RichTextLabel", regular)
	t.set_font("bold_font", "RichTextLabel", bold)
	# Slider
	t.set_stylebox("slider", "HSlider", rounded(Color(0.9, 0.85, 0.88), 8, 0, Color.TRANSPARENT))
	t.set_stylebox("grabber_area", "HSlider", rounded(PINK_DARK, 8, 0, Color.TRANSPARENT))
	t.set_stylebox("grabber_area_highlight", "HSlider", rounded(PINK_DARK, 8, 0, Color.TRANSPARENT))
	# CheckButton / CheckBox font
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_color", "CheckBox", INK)
	# ScrollContainer
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return t


static func rounded(bg: Color, radius := 20, border := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.anti_aliasing = true
	return s


static func outline(color: Color, radius := 20, width := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.draw_center = false
	s.set_corner_radius_all(radius)
	s.set_border_width_all(width)
	s.border_color = color
	s.anti_aliasing = true
	return s


## フォーカスの わく：ボタンの 外がわを かこむ 輪（ボタンの 色に うもれない）
static func focus_ring(radius := 22) -> StyleBoxFlat:
	var s := outline(FOCUS, radius + 6, 5)
	s.set_expand_margin_all(6)
	return s


## わかち書きの 文を、空白と 句読点の あとでだけ 折りかえす ように する。
## そのままだと かなの 間なら どこでも 折れて「ミクロ／ごう」の ように ことばが 切れる（子どもが 読みにくい）。
## 字の 間に 見えない しるし（WJ）を はさむだけ。行に 入らない 長い ことばは いままで どおり 途中で 折れる。
static func nobreak(text: String) -> String:
	var out := ""
	var n := text.length()
	for i in n:
		var ch := text[i]
		out += ch
		if i + 1 < n and not BREAK_AFTER.has(ch) and not (text[i + 1] in [" ", "　", "\n"]):
			out += WJ
	return out


## 自動で 折りかえす 本文の ラベル（ことばの 途中で 折らない）。あとで 文を 入れかえる ときも nobreak() を 通す
static func body(text: String, size := 26, color := INK, regular := true) -> Label:
	var l := label(nobreak(text), size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if regular:
		l.add_theme_font_override("font", Game.font_regular)
	return l


static func label(text: String, size := 26, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func button(text: String, size := 30, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if min_w > 0.0:
		b.custom_minimum_size = Vector2(min_w, 0)
	return b


static func colored_button(b: Button, bg: Color, border: Color) -> Button:
	b.add_theme_stylebox_override("normal", rounded(bg, 22, 3, border))
	b.add_theme_stylebox_override("hover", rounded(bg.lightened(0.12), 22, 3, border))
	b.add_theme_stylebox_override("pressed", rounded(border, 22, 3, border))
	return b


## 納品された絵（res://assets/ui/<name>.png）があれば そのテクスチャ、なければ null。
## Codex から届いた UI・カードの挿絵・顔アイコンは、同じ名前で置くだけで ここから拾われる（docs/art_orders/取り込み手順.md）。
static func art(name: String) -> Texture2D:
	var path := "res://assets/ui/%s.png" % name
	if ResourceLoader.exists(path):
		var t := load(path)
		if t is Texture2D:
			return t
	return null


## 納品された絵を 指定の大きさで出す TextureRect（絵が無ければ null）
static func art_rect(name: String, size: Vector2) -> TextureRect:
	var tex := art(name)
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## 患者・ピコの 絵。<who>_face_<mood>.png（prefer_full なら 先に <who>_fullbody_<mood>.png）が あれば それ。
## 無ければ コードで 描く 仮の 顔（ピコは pico_face_normal.png → コードの 顔）。prefer_full の 仮の 絵は 顔 ＋ 上半身。
## mood：患者は "sick"／"happy"、ピコは "normal"／"happy"／"surprised"／"worried"。color は EpisodeDB.speaker(who)["color"]。
static func portrait(who: String, mood: String, size: Vector2, color: Color, prefer_full := false) -> Control:
	var names: Array[String] = []
	if prefer_full:
		names.append("%s_fullbody_%s" % [who, mood])
	names.append("%s_face_%s" % [who, mood])
	if who == "pico":
		names.append("pico_face_normal")
	for n in names:
		var tr := art_rect(n, size)
		if tr:
			tr.size = size
			return tr
	var c := Control.new()
	c.custom_minimum_size = size
	c.size = size
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		if who == "pico":
			draw_pico(c, c.size * 0.5 + Vector2(0, c.size.y * 0.05), minf(c.size.x, c.size.y) * 0.38)
		elif prefer_full:
			draw_person(c, c.size, color, mood)
		else:
			draw_face(c, c.size * 0.5, minf(c.size.x, c.size.y) * 0.44, color, mood))
	return c


## portrait() が 絵（PNG）を 見つけるか（テストが 両方の 道を 通った ことを 見る）
static func has_portrait_art(who: String, mood: String) -> bool:
	return art("%s_face_%s" % [who, mood]) != null


## ドクター・ピコの 仮の 顔（絵が 無い とき）。r は 顔の 半径
static func draw_pico(ci: CanvasItem, c: Vector2, r: float) -> void:
	var k := r / 34.0
	var dark := Color(0.2, 0.2, 0.3)
	ci.draw_circle(c + Vector2(0, 2) * k, 36 * k, Color(0.3, 0.45, 0.6, 0.25))
	ci.draw_circle(c, r, Color(0.75, 0.92, 1.0))
	ci.draw_line(c + Vector2(0, -34) * k, c + Vector2(0, -46) * k, Color(0.3, 0.45, 0.6), 4 * k)
	ci.draw_circle(c + Vector2(0, -48) * k, 6 * k, Color(1.0, 0.8, 0.3))
	ci.draw_circle(c + Vector2(-12, -4) * k, 6 * k, dark)
	ci.draw_circle(c + Vector2(12, -4) * k, 6 * k, dark)
	ci.draw_circle(c + Vector2(-10, -6) * k, 2 * k, Color.WHITE)
	ci.draw_circle(c + Vector2(14, -6) * k, 2 * k, Color.WHITE)
	ci.draw_arc(c + Vector2(0, 8) * k, 10 * k, 0.2, PI - 0.2, 12, dark, 3 * k)


## 患者の 仮の 顔：はだ色の 丸 ＋ 患者の 色の かみ ＋ 目 ＋ 口。
## happy は にっこり。それ以外（sick など）は こまった まゆ ＋ への字の 口 ＋ あせ 1 つぶ。
static func draw_face(ci: CanvasItem, c: Vector2, r: float, color: Color, mood: String) -> void:
	var skin := Color(1.0, 0.9, 0.8)
	var dark := Color(0.27, 0.2, 0.25)
	var w := maxf(2.0, r * 0.08)
	ci.draw_circle(c + Vector2(0, r * 0.06), r * 1.02, Color(0.3, 0.2, 0.25, 0.12))
	ci.draw_circle(c, r, skin)
	# かみ：顔の 上を おおう 弧（弦で 切った 形）
	var hair := PackedVector2Array()
	for i in 25:
		var a := PI + 0.22 + (PI - 0.44) * i / 24.0
		hair.append(c + Vector2(cos(a), sin(a)) * r * 1.04)
	ci.draw_colored_polygon(hair, color.darkened(0.3))
	ci.draw_circle(c + Vector2(-r * 0.58, r * 0.3), r * 0.15, Color(1.0, 0.6, 0.65, 0.45))
	ci.draw_circle(c + Vector2(r * 0.58, r * 0.3), r * 0.15, Color(1.0, 0.6, 0.65, 0.45))
	for sx in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(sx * r * 0.34, r * 0.08), r * 0.1, dark)
		ci.draw_circle(c + Vector2(sx * r * 0.34 + r * 0.03, r * 0.05), r * 0.035, Color.WHITE)
	if mood == "happy":
		ci.draw_arc(c + Vector2(0, r * 0.3), r * 0.28, 0.3, PI - 0.3, 14, dark, w)
	else:
		ci.draw_arc(c + Vector2(0, r * 0.68), r * 0.24, PI + 0.45, TAU - 0.45, 14, dark, w)
		for sx in [-1.0, 1.0]:
			ci.draw_line(c + Vector2(sx * r * 0.5, -r * 0.1), c + Vector2(sx * r * 0.22, -r * 0.2), dark, w)
		var drop := c + Vector2(r * 0.8, -r * 0.02)
		ci.draw_colored_polygon(PackedVector2Array([drop + Vector2(0, -r * 0.24), drop + Vector2(-r * 0.09, -r * 0.02), drop + Vector2(r * 0.09, -r * 0.02)]), Color(0.55, 0.8, 1.0))
		ci.draw_circle(drop, r * 0.1, Color(0.55, 0.8, 1.0))


## 患者の 仮の 全身（上半身）：患者の 色の ふく ＋ くび ＋ 顔。はなしの 画面の 大きい わく用
static func draw_person(ci: CanvasItem, size: Vector2, color: Color, mood: String) -> void:
	var r := size.x * 0.3
	var c := Vector2(size.x * 0.5, size.y * 0.36)
	var top := c.y + r * 0.95
	var shirt := rounded(color, int(size.x * 0.2), 4, color.darkened(0.25))
	shirt.corner_radius_bottom_left = 0
	shirt.corner_radius_bottom_right = 0
	shirt.border_width_bottom = 0
	ci.draw_style_box(shirt, Rect2(size.x * 0.14, top, size.x * 0.72, size.y - top - 5.0))   # 下は 台紙の ふちの 手前まで
	ci.draw_rect(Rect2(c.x - r * 0.28, c.y + r * 0.7, r * 0.56, r * 0.5), Color(1.0, 0.86, 0.75))
	draw_face(ci, c, r, color, mood)


## からだの地図の 絵：bodymap_<who>.png → bodymap_hana.png → 仮の SVG（はなちゃんの 絵なので はなちゃんだけ）。
## null なら 呼ぶ 側が コードで 描く（guess.gd の _draw_body）
static func bodymap(who: String) -> Texture2D:
	var tex := art("bodymap_%s" % who)
	if tex == null:
		tex = art("bodymap_hana")
	if tex == null and who == "hana" and ResourceLoader.exists("res://assets/ui/body_map.svg"):
		tex = load("res://assets/ui/body_map.svg")
	return tex


## 小さい ほし 3 つ（flags の 数だけ 黄色）。r は ほしの 半径
static func stars(flags: Array, r: float, gap := 6.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(r * 6.0 + gap * 2.0, r * 2.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		for i in 3:
			var p := Vector2(r + i * (r * 2.0 + gap), c.size.y * 0.5 + r * 0.06)
			c.draw_colored_polygon(star_points(p + Vector2(0, r * 0.1), r * 1.12), Color(0.45, 0.3, 0.1, 0.25))
			c.draw_colored_polygon(star_points(p, r), YELLOW if flags[i] else Color(0.93, 0.91, 0.92)))
	return c


## 画面の拡大率（SubViewport を くっきり描くため）
static func window_scale(c: Control) -> float:
	var vp := c.get_viewport()
	if vp == null:
		return 1.0
	return clampf(vp.get_screen_transform().get_scale().x, 1.0, 3.0)


## ハートや星などを描く小さい Control
static func star_points(center: Vector2, r: float, inner := 0.45) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * inner
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	return pts


static func draw_heart(ci: CanvasItem, center: Vector2, r: float, color: Color) -> void:
	ci.draw_circle(center + Vector2(-r * 0.5, -r * 0.3), r * 0.55, color)
	ci.draw_circle(center + Vector2(r * 0.5, -r * 0.3), r * 0.55, color)
	var tri := PackedVector2Array([center + Vector2(-r * 1.02, -r * 0.12), center + Vector2(r * 1.02, -r * 0.12), center + Vector2(0, r * 0.95)])
	ci.draw_colored_polygon(tri, color)
