extends Control
## ものしりカード（1 枚を 大きく）。「わかった！」で閉じる。ずかんと「みつけた ものしりカード」の 画面から 開く。
## ゲームの とちゅう（Level が 動いて いる あいだ）には 出さない（みつけた ことは HUD の 小さい しらせ。docs/episodes.md）。
## card に "karte"（話の id）が あれば、ずかんの カルテ：絵の 列の かわりに カルテの 紙（karte_sheet.gd）を 出す。

signal closed

const T := preload("res://src/ui/ui_theme.gd")
const Sheet := preload("res://src/ui/karte_sheet.gd")

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
	_panel.offset_left = -440
	_panel.offset_right = 440
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
		pic = picture(image_kind, sid, Vector2(260, 300))
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
## 無ければ キャラクターの 3D（まわる）。カード・ゲーム中の 小さい しらせ・みつけた カードの 画面で 使う
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
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sv := SubViewport.new()
	sv.transparent_bg = true
	# 大きさは 書かない：stretch が 入れものの 大きさに 合わせる（stretch の 下で 書くと Godot が 警告を 出して 書きかえない）。
	# 入れもの（box）には 上で 大きさを もたせて あるので、0×0 の 絵（ブラウザ版の「Could not create render target」）に ならない
	sv.own_world_3d = true
	svc.add_child(sv)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.8, -4.0)
	cam.look_at_from_position(cam.position, Vector3(0, 0.3, 0), Vector3.UP)
	cam.fov = 40
	sv.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 35, 0)
	sv.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 0.95)
	e.ambient_light_energy = 1.0
	env.environment = e
	sv.add_child(env)
	var pivot := Node3D.new()
	ModelLib.fit(model, 0.95)
	# 回る 軸（原点）から いちばん 遠い 所で 合わせなおす（むしばきんの ドリルのように 片がわだけ 出る 形が、
	# 回った ときに わくから はみ出ない ように）。左右前後が そろった 形は 変わらない
	var bb := ModelLib._aabb(model)
	var reach := maxf(maxf(-bb.position.x, bb.end.x), maxf(-bb.position.z, bb.end.z))
	var half := maxf(bb.size.x, maxf(bb.size.y, bb.size.z)) * 0.5
	if reach > half:
		model.scale *= half / reach
	# 上下は 形の まん中を わくの まん中に（原点が ゆかの 近くや 上に ある モデル（かべの さいぼう）でも 切れない）
	model.position.y = -(bb.position.y + bb.size.y * 0.5) * model.scale.y
	pivot.add_child(model)
	pivot.rotation.y = -0.5
	sv.add_child(pivot)
	box.add_child(svc)
	if spin:
		box.ready.connect(func():
			var tw := box.create_tween().set_loops()
			tw.tween_property(pivot, "rotation:y", TAU, 6.0).from(0.0))
	return box


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
