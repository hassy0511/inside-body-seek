## 子ども向けの まるい UI テーマをコードで作る。
const INK := Color(0.27, 0.16, 0.22)
const PINK := Color(1.0, 0.72, 0.8)
const PINK_LIGHT := Color(1.0, 0.84, 0.88)
const PINK_DARK := Color(0.93, 0.55, 0.68)
const CREAM := Color(1.0, 0.98, 0.95)
const SKY := Color(0.62, 0.86, 1.0)
const MINT := Color(0.6, 0.9, 0.75)
const YELLOW := Color(1.0, 0.86, 0.35)


static func build(bold: Font, regular: Font) -> Theme:
	var t := Theme.new()
	t.default_font = bold
	t.default_font_size = 26
	# Button
	t.set_stylebox("normal", "Button", rounded(PINK, 22, 3, PINK_DARK))
	t.set_stylebox("hover", "Button", rounded(PINK_LIGHT, 22, 3, PINK_DARK))
	t.set_stylebox("pressed", "Button", rounded(PINK_DARK, 22, 3, PINK_DARK))
	t.set_stylebox("disabled", "Button", rounded(Color(0.88, 0.86, 0.87), 22, 3, Color(0.75, 0.72, 0.74)))
	t.set_stylebox("focus", "Button", outline(YELLOW, 22, 5))
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
