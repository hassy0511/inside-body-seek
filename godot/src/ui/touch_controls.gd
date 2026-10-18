extends Control
## タッチそうさ：左に丸いスティック、右に「おくすり」と「ダッシュ」のボタン。
## Input.action_press を使うので、プレイヤー側はキーボードと同じ扱いになる。

const T := preload("res://src/ui/ui_theme.gd")
const STICK_R := 90.0
const KNOB_R := 40.0

var _stick_touch := -1
var _stick_center := Vector2.ZERO
var _knob := Vector2.ZERO
var _action_touch := -1
var _dash_touch := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = should_show()


func should_show() -> bool:
	var s: String = SaveData.setting("touch", "auto")
	if s == "on":
		return true
	if s == "off":
		return false
	return DisplayServer.is_touchscreen_available()


func _stick_home() -> Vector2:
	return Vector2(170, size.y - 170)


func _action_center() -> Vector2:
	return Vector2(size.x - 150, size.y - 150)


func _dash_center() -> Vector2:
	return Vector2(size.x - 300, size.y - 110)


func _input(event: InputEvent) -> void:
	if not visible or Game.level == null:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if e.position.distance_to(_action_center()) < 80 and _action_touch < 0:
				_action_touch = e.index
				Input.action_press("action")
				queue_redraw()
			elif e.position.distance_to(_dash_center()) < 55 and _dash_touch < 0:
				_dash_touch = e.index
				Input.action_press("dash")
				queue_redraw()
			elif e.position.x < size.x * 0.5 and _stick_touch < 0:
				_stick_touch = e.index
				_stick_center = e.position
				_knob = Vector2.ZERO
				queue_redraw()
		else:
			if e.index == _action_touch:
				_action_touch = -1
				Input.action_release("action")
			elif e.index == _dash_touch:
				_dash_touch = -1
				Input.action_release("dash")
			elif e.index == _stick_touch:
				_stick_touch = -1
				_knob = Vector2.ZERO
				_release_move()
			queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_touch:
			var v := d.position - _stick_center
			if v.length() > STICK_R:
				v = v.normalized() * STICK_R
			_knob = v
			_apply_move(v / STICK_R)
			queue_redraw()


func _apply_move(v: Vector2) -> void:
	_release_move()
	if v.x < -0.15:
		Input.action_press("move_left", -v.x)
	elif v.x > 0.15:
		Input.action_press("move_right", v.x)
	if v.y < -0.15:
		Input.action_press("move_up", -v.y)
	elif v.y > 0.15:
		Input.action_press("move_down", v.y)


func _release_move() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_release_move()
		if _action_touch >= 0:
			Input.action_release("action")
		if _dash_touch >= 0:
			Input.action_release("dash")
		_stick_touch = -1
		_action_touch = -1
		_dash_touch = -1


func _draw() -> void:
	var sc := _stick_center if _stick_touch >= 0 else _stick_home()
	draw_circle(sc, STICK_R, Color(1, 1, 1, 0.22))
	draw_arc(sc, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.5), 3)
	draw_circle(sc + _knob, KNOB_R, Color(1, 1, 1, 0.6))
	var ac := _action_center()
	draw_circle(ac, 80, Color(0.6, 0.95, 1.0, 0.75 if _action_touch >= 0 else 0.45))
	draw_arc(ac, 80, 0, TAU, 48, Color(1, 1, 1, 0.7), 3)
	draw_string(Game.font_bold, ac + Vector2(-46, 10), "おくすり", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, T.INK)
	var dc := _dash_center()
	draw_circle(dc, 55, Color(1.0, 0.85, 0.4, 0.75 if _dash_touch >= 0 else 0.45))
	draw_arc(dc, 55, 0, TAU, 40, Color(1, 1, 1, 0.7), 3)
	draw_string(Game.font_bold, dc + Vector2(-40, 8), "ダッシュ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, T.INK)
