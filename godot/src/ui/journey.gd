extends "res://src/ui/flow_screen.gd"
## たびの 画面：からだに はいる（"enter"。よそうの あと）／からだから でる（"exit"。さいごの あとの はなしの あと、カルテの 前）。
## 1 話に 2 回 出る。だれの からだか（患者の 名前と 顔）・からだの地図の 上の 道・ミクロごうの 動き・ピコの ひとことを 見せる。
## - enter：外で ちいさく なる → 入口（ENTRANCES）から はいる → 道を とおって さいしょの 場所へ
## - exit ：さいごの 場所から 道を もどる → 出口（EXITS）から 外へ → もとの 大きさに もどる → 患者が げんきな 顔に
## - 動きは 見せるだけ。ボタンは はじめから あり（フォーカスも ある）、動きの とちゅうで 押して よい。時間で 勝手に 進まない
## - データは EpisodeDB.journey(ep, mode)（入口・出口は 話の "enter"／"exit"、道は ROUTE_LINKS）
## - enter の 行き先は さいしょの 場面の 場所（いまは 入口の 場所。とおりみちも 遊ぶので、ここで 先へ とばない）
## - enter：クリアずみで とおりみちが ある 話は「とおりみちを とばす」も 出す（フォーカスは ふつうの ボタンの まま。skipped）
## - exit：右に「とおった みち」（とおった 場所の ならび。route_line.gd）。その ぶん 患者の ふだを ひくく する

signal finished
signal skipped

## ピコの ふきだしの 文：28 px、幅 430、5 行まで（テストが 本物の フォントで はかる）
const SAY_SIZE := 28
const SAY_WIDTH := 430.0
const SAY_LINES := 5
const BodyMap := preload("res://src/ui/body_map.gd")
const MAP_POS := Vector2(0, 34)
const MAP_SIZE := Vector2(560, 560)
const PANEL_X := 600.0
const CARD_SIZE := Vector2(580, 210)
const BUBBLE_POS := Vector2(600, 262)
const EXIT_CARD_H := 130.0                 # exit の ときの 患者の ふだの 高さ（下に とおった みちを 入れる）
const EXIT_FACE := 100.0
const EXIT_NAME := 34                      # exit の ときの 患者の 名前の 大きさ
const ROUTE_Y := 170.0                     # exit の「とおった みち」の 上
const EXIT_BUBBLE_Y := 306.0
const RouteLine := preload("res://src/ui/route_line.gd")
const BUBBLE_SIZE := Vector2(580, 270)
const BIG := 1.8         # 外での ミクロごうの 大きさ（かけ算）
const SMALL := 0.5       # からだの 中での 大きさ
const SPEED := 190.0     # からだの 中を すすむ 速さ（px／秒）
const YELLOW := Color(1.0, 0.86, 0.35)

var ep: Dictionary
var mode := "enter"
var j: Dictionary = {}
var button: Button
var skip_button: Button = null   # 「とおりみちを とばす」（出す ときだけ）
var route: Control = null        # exit の「とおった みち」
var caption: Label
var _map: BodyMap
var _fx: Control
var _face_box: Control
var _face_mood := ""
var _card: PanelContainer
var _bubble: PanelContainer
var _cap_chip: PanelContainer
var _place_chip: PanelContainer
var _path_in := PackedVector2Array()    # からだの 中（enter：入口 → 場所、exit：場所 → 出口）
var _path_out := PackedVector2Array()   # 外（enter：外 → 入口、exit：出口 → 外）
var _t := 0.0
var _frozen := false
var _times: Array[float] = []           # 区切りの 時刻 [T0, T1, T2, T3]
var _heading := 0.0
var _flip := 1.0
var _sounds: Dictionary = {}


static func say_fits(text: String) -> bool:
	return lines_of(text, SAY_SIZE, SAY_WIDTH) <= SAY_LINES


func setup(e: Dictionary, m: String) -> void:
	ep = e
	mode = m
	j = EpisodeDB.journey(ep, mode)


func _ready() -> void:
	var box := make_stage(Color(0.93, 0.95, 1.0))
	var who: Dictionary = EpisodeDB.speaker(ep["patient"])
	add_heading(("%sの からだに はいるよ！" if mode == "enter" else "%sの からだから でるよ！") % who["name"])
	# 左：からだの地図 ＋ 動き（道・ミクロごう・しかけ）
	_map = BodyMap.new()
	_map.setup(ep["patient"], MAP_SIZE)
	_map.position = MAP_POS
	box.add_child(_map)
	_fx = Control.new()
	_fx.position = MAP_POS
	_fx.size = MAP_SIZE
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	box.add_child(_fx)
	_build_paths()
	_place_chip = _chip(place_name(), 22, Color.WHITE, YELLOW.darkened(0.3))
	box.add_child(_place_chip)
	_cap_chip = _chip("", 24, Color(1, 1, 1, 0.95), Color(0.55, 0.78, 0.95))
	caption = _cap_chip.get_child(0)
	box.add_child(_cap_chip)
	# 右上：だれの からだか（顔・名前・入口／出口）
	_card = PanelContainer.new()
	_card.position = Vector2(PANEL_X, 34)
	_card.size = card_size()
	_card.add_theme_stylebox_override("panel", T.rounded(Color.WHITE, 30, 6, who["color"]))
	box.add_child(_card)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	_card.add_child(hb)
	_face_box = Control.new()
	_face_box.custom_minimum_size = Vector2(face_size(), face_size())
	_face_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_face_box)
	_set_face("sick", false)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	hb.add_child(vb)
	if mode == "enter":
		vb.add_child(T.label("かんじゃさん", 20, (who["color"] as Color).darkened(0.5)))
	vb.add_child(T.label(who["name"], 40 if mode == "enter" else EXIT_NAME, T.INK))
	var way_chip := _chip(("いりぐち： %s" if mode == "enter" else "でぐち： %s") % j["way"].get("name", ""), 24, (who["color"] as Color).lerp(Color.WHITE, 0.6), (who["color"] as Color).darkened(0.2))
	way_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vb.add_child(way_chip)
	# 右なか：ピコの ひとこと（話の enter.say／exit.say）
	if mode == "exit":
		# とおった みち：入口から さいごの 場所まで とおった 場所の ならび（出口の 前に もういちど 見る）
		var rp := PanelContainer.new()
		rp.position = Vector2(PANEL_X, ROUTE_Y)
		rp.size = Vector2(CARD_SIZE.x, 0)
		var rsb := T.rounded(Color.WHITE, 22, 4, YELLOW.darkened(0.2))
		rsb.content_margin_top = 4
		rsb.content_margin_bottom = 4
		rp.add_theme_stylebox_override("panel", rsb)
		box.add_child(rp)
		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", 0)
		rp.add_child(rv)
		rv.add_child(T.label("とおった みち", 18, YELLOW.darkened(0.5)))
		route = RouteLine.new()
		route.setup(EpisodeDB.stops(ep), -1, -1, CARD_SIZE.x - 44.0, true, false)
		rv.add_child(route)
	_bubble = PanelContainer.new()
	_bubble.position = bubble_pos()
	_bubble.size = Vector2(BUBBLE_SIZE.x, 0)
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
	var say := T.body(j["say"], SAY_SIZE)
	say.custom_minimum_size = Vector2(SAY_WIDTH, 0)
	tv.add_child(say)
	# 右下：ボタン（はじめから 押せる。動きの とちゅうでも よい）
	# はじめの 場面が とおりみちなら、まだ しらべない（とおって いく だけ）
	var go_text := ("しゅっぱつ！ ▶" if EpisodeDB.is_pass(ep, 0) else "しらべに いこう！ ▶") if mode == "enter" else "つぎへ ▶"
	button = T.button(go_text, 32)
	button.position = Vector2(810, 548)
	button.size = Vector2(370, 82)
	T.colored_button(button, T.YELLOW, T.YELLOW_DARK)
	button.focus_neighbor_left = NodePath(".")
	button.focus_neighbor_right = NodePath(".")
	button.focus_neighbor_top = NodePath(".")
	button.focus_neighbor_bottom = NodePath(".")
	# 2 つの ボタンの どちらか 1 回だけ（同じ フレームで 両方 押されても あとの ほうは 何も しない）
	button.pressed.connect(func():
		if not locked():
			lock(99.0)
			Sfx.play("click")
			finished.emit())
	box.add_child(button)
	if offers_skip(ep, mode):
		skip_button = T.button("とおりみちを\nとばす", 24)
		skip_button.position = Vector2(PANEL_X, 548)
		skip_button.size = Vector2(195, 82)
		for side in ["left", "top", "bottom"]:
			skip_button.set("focus_neighbor_" + side, NodePath("."))
		skip_button.pressed.connect(func():
			if not locked():
				lock(99.0)
				Sfx.play("click")
				skipped.emit())
		box.add_child(skip_button)
		skip_button.focus_neighbor_right = skip_button.get_path_to(button)
		button.focus_neighbor_left = button.get_path_to(skip_button)
	set_focus(button)
	lock()
	_update(0.0)


## 「とおりみちを とばす」を 出すか：入口の 画面で、クリアずみ（遊びなおし）で、とおりみちが ある 話だけ
static func offers_skip(e: Dictionary, m: String) -> bool:
	return m == "enter" and SaveData.is_cleared(e.get("id", "")) and EpisodeDB.has_pass(e)


func card_size() -> Vector2:
	return CARD_SIZE if mode == "enter" else Vector2(CARD_SIZE.x, EXIT_CARD_H)


func face_size() -> float:
	return 170.0 if mode == "enter" else EXIT_FACE


func bubble_pos() -> Vector2:
	return BUBBLE_POS if mode == "enter" else Vector2(BUBBLE_POS.x, EXIT_BUBBLE_Y)


## 地図の 上の 道（入れ物の 中の 座標）と、区切りの 時刻
func _build_paths() -> void:
	var inside := PackedVector2Array()
	for p in j["inside"]:
		inside.append(_map.to_local_pos(p))
	var out := PackedVector2Array()
	for p in j["out"]:
		out.append(_map.to_local_pos(p))
	if inside.is_empty() and not out.is_empty():
		inside.append(out[0])   # データの まちがい（validate() が 止める）。それでも 画面は 出す
	if out.is_empty():
		out.append(inside[0] if not inside.is_empty() else MAP_SIZE * 0.5)
	if mode == "enter":
		out.reverse()
		_path_out = out
		_path_in = inside
	else:
		inside.reverse()
		_path_in = inside
		_path_out = out
	var travel := maxf(0.9, _length(_path_in) / SPEED)
	if mode == "enter":
		_times = [0.35, 1.25, 2.05, 2.05 + travel]
	else:
		_times = [0.45, 0.45 + travel, 0.45 + travel + 0.8, 0.45 + travel + 1.6]


## 動きが おわる 時刻（その あとは ゆれているだけ）
func rest_time() -> float:
	return _times[3] + 0.3


## 撮影用：動きを frac（0〜1。1 ＝ おわり）の 所で 止める
func freeze_at(frac: float) -> void:
	_frozen = true
	_t = clampf(frac, 0.0, 1.0) * rest_time()
	_update(0.0)


## ミクロごうの 道 全体（外も ふくむ。始まりから おわりまで。テストが 見る）
func path_points() -> PackedVector2Array:
	var p := PackedVector2Array()
	if mode == "enter":
		p.append_array(_path_out)
		p.append_array(_path_in)
	else:
		p.append_array(_path_in)
		p.append_array(_path_out)
	return p


## 場所（enter ＝ さいしょの 場所、exit ＝ さいごの 場所）の 地図の 上の 位置
func place_point() -> Vector2:
	return _path_in[_path_in.size() - 1] if mode == "enter" else _path_in[0]


func place_name() -> String:
	if not StageDB.stage_ids().has(j["place"]):
		return ""
	var s := StageDB.get_stage(j["place"])
	return "%s（%s）" % [s["name"], s["kanji"]]


## 地図の 下の ひとことの 全部（テストが 文の きまりと 長さを 見る）
func captions() -> Array[String]:
	var who: String = EpisodeDB.speaker(ep["patient"])["name"]
	var go: String = j["way"].get("go", "")
	if mode == "enter":
		return ["ちいさく なあれ……", go, "%sへ すすむよ" % place_name(), "%sに とうちゃく！" % place_name()]
	return ["%sから でぐちへ" % place_name(), go, "もとの おおきさに もどるよ", "%s、げんきに なったね！" % who]


func _process(delta: float) -> void:
	super(delta)
	if not _frozen:
		_t += delta
	_update(delta)


## 時刻 _t に 合わせて ひとこと・顔・音を 変える（えがくのは _draw_fx）
func _update(_delta: float) -> void:
	# ひとこと：T1 まで 0、T2 まで 1、T3 まで 2、その あと 3
	var idx := 0
	while idx < 3 and _t >= _times[idx + 1]:
		idx += 1
	var cap: String = captions()[idx]
	if caption.text != T.nobreak(cap):
		caption.text = T.nobreak(cap)
		_cap_chip.size = Vector2.ZERO
		_cap_chip.position = Vector2(MAP_POS.x + (MAP_SIZE.x - _cap_chip.get_combined_minimum_size().x) * 0.5, MAP_POS.y + MAP_SIZE.y + 4)
	_place_chip.size = Vector2.ZERO
	var pp := place_point() + MAP_POS
	var cs := _place_chip.get_combined_minimum_size()
	var right := pp.x + 26 + cs.x <= MAP_POS.x + MAP_SIZE.x
	_place_chip.position = Vector2(pp.x + 26 if right else pp.x - 26 - cs.x, pp.y - cs.y * 0.5)
	# 音と 顔（1 回だけ）
	if mode == "enter":
		_sound_once("pop", 0.05)
		_sound_once("heal", _times[0])
		_sound_once("pop", _times[1] + 0.4, "pop2")
		_sound_once("goal_open", _times[3])
	else:
		_sound_once("pop", 0.05)
		_sound_once("pop", _times[2] - 0.3, "pop2")
		_sound_once("cheer", _times[2])
		if _t >= _times[2] and _face_mood != "happy":
			_set_face("happy", not _frozen)
	_fx.queue_redraw()


func _sound_once(name: String, at: float, key := "") -> void:
	var k := key if key != "" else name
	if _t >= at and not _sounds.has(k):
		_sounds[k] = true
		if not _frozen:
			Sfx.play(name)


## 患者の 顔（"sick"／"happy"）。bounce なら ぽよんと
func _set_face(mood: String, bounce: bool) -> void:
	_face_mood = mood
	for c in _face_box.get_children():
		c.queue_free()
	var col: Color = EpisodeDB.speaker(ep["patient"])["color"]
	var fs := face_size()
	var back := Panel.new()
	back.size = Vector2(fs, fs)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", T.rounded(col.lerp(Color.WHITE, 0.55), int(fs * 0.5), 4, Color.WHITE))
	_face_box.add_child(back)
	var f := T.portrait(ep["patient"], mood, Vector2(fs, fs), col)
	_face_box.add_child(f)
	if bounce:
		_face_box.pivot_offset = Vector2(fs, fs) * 0.5
		_face_box.scale = Vector2(0.75, 0.75)
		create_tween().tween_property(_face_box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 小さい ふだ（文 ＋ 色つきの わく）
func _chip(text: String, font_size: int, bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := T.rounded(bg, 18, 3, border)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(T.label(text, font_size, T.INK))
	return p


# ---------------------------------------------------------------- えがく
static func _length(p: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, p.size()):
		l += p[i - 1].distance_to(p[i])
	return l


## 道の 上の 位置（f ＝ 0〜1。長さで わる）
static func _at(p: PackedVector2Array, f: float) -> Vector2:
	if p.size() == 1:
		return p[0]
	var want := _length(p) * clampf(f, 0.0, 1.0)
	for i in range(1, p.size()):
		var d := p[i - 1].distance_to(p[i])
		if want <= d or i == p.size() - 1:
			return p[i - 1].lerp(p[i], clampf(want / maxf(d, 0.001), 0.0, 1.0))
		want -= d
	return p[p.size() - 1]


## 道の 始まりから f までの 部分
static func _part(p: PackedVector2Array, f: float) -> PackedVector2Array:
	var out := PackedVector2Array([p[0]])
	var want := _length(p) * clampf(f, 0.0, 1.0)
	for i in range(1, p.size()):
		var d := p[i - 1].distance_to(p[i])
		if want <= d:
			out.append(p[i - 1].lerp(p[i], want / maxf(d, 0.001)))
			return out
		want -= d
		out.append(p[i])
	return out


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## いまの ミクロごうの 位置と 大きさ
func _ship() -> Array:
	var T0: float = _times[0]
	var T1: float = _times[1]
	var T2: float = _times[2]
	var T3: float = _times[3]
	var pos: Vector2
	var k: float
	if mode == "enter":
		if _t < T1:
			pos = _path_out[0]
			k = BIG * lerpf(0.6, 1.0, _ease(_t / T0)) if _t < T0 else lerpf(BIG, SMALL, _ease((_t - T0) / (T1 - T0)))
		elif _t < T2:
			pos = _at(_path_out, _ease((_t - T1) / (T2 - T1)))
			k = SMALL
		else:
			pos = _at(_path_in, _ease((_t - T2) / (T3 - T2)))
			k = SMALL
	else:
		if _t < T1:
			pos = _at(_path_in, _ease((_t - T0) / (T1 - T0)) if _t > T0 else 0.0)
			k = SMALL * lerpf(0.6, 1.0, _ease(_t / T0)) if _t < T0 else SMALL
		elif _t < T2:
			pos = _at(_path_out, _ease((_t - T1) / (T2 - T1)))
			k = SMALL
		else:
			pos = _path_out[_path_out.size() - 1]
			k = lerpf(SMALL, BIG, _ease((_t - T2) / (T3 - T2)))
	# とまって いる ときは ふわふわ
	var moving := (mode == "enter" and _t >= T1 and _t < T3) or (mode == "exit" and _t >= T0 and _t < T2)
	if not moving:
		pos.y += sin(_t * 3.0) * 3.0 * k
	return [pos, k, moving]


func _draw_fx() -> void:
	var T1: float = _times[1]
	var T2: float = _times[2]
	var T3: float = _times[3]
	var dark := Color(0.35, 0.25, 0.3)
	# 道：これから 行く 道（点線）と、とおった 道（きいろ）
	if _path_in.size() >= 2:
		var whole := _path_in
		_dotted(whole, Color(1, 1, 1, 0.95), dark)
		var f := 0.0
		if mode == "enter":
			f = clampf((_t - T2) / (T3 - T2), 0.0, 1.0)
		else:
			f = clampf((_t - _times[0]) / (T1 - _times[0]), 0.0, 1.0)
		f = _ease(f)
		if f > 0.0:
			var part := _part(whole, f)
			if part.size() >= 2:
				_fx.draw_polyline(part, dark, 13, true)
				_fx.draw_polyline(part, YELLOW, 8, true)
	# 場所の しるし（enter は とうちゃくで ひかる。exit は 始まりの 所）
	var pp := place_point()
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var lit := (mode == "enter" and _t >= T3) or (mode == "exit" and _t < T1)
	_fx.draw_arc(pp, 22.0 + (6.0 * pulse if lit else 0.0), 0, TAU, 40, dark, 7, true)
	_fx.draw_arc(pp, 22.0 + (6.0 * pulse if lit else 0.0), 0, TAU, 40, YELLOW if lit else Color(1, 1, 1, 0.9), 4, true)
	# 出入りの しかけ
	var at := _path_out[_path_out.size() - 1] if mode == "enter" else _path_out[0]
	var fx_t := (_t - (T1 - 0.1)) / (T2 - T1 + 0.6) if mode == "enter" else (_t - (T1 - 0.2)) / (T2 - T1 + 0.8)
	if fx_t > 0.0 and fx_t < 1.0:
		_draw_way_fx(String(j["way"].get("fx", "")), at, fx_t)
	# ミクロごう
	var s := _ship()
	var pos: Vector2 = s[0]
	var k: float = s[1]
	# 向き：すすむ 向きへ（右へ 行く ときと 左へ 行く ときで うらがえす）
	var ahead: Vector2 = _ship_dir() if s[2] else Vector2.ZERO
	if ahead.length() > 0.01:
		if absf(ahead.x) > 0.15:
			_flip = 1.0 if ahead.x > 0.0 else -1.0
		var target := clampf(atan2(ahead.y, absf(ahead.x)), -1.2, 1.2) * _flip
		_heading = lerp_angle(_heading, target, 0.25)
	else:
		_heading = lerp_angle(_heading, 0.0, 0.12)
	# ちいさく なる／もどる ときの きらきら
	var spark_t := -1.0
	if mode == "enter" and _t > _times[0] and _t < T1 + 0.2:
		spark_t = (_t - _times[0]) / (T1 + 0.2 - _times[0])
	if mode == "exit" and _t > T2 and _t < T3 + 0.3:
		spark_t = (_t - T2) / (T3 + 0.3 - T2)
	if spark_t >= 0.0:
		for i in 8:
			var a := TAU * i / 8.0 + spark_t * 1.5
			var r := 30.0 + 55.0 * spark_t
			_star(pos + Vector2(cos(a), sin(a)) * r, 9.0 * (1.0 - spark_t * 0.6), Color(1.0, 0.9, 0.4, 1.0 - spark_t * 0.7))
	if k > 0.02:
		if k < SMALL + 0.2:   # からだの 中では 白い 光の 輪で 目立たせる
			_fx.draw_circle(pos, 30.0 * k / SMALL, Color(1, 1, 1, 0.55))
		draw_ship(_fx, pos, k, _heading, _flip, _t)


## いまの すすむ 向き（少し 先の 位置との ちがい）
func _ship_dir() -> Vector2:
	var keep := _t
	var now: Vector2 = _ship()[0]
	_t = keep + 0.05
	var later: Vector2 = _ship()[0]
	_t = keep
	return later - now


func _dotted(p: PackedVector2Array, col: Color, edge: Color) -> void:
	var total := _length(p)
	var d := 0.0
	while d <= total:
		var q := _at(p, d / maxf(total, 0.001))
		_fx.draw_circle(q, 5.5, edge)
		_fx.draw_circle(q, 3.5, col)
		d += 16.0


func _star(c: Vector2, r: float, col: Color) -> void:
	_fx.draw_colored_polygon(T.star_points(c, r, 0.42), col)


## 入口・出口の しかけ（t ＝ 0〜1）
func _draw_way_fx(kind: String, at: Vector2, t: float) -> void:
	var water := Color(0.45, 0.75, 1.0, 0.9)
	var fade := 1.0 - _ease((t - 0.7) / 0.3)
	match kind:
		"water":
			# おみずの つぶが 上から くちへ
			for i in 7:
				var s := fmod(t * 2.2 + i * 0.14, 1.0)
				var from := at + Vector2(46 + (i % 3) * 14, -70 - (i % 2) * 20)
				var q := from.lerp(at, s)
				_drop(q, 7.0 * (1.0 - s * 0.4), Color(water, water.a * fade))
		"open":
			var o := sin(clampf(t, 0.0, 1.0) * PI)
			_fx.draw_set_transform(at, 0.0, Vector2(1.0, 0.75))
			_fx.draw_circle(Vector2.ZERO, 30.0 * o, Color(0.55, 0.18, 0.25, 0.9))
			_fx.draw_circle(Vector2(0, 10) * o, 14.0 * o, Color(0.95, 0.5, 0.55, 0.9))
			_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"breath":
			for i in 3:
				var s := fmod(t * 1.6 + i * 0.33, 1.0)
				var c := at + Vector2(70, -26).lerp(Vector2.ZERO, s) + Vector2(0, (i - 1) * 12)
				_fx.draw_arc(c, 14.0, -1.2, 1.2, 12, Color(0.6, 0.8, 1.0, 0.8 * fade), 4, true)
		"spray":
			for i in 10:
				var a := -0.9 + i * 0.16
				var r := 20.0 + 120.0 * t
				var q := at + Vector2(cos(a), sin(a)) * r + Vector2(0, 40.0 * t * t)
				_drop(q, 6.0, Color(water, water.a * fade))
		"puff":
			for i in 5:
				var a := -0.5 + i * 0.25
				var r := 16.0 + 70.0 * t
				_fx.draw_circle(at + Vector2(cos(a), sin(a)) * r * 0.9 + Vector2(10, 0), 16.0 + 14.0 * t, Color(0.92, 0.95, 1.0, 0.85 * fade))
		"drop":
			var q := at + Vector2(0, 60.0 * _ease(t * 1.4))
			_fx.draw_circle(q, 13.0, Color(0.55, 0.36, 0.22, 0.95 * fade))
			_fx.draw_circle(q + Vector2(-4, -6), 7.0, Color(0.68, 0.48, 0.3, 0.95 * fade))
			if t > 0.6:
				_fx.draw_arc(at + Vector2(0, 66), 10.0 + 40.0 * (t - 0.6), 0, TAU, 24, Color(0.55, 0.36, 0.22, 0.7 * fade), 3, true)
		"spark":
			for i in 6:
				var a := TAU * i / 6.0 + t * 2.0
				_star(at + Vector2(cos(a), sin(a)) * (14.0 + 30.0 * t), 8.0, Color(1.0, 0.9, 0.4, fade))


func _drop(c: Vector2, r: float, col: Color) -> void:
	_fx.draw_circle(c, r, col)
	_fx.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.4), c + Vector2(0, -r * 2.0), c + Vector2(r * 0.8, -r * 0.4)]), col)


## ミクロごう（横から 見た 形）：k ＝ 大きさ、angle ＝ 向き、flip ＝ 左むきなら -1。t は プロペラの 回転
static func draw_ship(ci: CanvasItem, pos: Vector2, k: float, angle: float, flip: float, t: float) -> void:
	var hull := Color("#F3EBE1")
	var yel := Color("#FCC738")
	var line := Color(0.33, 0.3, 0.32)
	var glass := Color("#B8E2EA")
	ci.draw_set_transform(pos, angle, Vector2(k * flip, k))
	var w := 3.0
	# プロペラ（うしろ）
	var spin := absf(sin(t * 18.0))
	ci.draw_line(Vector2(-34, 0), Vector2(-44, 0), line, 4)
	ci.draw_set_transform(pos + Vector2(-46 * k * flip, 0).rotated(angle), angle, Vector2(k * flip, k))
	_oval(ci, Vector2.ZERO, 5.0, 16.0 * spin + 3.0, yel, line, w)
	ci.draw_set_transform(pos, angle, Vector2(k * flip, k))
	# ひれ
	for sy in [-1.0, 1.0]:
		var fin := PackedVector2Array([Vector2(-22, sy * 14), Vector2(-38, sy * 26), Vector2(-30, sy * 6)])
		ci.draw_colored_polygon(fin, yel)
		fin.append(fin[0])
		ci.draw_polyline(fin, line, w, true)
	# 船体
	_oval(ci, Vector2.ZERO, 36.0, 24.0, hull, line, w)
	ci.draw_line(Vector2(-30, 8), Vector2(30, 8), yel, 6)
	ci.draw_circle(Vector2(-14, 1), 5.5, Color("#85B6D5"))
	ci.draw_arc(Vector2(-14, 1), 5.5, 0, TAU, 16, line, 2, true)
	ci.draw_circle(Vector2(34, 2), 4.0, Color(1.0, 0.95, 0.6))
	# まるい ドームと パイロット
	ci.draw_circle(Vector2(6, -14), 15.0, Color(glass, 0.95))
	ci.draw_circle(Vector2(6, -13), 7.5, Color("#FCC294"))
	ci.draw_arc(Vector2(6, -14), 8.0, PI + 0.2, TAU - 0.2, 10, Color("#894927"), 5, true)
	ci.draw_line(Vector2(1, -16), Vector2(12, -16), Color("#44BED0"), 3)
	ci.draw_arc(Vector2(6, -14), 15.0, PI + 0.05, TAU - 0.05, 20, line, w, true)
	ci.draw_arc(Vector2(10, -20), 6.0, PI + 0.6, PI * 1.5, 8, Color(1, 1, 1, 0.9), 2, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _oval(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, line: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, line, w, true)


## はみ出しの 説明（無ければ ""）：ふきだし・名前の ふだが 箱に 入り、ボタンと 重ならないか、道が 地図の 中か
func overflow() -> String:
	var bh := _bubble.get_combined_minimum_size().y
	if bubble_pos().y + bh > button.position.y - 8.0:
		return "ふきだしが 高い（%.0f px）" % bh
	var ch := _card.get_combined_minimum_size()
	if ch.y > card_size().y or ch.x > card_size().x:
		return "患者の ふだが 大きい（%s）" % ch
	if route != null:
		var rp: Control = route.get_parent().get_parent()
		if ROUTE_Y + rp.get_combined_minimum_size().y > bubble_pos().y - 6.0 or 34.0 + card_size().y > ROUTE_Y - 4.0:
			return "とおった みちが ふだか ふきだしに かかる（%.0f px）" % rp.get_combined_minimum_size().y
		if not route.fits():
			return "とおった みちの 名前が 入らない"
	var area := Rect2(Vector2.ZERO, MAP_SIZE).grow(-10.0)
	for p in path_points():
		if not area.has_point(p):
			return "道の 点 %s が 地図の 外" % p
	for c in captions():
		if lines_of(c, 24, MAP_SIZE.x - 40.0) > 1:
			return "地図の 下の ひとことが 長い：%s" % c
	return ""


func fits() -> bool:
	return overflow() == ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()   # もどる 先は 無い（からだの 中へ 行く／出る しかない）
