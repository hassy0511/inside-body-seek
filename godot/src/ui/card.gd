extends Control
## ものしりカード（1 枚を 大きく）。「わかった！」で閉じる。ずかんと「みつけた ものしりカード」の 画面から 開く。
## ゲームの とちゅう（Level が 動いて いる あいだ）には 出さない（みつけた ことは HUD の 小さい しらせ。docs/episodes.md）。
## card に "karte"（話の id）が あれば、ずかんの カルテ：絵の 列の かわりに カルテの 紙（karte_sheet.gd）を 出す。

signal closed

const T := preload("res://src/ui/ui_theme.gd")
const Sheet := preload("res://src/ui/karte_sheet.gd")

## 3D の 絵：止まった 絵（タイル）は ななめ前（顔が 見える 3/4）。カードと しらせは ±SWAY_DEG の あいだを ゆっくり ゆれる
## （0 ＝ 顔が まっすぐ こちら。＋ は 顔が 絵の 右へ むく）。SWAY_SEC で 1 往復
const STILL_DEG := 35.0
const SWAY_DEG := 50.0
const SWAY_SEC := 8.0
## カードの 左の 絵の わく。文の 列の 幅（548）は 変えずに、カードを 880 → 940 に 広げて 絵に 回した
## （絵を はかった 大きさの まま 出す ように したら、よこ 260 では 前より 小さく 見えた）。納品の 挿絵（約 256×300）も 比を 保って この わくに 入る
const PIC_SIZE := Vector2(320, 400)
const PIC_CAM := Vector3(0, 0.75, -4.2)
const PIC_FOV := 40.0
## 形の はこの かどが わくの はし から この わりあい（まん中 0、はし 1）より 内がわ
const PIC_MARGIN := 0.94
## 3D の 絵の 光の 強さ（add_picture_light）
const PIC_SUN := 0.36
const PIC_SUN_DEG := Vector3(-40, 145, 0)
const PIC_AMBIENT := 0.73
const PIC_AMBIENT_COLOR := Color(1, 1, 1)

var _panel: PanelContainer
var _btn: Button
var _done := false
var _opened_ms := 0


func _ready() -> void:
	_opened_ms = Time.get_ticks_msec()
	if _btn:
		_btn.grab_focus()
		# 連打で読まずに閉じてしまわないように、少しの間は押せない
		_btn.disabled = true
		get_tree().create_timer(0.7, true).timeout.connect(func():
			if is_instance_valid(_btn):
				_btn.disabled = false
				_btn.grab_focus())


## card は {"title", "text"}（＋ 任意の "tag"：上の 小さい 見出し。無ければ「ものしりカード」）。
## image_kind はカードのキー（"stage"、"mushiba" など）。stage_id を渡すと、納品された挿絵
## res://assets/ui/cards/card_<stage_id>_<image_kind>.png があれば 3D のプレビューの代わりに出す。
func setup(card: Dictionary, image_kind := "", stage_id := "") -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.1, 0.15, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -470
	_panel.offset_right = 470
	_panel.offset_top = -230
	_panel.offset_bottom = 230
	_panel.add_theme_stylebox_override("panel", T.rounded(T.CREAM, 30, 6, T.YELLOW))
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	margin.add_child(hb)

	# ずかんの カルテ：絵の 列を 出さず、カルテの 紙を 入れる（背が 高いので 枠も 広げる）
	var is_karte: bool = card.has("karte")
	if is_karte:
		_panel.offset_left = -470
		_panel.offset_right = 470
		_panel.offset_top = -320
		_panel.offset_bottom = 320
	var sid := stage_id if stage_id != "" else Game.current_stage_id
	var pic: Control = null
	if not is_karte:
		pic = picture(image_kind, sid, PIC_SIZE)
	if pic:
		hb.add_child(pic)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	hb.add_child(vb)
	var tag := T.label(card.get("tag", "ものしりカード"), 18, Color(0.75, 0.5, 0.2))
	var title_text: String = card.get("title", "")
	var title := T.body(title_text, 40 if title_text.length() <= 11 else 32, T.INK, false)
	if is_karte:
		# カルテの あたま：左に 番号と だいめい、右に 患者の 名前と げんきに なった 顔
		var ep := EpisodeDB.get_episode(card["karte"])
		var who: Dictionary = EpisodeDB.speaker(ep["patient"])
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_theme_constant_override("separation", 0)
		tv.add_child(tag)
		tv.add_child(title)
		top.add_child(tv)
		var who_name := T.label(who["name"], 20, (who["color"] as Color).darkened(0.45))
		who_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(who_name)
		var face := T.portrait(ep["patient"], "happy", Vector2(64, 64), who["color"])
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(face)
		vb.add_child(top)
		var sheet := Sheet.build(ep)
		sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(sheet)
	else:
		vb.add_child(tag)
		vb.add_child(title)
		var body := T.body(card.get("text", ""), 25)
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(body)
	_btn = T.button("わかった！", 30, 240)
	_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_btn.pressed.connect(close)
	# 矢印で 下の 画面（ずかん・みつけた カード）の ボタンへ フォーカスが 出て いかない ように
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_btn.set_focus_neighbor(side, NodePath("."))
	_btn.focus_next = NodePath(".")
	_btn.focus_previous = NodePath(".")
	vb.add_child(_btn)

	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.7, 0.7)
	var t := create_tween()
	t.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## カードの 絵：納品された 挿絵（res://assets/ui/cards/card_<stage_id>_<kind>.png）が あれば それ、
## 無ければ キャラクターの 3D（spin：顔を こちらに むけた まま ゆれる。false は ななめ前で 止まる）。カード・ゲーム中の 小さい しらせ・みつけた カードの 画面で 使う
static func picture(kind: String, stage_id: String, size: Vector2, spin := true) -> Control:
	var art: Control = T.art_rect("cards/card_%s_%s" % [stage_id, kind], size) if stage_id != "" else null
	if art != null:
		return art
	return _model_picture(kind, size, spin)


static func _model_picture(kind: String, size: Vector2, spin: bool) -> Control:
	var box := Control.new()
	box.custom_minimum_size = size
	box.size = size   # ならべる 前から 大きさを もたせる（下の SubViewport が 0×0 に ならない）
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var model_name := kind
	if kind == "stage" or kind == "goal" or kind == "":
		model_name = "pico"
	if kind == "nutrient":
		model_name = "nutrient_a"
	var model := ModelLib.instance("characters/" + model_name)
	if model == null and ModelLib.PLACEHOLDER_COLORS.has(model_name):
		model = ModelLib.placeholder(model_name, 0.7)
	if model == null:
		var r := minf(size.x, size.y) * 0.3
		box.draw.connect(func():
			var c := box.size * 0.5
			box.draw_circle(c, r, T.PINK_LIGHT)
			box.draw_circle(c, r * 0.8, T.PINK))
		return box
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 絵は いつも size ぴったり（入れもの box の まん中）。ならべる 側が box を のばしても 絵の 大きさは 変えない：
	# カードの 中では box が たてに のびる（はじめは 260×300 の 絵が 260×404 に のびて いた）。それに 合わせて 絵まで のばすと、たての 画角は 同じ なので
	# 中身が 1.4 倍に 大きく なって、よこが わくで 切れた（ピロリきんの しょく手と 顔）。picture_fit() は size で はかって いる
	svc.anchor_left = 0.5
	svc.anchor_right = 0.5
	svc.anchor_top = 0.5
	svc.anchor_bottom = 0.5
	svc.offset_left = -size.x * 0.5
	svc.offset_right = size.x * 0.5
	svc.offset_top = -size.y * 0.5
	svc.offset_bottom = size.y * 0.5
	box.set_meta("pic_size", size)
	var sv := SubViewport.new()
	sv.transparent_bg = true
	# SubViewport の 大きさは 書かない：stretch が svc の 大きさ（上で 決めた size）に 合わせる（stretch の 下で 書くと Godot が 警告を 出す）。
	# svc は 作った ときから size なので、0×0 や 大きすぎる 絵（ブラウザ版の「Could not create render target」）に ならない
	sv.own_world_3d = true
	svc.add_child(sv)
	var cam := Camera3D.new()
	cam.position = PIC_CAM
	cam.look_at_from_position(cam.position, Vector3.ZERO, Vector3.UP)
	cam.fov = PIC_FOV
	sv.add_child(cam)
	add_picture_light(sv)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	ModelLib.fit(model, 0.95)
	# 形の まん中（はこの 中心）を まわる 軸に おく（原点が ゆかの 近くに ある かべの さいぼうや、
	# 片がわだけ 出る むしばきんの ドリルでも、ゆれる あいだ わくの まん中に いる）
	var bb := ModelLib._aabb(model)
	model.position = -bb.get_center() * model.scale
	# ゆれの はしから はしまで どの 角度でも、形の はこの 8 つの かど が わくの 内がわに 入る 大きさに する
	model.scale *= picture_fit(bb.size * model.scale, size)
	model.position = -bb.get_center() * model.scale
	pivot.add_child(model)
	pivot.rotation.y = deg_to_rad(STILL_DEG)
	sv.add_child(pivot)
	box.add_child(svc)
	if spin:
		# ぐるっと まわすと うしろ（顔の ない がわ）が 出る。顔を こちらに むけた まま、ななめ前の 左右へ ゆっくり ゆらす
		box.ready.connect(func():
			var tw := box.create_tween().set_loops()
			tw.tween_property(pivot, "rotation:y", deg_to_rad(SWAY_DEG), SWAY_SEC * (SWAY_DEG - STILL_DEG) / (4.0 * SWAY_DEG)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(pivot, "rotation:y", deg_to_rad(-SWAY_DEG), SWAY_SEC * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(pivot, "rotation:y", deg_to_rad(STILL_DEG), SWAY_SEC * (SWAY_DEG + STILL_DEG) / (4.0 * SWAY_DEG)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN))
	return box


## 3D の 絵の 光（カード・しらせ・タイル・ずかんで 共通。どの モデルも これ 1 つ）。
## 光の 当たる がわで 色が その ものの 色（albedo）の 約 1.0 倍に なる ように 合わせて ある
## （前は 0.85 倍で、かべの さいぼうが 絵より 暗い カラメル色に 見えた。はかりかたは docs/art_orders/W2_02_wallcell_3D化の結果.md）
static func add_picture_light(sv: Node) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = PIC_SUN_DEG
	light.light_energy = PIC_SUN
	sv.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = PIC_AMBIENT_COLOR
	e.ambient_light_energy = PIC_AMBIENT
	env.environment = e
	sv.add_child(env)


## 形の はこ（大きさ box_size、中心が まわる 軸の 上）を ゆれの どの 角度でも わくに 入れる ための 倍率
## （1.15 より 大きく は しない。小さい ものを むやみに 大きく しない）。カメラは PIC_CAM から 原点を 見る
static func picture_fit(box_size: Vector3, size: Vector2) -> float:
	var cam := Transform3D.IDENTITY.looking_at(-PIC_CAM, Vector3.UP)
	cam.origin = PIC_CAM
	var inv := cam.affine_inverse()
	var ty := tan(deg_to_rad(PIC_FOV) * 0.5)
	var tx := ty * size.x / maxf(size.y, 1.0)
	var k := 1.15
	for it in 6:
		var worst := 0.0
		var deg := -SWAY_DEG
		while deg <= SWAY_DEG + 0.01:
			var rot := Basis(Vector3.UP, deg_to_rad(deg))
			for i in 8:
				var c := Vector3(box_size.x * (0.5 if i & 1 else -0.5), box_size.y * (0.5 if i & 2 else -0.5), box_size.z * (0.5 if i & 4 else -0.5))
				var v := inv * (rot * (c * k))
				var depth := maxf(-v.z, 0.05)
				worst = maxf(worst, maxf(absf(v.x) / (depth * tx), absf(v.y) / (depth * ty)))
			deg += 5.0
		if worst <= PIC_MARGIN + 0.001:
			if it == 0:
				return k
			break
		k *= PIC_MARGIN / worst * 0.995
	return k


func _unhandled_input(event: InputEvent) -> void:
	if Time.get_ticks_msec() - _opened_ms < 700:
		return
	if event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		close()
		get_viewport().set_input_as_handled()


## パネルの 高さ（テストが はみ出しを 見る）
func panel_height() -> float:
	return maxf(_panel.size.y, _panel.get_combined_minimum_size().y)


## 「わかった！」の ボタン（テストが 押す）
func button() -> Button:
	return _btn


func close() -> void:
	if _done:
		return
	_done = true
	Sfx.play("click")
	var t := create_tween()
	t.tween_property(_panel, "scale", Vector2(0.8, 0.8), 0.12)
	t.tween_callback(func():
		closed.emit()
		queue_free())
