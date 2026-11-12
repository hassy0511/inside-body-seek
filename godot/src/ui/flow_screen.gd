extends Control
## カルテの 流れの 画面（カルテえらび・はなし・よそう・カルテ）の 土台。
## - いつも どこかに フォーカスが ある ように 見はる（消えたら focus_target に もどす）
## - 押しすぎ よけ：lock() から 0.4 秒は locked() が true（ボタンは disabled に しない。フォーカスが 外れない ように）
## - 時間で 勝手に 進まない。Game.testing でも 自動送り しない（テストは フォーカス中の ボタンを 押して 進める）
## テーマは Game._set_screen() が 付ける。const T は ここに ある（継いだ 側で もう一度 書かない）。

const T := preload("res://src/ui/ui_theme.gd")

var focus_target: Control = null
var _lock := 0.0


func _process(delta: float) -> void:
	# 時間は delta で 数える（テストは 実時間より ずっと 速く 回るので、時計は 使わない）
	_lock = maxf(_lock - delta, 0.0)
	if focus_target != null and is_instance_valid(focus_target) and focus_target.is_visible_in_tree() \
			and get_viewport().gui_get_focus_owner() == null:
		focus_target.grab_focus()


## 子どもが 次に 押す ボタンへ フォーカスを 入れる（画面の 中身を 作りかえる たびに 呼ぶ）
func set_focus(c: Control) -> void:
	focus_target = c
	c.grab_focus()


func lock(seconds := 0.4) -> void:
	_lock = seconds


func locked() -> bool:
	return _lock > 0.0


## 全面の 背景を しき、画面の 中央に 固定の 大きさの 入れ物を 置いて 返す。
## 入れ物の 中は 1280×720 の ときの 座標で ならべる（画面の 大きさが 変わっても 中央に まとまる）。
func make_stage(bg: Color, box := Vector2(1180, 640)) -> Control:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = bg
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = -box.x * 0.5
	c.offset_right = box.x * 0.5
	c.offset_top = -box.y * 0.5
	c.offset_bottom = box.y * 0.5
	add_child(c)
	return c


## 左上の「← もどる」（ui_cancel と 同じ はたらきを on_back に わたす）
func add_back_button(on_back: Callable) -> Button:
	var b := T.button("← もどる", 24)
	b.position = Vector2(24, 20)
	b.pressed.connect(func():
		if not locked():
			Sfx.play("click")
			on_back.call())
	add_child(b)
	return b


## 文が 幅 width・大きさ font_size で 何行に なるか（本物の フォントで はかる。テストが 使う）
static func lines_of(text: String, font_size: int, width: float) -> int:
	var f: Font = Game.font_regular
	var h := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size).y
	return int(ceil(h / f.get_height(font_size) - 0.01))
