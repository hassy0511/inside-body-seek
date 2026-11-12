extends Node
## ゲーム全体の進行（タイトル → カルテえらび → そうだん → よそう → 場面 1〜3 こ → カルテ）。
## 画面は src/ui/ の Control をコードで組み立てて UILayer に置く。
## - カルテ（1 話）の 流れは _enter() の 1 か所で 切りかえる。データは EpisodeDB、設計は docs/episodes.md 3 章。
## - 「画面」と「Level」は 同時に 生きない（画面を 出す 前に unload_level()）。
##   場所の ものしりカードだけは、クリアした Level の 上に ポップアップで 出る。

signal stage_started(stage_id: String)
## Level を 1 つ クリアする たびに 出る（カルテの 場面でも 場所モードでも）。stars は いつも 0（ほしは カルテごと）
signal stage_finished(stage_id: String, stars: int)
## カルテ画面を 閉じた とき
signal episode_finished(ep_id: String, stars: int)
## フェーズに 入った とき（index は 場面の 番号。テストが 順番を 見る）
signal phase_changed(phase: String, index: int)
## HUD に 文が 出た とき（テストが goal_say などを 見る）
signal said(text: String)

const UiThemeBuilder := preload("res://src/ui/ui_theme.gd")
const TitleScreen := preload("res://src/ui/title.gd")
const EpisodeSelectScreen := preload("res://src/ui/episode_select.gd")
const TalkScreen := preload("res://src/ui/talk.gd")
const GuessScreen := preload("res://src/ui/guess.gd")
const KarteScreen := preload("res://src/ui/karte.gd")
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

## いまの カルテ（空なら「場所だけ」モード：テストと 撮影用）
var episode: Dictionary = {}
var scene_index := 0
var phase := ""            # "consult" / "guess" / "scene" / "after" / "karte" / ""
var first_guess := ""
var _review := false       # クリアずみの カルテを 読みかえして いる（クリアの 記録を しない）

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
	# メニューを ゲームパッド／Z・X キーでも 操作できるように（ui_accept は標準では Enter/Space だけ）
	_add_action("ui_accept", [_jbtn(JOY_BUTTON_A), _key(KEY_Z)])
	_add_action("ui_cancel", [_jbtn(JOY_BUTTON_B), _key(KEY_X)])


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
	if touch_controls and is_instance_valid(touch_controls):
		touch_controls.visible = false   # OverlayLayer は 画面より 上。出た ままだと 下の ボタンを 押せない
	ui_layer.add_child(c)


func screen() -> Control:
	return _screen if _screen != null and is_instance_valid(_screen) else null


## CanvasLayer の下に置く Control にはテーマが引き継がれないので、ここで付けてから足す
func add_overlay(c: Control) -> void:
	c.theme = theme
	overlay_layer.add_child(c)


func show_title() -> void:
	unload_level()
	episode = {}
	phase = ""
	Sfx.play_bgm("bgm_title")
	_set_screen(TitleScreen.new())


func show_episode_select() -> void:
	unload_level()
	episode = {}
	phase = ""
	Sfx.play_bgm("bgm_title")
	_set_screen(EpisodeSelectScreen.new())


func show_zukan() -> void:
	_set_screen(ZukanScreen.new())


# ---------------------------------------------------------------- カルテの 流れ
## カルテを 始める。from_phase / from_scene / guess は「つづきから」と テスト・撮影用（とちゅうから 入る）
func start_episode(ep_id: String, from_phase := "consult", from_scene := 0, guess := "") -> void:
	var ep := EpisodeDB.get_episode(ep_id)
	if ep.is_empty():
		show_episode_select()
		return
	unload_level()
	episode = ep
	scene_index = clampi(from_scene, 0, ep["scenes"].size() - 1)
	first_guess = guess
	_review = false
	Sfx.play_bgm("bgm_title")
	_enter(from_phase)


## 「つづきから」：さいごに おえた 場面の「あとの はなし」から 入る（おさらいに なる）。無ければ 次の 場面か カルテへ
func resume_episode() -> void:
	var r := SaveData.resume()
	if r.is_empty():
		show_episode_select()
		return
	start_episode(r["ep"], "after", int(r["cleared"]) - 1, r.get("guess", ""))


## クリアずみの カルテの 紙と クイズだけ もういちど（クイズの ほしを 取りなおせる）
func review_karte(ep_id: String) -> void:
	if not SaveData.is_cleared(ep_id):
		show_episode_select()
		return
	unload_level()
	episode = EpisodeDB.get_episode(ep_id)
	scene_index = 0
	first_guess = ""
	_review = true
	_enter("karte")


## フェーズに 入る（切りかえは ここ 1 か所）。データが 無い フェーズは 自分で 次へ 進む。
## back は よそうから そうだんへ もどる とき（そうだんの さいごの ページを 出す）
func _enter(p: String, back := false) -> void:
	phase = p
	match p:
		"consult":
			var lines: Array = episode["consult"]
			var opening: bool = not SaveData.data["opening_seen"]
			if opening:
				lines = EpisodeDB.OPENING + lines
			if lines.is_empty():   # データの まちがい（validate() が 止める）。それでも 先へ 進める
				_enter("guess")
				return
			var t := TalkScreen.new()
			t.setup(lines, {"mood": "sick", "can_cancel": true, "start_page": lines.size() - 1 if back else 0, "last_label": "よそうする ▶" if episode.has("guess") else "しゅっぱつ！ ▶"})
			t.finished.connect(func():
				if opening:
					SaveData.data["opening_seen"] = true   # 読みおわってから 既読に（とちゅうで もどった 子には もう一度 出す）
					SaveData.save()
				_enter("guess"))
			t.cancelled.connect(show_episode_select)
			_set_screen(t)
		"guess":
			if not episode.has("guess"):
				_enter("scene")
				return
			var g := GuessScreen.new()
			g.setup(episode)
			g.finished.connect(func(first: String):
				first_guess = first
				_enter("scene"))
			g.cancelled.connect(func(): _enter("consult", true))   # もどる ＝ そうだんの さいごの ページへ
			_set_screen(g)
		"scene":
			_start_level(EpisodeDB.scene_stage(episode, scene_index))
		"after":
			var a: Dictionary = episode["scenes"][scene_index].get("after", {})
			var after_lines := EpisodeDB.after_lines(episode, scene_index, first_guess)
			if after_lines.is_empty():   # あとの はなしが 無い 場面は すぐ 次へ
				_after_done()
				return
			unload_level()
			var last: bool = scene_index + 1 >= episode["scenes"].size()
			var t := TalkScreen.new()
			t.setup(after_lines, {"mood": "sick", "banner": a.get("banner", ""), "last_label": "つぎへ ▶" if last else "つぎへ いこう ▶"})
			t.finished.connect(_after_done)
			_set_screen(t)
		"karte":
			unload_level()
			var id: String = episode["id"]
			if not _review:
				SaveData.record_clear(id)   # カルテを とちゅうで やめても クリアは のこる
				SaveData.clear_resume(id)
			var k := KarteScreen.new()
			k.setup(episode, {"guess_hit": EpisodeDB.guess_is_hit(episode, first_guess), "review": _review})
			k.answered.connect(func(correct: bool): SaveData.record_quiz(id, correct))
			k.finished.connect(_on_karte_finished)
			_set_screen(k)
		_:
			push_error("unknown phase: %s" % p)
			show_episode_select()
			return
	phase_changed.emit(p, scene_index)


## あとの はなしが おわった：つぎの 場面へ。さいごの 場面なら カルテへ
func _after_done() -> void:
	if scene_index + 1 < episode["scenes"].size():
		scene_index += 1
		_enter("scene")
	else:
		_enter("karte")


## カルテ画面を 閉じた：つぎの カルテへ（go_next）か、カルテえらびへ
func _on_karte_finished(go_next: bool) -> void:
	var id: String = episode["id"]
	episode_finished.emit(id, SaveData.stars(id))
	var next := EpisodeDB.next_id(id)
	if go_next and next != "":
		start_episode(next)
	elif go_next and EpisodeDB.SEASON_COMPLETE:
		show_ending()
	else:
		show_episode_select()


## 場所だけを 既定の ミッションで 開く（テスト・スクリーンショット用。子どもの 画面からは 来ない）
func start_stage(place_id: String) -> void:
	episode = {}
	phase = ""
	_start_level(StageDB.get_stage(place_id))


## stage ＝ 場所の 辞書（場所モード）か、EpisodeDB.scene_stage() の 辞書（場所の 写し ＋ 場面の 上書き）
func _start_level(stage: Dictionary) -> void:
	unload_level()
	_clear_screen()
	current_stage_id = stage["id"]
	level = LevelScene.instantiate()
	level.setup(stage)
	world.add_child(level)
	hud = HudScene.new()
	hud.theme = theme
	ui_layer.add_child(hud)
	hud.bind_level(level)
	_ensure_touch_controls()
	Sfx.play_bgm(stage.get("bgm", "bgm_boss" if stage["difficulty"] >= 3 else "bgm_stage"))
	stage_started.emit(current_stage_id)
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


## ポーズの「この ばめんを やりなおす」：いまの 場面だけ 最初から（そうだんへは もどらない）
func retry_stage() -> void:
	if episode.is_empty():
		start_stage(current_stage_id)
	else:
		_enter("scene")


func _on_level_cleared(place_id: String, no_damage: bool) -> void:
	stage_finished.emit(place_id, 0)
	if episode.is_empty():
		show_episode_select()   # 場所モード（テスト・撮影）
		return
	var id: String = episode["id"]
	SaveData.record_scene(id, scene_index, no_damage)          # ハートの 印は 場面ごと・回を またいで たまる
	# ここまでは「つづきから」で もどれる。つづきの 記録は 1 つだけ なので、クリアずみの 話を
	# 遊びなおして いる ときは、ほかの 話（まだ とちゅう）の つづきを 上書きしない
	var r := SaveData.resume()
	if r.is_empty() or r["ep"] == id or not SaveData.is_cleared(id):
		SaveData.set_resume(id, scene_index + 1, first_guess)
	SaveData.mark_card(place_id, "summary")                    # 場所の「まとめ」は クリアで ずかんに 入る
	# 場所の ものしりカードは、はじめて クリアした あとに 1 回（遊ぶ 前の 文を へらす）
	var card: Dictionary = {} if SaveData.card_seen(place_id, "stage") else StageDB.card(place_id, "stage")
	show_card(card, func():
		SaveData.mark_card(place_id, "stage")
		_enter("after"), "stage", place_id)


func show_ending() -> void:
	unload_level()
	Sfx.play_bgm("bgm_title")
	var t := TitleScreen.new()
	t.ending_mode = true
	_set_screen(t)


# ---------------------------------------------------------------- ポップアップ
## ものしりカードを出す（ゲームは一時停止）。閉じたら on_close を呼ぶ。
func show_card(card: Dictionary, on_close: Callable = Callable(), image_kind := "", stage_id := "") -> void:
	if card.is_empty():
		if on_close.is_valid():
			on_close.call()
		return
	var p := CardPopup.new()
	p.setup(card, image_kind, stage_id)
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
	if level == null or _popup_open or level.finished:
		return
	var existing := overlay_layer.get_node_or_null("PauseMenu")
	if existing:
		var prev = existing.get("prev")
		existing.queue_free()
		get_tree().paused = false
		if prev != null and is_instance_valid(prev) and prev is Control:
			(prev as Control).grab_focus()
		return
	var pm := PauseMenu.new()
	pm.name = "PauseMenu"
	add_overlay(pm)
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and level != null and not level.finished:
		toggle_pause()
		get_viewport().set_input_as_handled()


## HUD のメッセージ（ドクター・ピコ）
## hold > 0 は 物語の ひとこと（出てから hold 秒は とっさの ひとことに 上書きされない）。Level.say_story() が 使う
func say(text: String, seconds := 4.0, hold := 0.0) -> void:
	if hud and is_instance_valid(hud) and hud.say(text, seconds, hold):
		said.emit(text)


## おまけの ひとこと（チェックポイント など）：ほかの 文が 出ている あいだは 出さない（ヒントと 同じ きまり）
func say_soft(text: String, seconds := 4.0) -> void:
	if not hud_busy():
		say(text, seconds)


## タッチ操作が いま 有効か（設定が auto のときは タッチ画面の有無で決まる）
func touch_effective() -> bool:
	var s: String = SaveData.setting("touch", "auto")
	return s == "on" or (s == "auto" and DisplayServer.is_touchscreen_available())


func hud_busy() -> bool:
	return hud != null and is_instance_valid(hud) and hud.is_busy()
