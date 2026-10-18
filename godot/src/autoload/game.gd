extends Node
## ゲーム全体の進行（タイトル → ステージえらび → ステージ → けっか）。
## 画面は src/ui/ の Control をコードで組み立てて UILayer に置く。

signal stage_started(stage_id: String)
signal stage_finished(stage_id: String, stars: int)

const UiThemeBuilder := preload("res://src/ui/ui_theme.gd")
const TitleScreen := preload("res://src/ui/title.gd")
const StageSelectScreen := preload("res://src/ui/stage_select.gd")
const ResultScreen := preload("res://src/ui/result.gd")
const ZukanScreen := preload("res://src/ui/zukan.gd")
const CardPopup := preload("res://src/ui/card.gd")
const PauseMenu := preload("res://src/ui/pause.gd")
const HudScene := preload("res://src/ui/hud.gd")
const TouchControlsScene := preload("res://src/ui/touch_controls.gd")
const LevelScene := preload("res://src/level/level.tscn")

var main: Node = null
var world: Node3D = null
var ui_layer: CanvasLayer = null
var overlay_layer: CanvasLayer = null

var theme: Theme
var font_regular: Font
var font_bold: Font

var current_stage_id := ""
var level: Node = null
var hud: Control = null
var touch_controls: Control = null
var _screen: Control = null
var _popup_open := false

## 自動テスト用：true のとき カードやメッセージの待ちを短くする
var testing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	font_regular = load("res://assets/fonts/MPLUSRounded1c-Regular.ttf")
	font_bold = load("res://assets/fonts/MPLUSRounded1c-Bold.ttf")
	theme = UiThemeBuilder.build(font_bold, font_regular)
	get_window().theme = theme


# ---------------------------------------------------------------- 入力
func _setup_input() -> void:
	_add_action("move_left", [_key(KEY_LEFT), _key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0), _jbtn(JOY_BUTTON_DPAD_LEFT)])
	_add_action("move_right", [_key(KEY_RIGHT), _key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0), _jbtn(JOY_BUTTON_DPAD_RIGHT)])
	_add_action("move_up", [_key(KEY_UP), _key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0), _jbtn(JOY_BUTTON_DPAD_UP)])
	_add_action("move_down", [_key(KEY_DOWN), _key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0), _jbtn(JOY_BUTTON_DPAD_DOWN)])
	_add_action("action", [_key(KEY_SPACE), _key(KEY_Z), _key(KEY_ENTER), _key(KEY_KP_ENTER), _jbtn(JOY_BUTTON_A)])
	_add_action("dash", [_key(KEY_SHIFT), _key(KEY_X), _jbtn(JOY_BUTTON_B), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_add_action("pause", [_key(KEY_ESCAPE), _key(KEY_P), _jbtn(JOY_BUTTON_START)])


func _add_action(name: String, events: Array, deadzone := 0.3) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, deadzone)
	for e in events:
		InputMap.action_add_event(name, e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _jbtn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e


# ---------------------------------------------------------------- 画面
func register_main(m: Node) -> void:
	main = m
	world = m.get_node("World")
	ui_layer = m.get_node("UILayer")
	overlay_layer = m.get_node("OverlayLayer")


func _clear_screen() -> void:
	if _screen and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


func _set_screen(c: Control) -> void:
	_clear_screen()
	_screen = c
	c.theme = theme
	ui_layer.add_child(c)


## CanvasLayer の下に置く Control にはテーマが引き継がれないので、ここで付けてから足す
func add_overlay(c: Control) -> void:
	c.theme = theme
	overlay_layer.add_child(c)


func show_title() -> void:
	unload_level()
	Sfx.play_bgm("bgm_title")
	_set_screen(TitleScreen.new())


func show_stage_select() -> void:
	unload_level()
	Sfx.play_bgm("bgm_title")
	_set_screen(StageSelectScreen.new())


func show_zukan() -> void:
	_set_screen(ZukanScreen.new())


func start_stage(stage_id: String) -> void:
	unload_level()
	_clear_screen()
	current_stage_id = stage_id
	var stage := StageDB.get_stage(stage_id)
	level = LevelScene.instantiate()
	level.setup(stage)
	world.add_child(level)
	hud = HudScene.new()
	hud.theme = theme
	ui_layer.add_child(hud)
	hud.bind_level(level)
	_ensure_touch_controls()
	Sfx.play_bgm("bgm_boss" if stage["difficulty"] >= 3 else "bgm_stage")
	stage_started.emit(stage_id)
	level.cleared.connect(_on_level_cleared)
	level.begin()


func unload_level() -> void:
	if level and is_instance_valid(level):
		level.queue_free()
	level = null
	if hud and is_instance_valid(hud):
		hud.queue_free()
	hud = null
	if touch_controls and is_instance_valid(touch_controls):
		touch_controls.visible = false
	get_tree().paused = false


func _ensure_touch_controls() -> void:
	if touch_controls == null or not is_instance_valid(touch_controls):
		touch_controls = TouchControlsScene.new()
		add_overlay(touch_controls)
	touch_controls.visible = touch_controls.should_show()


func retry_stage() -> void:
	var id := current_stage_id
	start_stage(id)


func _on_level_cleared(stage_id: String, no_damage: bool) -> void:
	var stage := StageDB.get_stage(stage_id)
	var r := ResultScreen.new()
	r.setup(stage, no_damage)
	if touch_controls:
		touch_controls.visible = false
	_set_screen(r)
	r.finished.connect(func(stars: int, go_next: bool):
		SaveData.record_clear(stage_id, stars)
		stage_finished.emit(stage_id, stars)
		var next := StageDB.next_stage_id(stage_id)
		if go_next and next != "":
			start_stage(next)
		elif go_next and next == "":
			show_ending()
		else:
			show_stage_select()
	)


func show_ending() -> void:
	unload_level()
	var t := TitleScreen.new()
	t.ending_mode = true
	_set_screen(t)


# ---------------------------------------------------------------- ポップアップ
## ものしりカードを出す（ゲームは一時停止）。閉じたら on_close を呼ぶ。
func show_card(card: Dictionary, on_close: Callable = Callable(), image_kind := "") -> void:
	if card.is_empty():
		if on_close.is_valid():
			on_close.call()
		return
	var p := CardPopup.new()
	p.setup(card, image_kind)
	add_overlay(p)
	_popup_open = true
	get_tree().paused = true
	p.closed.connect(func():
		_popup_open = false
		get_tree().paused = false
		if on_close.is_valid():
			on_close.call()
	)
	if testing:
		# テスト時は少し待ってから自動で閉じる
		await get_tree().create_timer(0.05, true).timeout
		if is_instance_valid(p):
			p.close()


func is_popup_open() -> bool:
	return _popup_open


func toggle_pause() -> void:
	if level == null or _popup_open:
		return
	var existing := overlay_layer.get_node_or_null("PauseMenu")
	if existing:
		existing.queue_free()
		get_tree().paused = false
		return
	var pm := PauseMenu.new()
	pm.name = "PauseMenu"
	add_overlay(pm)
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and level != null:
		toggle_pause()
		get_viewport().set_input_as_handled()


## HUD のメッセージ（ドクター・ピコ）
func say(text: String, seconds := 4.0) -> void:
	if hud and is_instance_valid(hud):
		hud.say(text, seconds)
