extends "res://tests/shot.gd"
## ブラウザ版と テスト（エディタの Godot）で、画面の 文が 同じ 行で 折れるかを くらべる ための 画面めぐり。
## tools/web_text_check.sh が 2 回 動かす：ここ（エディタの Godot、ヘッドレス）と、ブラウザ版に 書き出した 写し。
## テストは 文が 箱に 入るかを エディタの Godot で はかる。ブラウザ版の 折りかたが ちがうと、はかった 行の 数が
## 画面と 合わない（前は 行の 折りかたの データを 持たず、空白でしか 折れなかった）。
##
## やる こと：1〜3 話の 画面を ぜんぶ 順に 出し（shot.gd の _setup() を そのまま 使う）、見えて いる 文
## （Label と、字の ある Button）ごとに「どこで 行が 折れたか」を 1 行の JSON で 出す：
##   WEBTEXT {"s": 画面, "i": 番号, "k": 種類, "t": 文, "w": 幅, "n": ラベルが 数えた 行の 数, "lines": [行, …], "cut": 切れて いるか}
##   WEBTEXT {"s": 画面, "fits": 画面の fits() の 答え, "over": overflow() の 答え}
##   WEBTEXT {"view": 画面の 大きさ}／WEBTEXT {"end": 画面の 数}
## 行の 中身は Label と 同じ 折りかた（TextParagraph に 同じ フォント・大きさ・幅・折りかたの しるし）で 出し、
## ラベル 自身の get_line_count() と 合うかも 出す（合わなければ くらべる 側が「はかりちがい」と 言う）。
## そのあと HUD の ピコの ふきだしに 1〜3 話の 場面の 文（intro・ヒント（text と text_touch）・goal_say・clear_say・
## ミッションの each_say と done_say・とおりみちの say）を 1 つずつ 入れて 同じ ように 出す。
## 文の 見ためは 出さない（色・位置は ここでは くらべない）。セーブは user://save_webtext.json（本物を さわらない）。

const T := preload("res://src/ui/ui_theme.gd")
const HudScene := preload("res://src/ui/hud.gd")
const MissionScript := preload("res://src/level/mission.gd")
const EPS := ["ep01", "ep02", "ep03"]
## 1 画面を 出してから 文を あつめる までに 待つ フレーム（コンテナの ならべなおしは 次の フレーム）
const SETTLE_FRAMES := 6
const SEED := 20261125


## HUD に わたす にせの Level（ミッションの 文と 上の 題だけ 出す。3D は 読みこまない）
class FakeLevel extends Node:
	signal missions_changed
	signal hearts_changed(h: int)
	var stage := {}
	var missions: Array = []
	var player = null


var _screens := 0
var _texts := 0


func _ready() -> void:
	Game.testing = true
	# テスト（smoke.gd）と 同じ 1280×720 に する。ヘッドレスの 窓は 64×64 で、そのままだと 形が かわる
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	SaveData.use_path("user://save_webtext.json")
	var vs := get_viewport().get_visible_rect().size
	_out({"view": "%dx%d" % [int(vs.x), int(vs.y)], "ts": TextServerManager.get_primary_interface().get_name(),
		"data": TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_USE_SUPPORT_DATA),
		"setting": ProjectSettings.get_setting("internationalization/locale/include_text_server_data", false)})
	for item in screen_list():
		var flags: PackedStringArray = item.split("+")
		var stage := flags[0]
		flags.remove_at(0)
		_reset(flags.has("touch"))
		seed(SEED)   # カルテの クイズの えらびは 出す たびに まぜる。両方で 同じ ならびに する
		if not await _setup(stage, flags):
			_out({"s": item, "error": "画面が 出せない"})
			continue
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		# ポーズは 場面を 30 フレーム 動かして から 出す。ブラウザは おそいので その あいだに 進む 所が ちがう
		# （のった きょり・カードの ふだ）。ポーズの 箱の 中だけ くらべる
		var pause_menu := Game.overlay_layer.get_node_or_null("PauseMenu")
		_collect(item, pause_menu if stage == "pause" and pause_menu != null else get_tree().root)
		var scr := Game.screen()
		if scr != null and scr.has_method("fits"):
			_out({"s": item, "fits": scr.fits(), "over": scr.overflow() if scr.has_method("overflow") else ""})
		await _close_overlays()
	await _hud_texts()
	_out({"end": _screens, "texts": _texts})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	get_tree().quit(0)


## 出す 画面の 一覧（1〜3 話。データから 作るので 話や ページが ふえても ついて いく）。書きかたは shot.gd の 先頭と 同じ。
## shot.gd に 無い もの：guess_pick:<話>:<場所>（よそうで その 場所を えらんだ あと）、opening+p<N>（はじめの はなしの N ページ）
static func screen_list() -> Array[String]:
	var out: Array[String] = ["title", "select_new", "select", "resume"]
	for k in EpisodeDB.OPENING.size():
		out.append("opening+p%d" % k)
	var places: Array[String] = []
	for id in EPS:
		var ep: Dictionary = EpisodeDB.get_episode(id)
		for k in ep["consult"].size():
			out.append("consult:%s+p%d" % [id, k])
		out.append("guess:" + id)
		for c in ep["guess"]["choices"]:
			out.append("guess_pick:%s:%s" % [id, c["place"]])
		for m in ["enter", "exit"]:
			for t in ["+t0", "+t50", "", "+cleared"]:
				out.append(m + ":" + id + t)
		if EpisodeDB.has_pass(ep):
			out.append("hop:%s:-1" % id)
		for i in ep["scenes"].size() - 1:
			out.append("hop:%s:%d+t0" % [id, i])
			out.append("hop:%s:%d" % [id, i])
		for i in ep["scenes"].size():
			var sc: Dictionary = ep["scenes"][i]
			if not places.has(sc["place"]):
				places.append(sc["place"])
			if EpisodeDB.is_pass(ep, i):
				continue
			var guesses := [""]
			if sc.get("after", {}).has("lines_hit"):
				guesses.append("+hit")
			for g in guesses:
				var first := ""
				if g == "+hit":
					for c in ep["guess"]["choices"]:
						if c.get("hit", false):
							first = c["place"]
				for k in EpisodeDB.after_lines(ep, i, first).size():
					out.append("after:%s:%d+p%d%s" % [id, i, k, g])
		for n in 4:
			out.append("karte:%s:%d" % [id, n])
		out.append("karte:%s:3+wrong" % id)
		out.append("karte:%s:3+hurt" % id)
		for n in 3:
			out.append("review:%s:%d" % [id, n])
		out.append("zukan_karte:" + id)
	for p in places:
		out.append("cards:" + p)
		for key in StageDB.get_stage(p)["cards"].keys():
			out.append("card:%s:%s" % [p, key])
	out.append("zukan")
	out.append("pause")   # さいごに（3D の 場面を 読みこむ）
	return out


func _setup(stage: String, flags: PackedStringArray) -> bool:
	var parts := stage.split(":")
	if parts[0] == "guess_pick":
		# よそうで その 場所を えらぶ（はずれ・go・あたり の ふきだし。shot.gd の guess_wrong／guess_go は 1 つずつ だけ）
		Game.start_episode(parts[1], "guess")
		await _wait_unlocked()
		Game.screen().choose(parts[2])
		return true
	var ok: bool = await super(stage, flags)
	if stage == "opening":
		for f in flags:
			if f.begins_with("p") and f.substr(1).is_valid_int():
				await _press(int(f.substr(1)))
	return ok


## root の 下の 見えて いる 文を ぜんぶ 出す
func _collect(sid: String, root: Node) -> void:
	_screens += 1
	var i := 0
	for n in root.find_children("*", "Control", true, false):
		if not n.is_visible_in_tree():
			continue
		if not (n is Label or n is Button):
			continue
		var text: String = n.text
		if text.replace(T.WJ, "").strip_edges() == "":
			continue
		_out(_record(sid, i, n))
		i += 1


func _record(sid: String, i: int, n: Control) -> Dictionary:
	var rec := {"s": sid, "i": i, "k": n.get_class(), "t": String(n.text).replace(T.WJ, "")}
	if n is Label:
		rec["w"] = snappedf(n.size.x, 0.01)
		rec["n"] = n.get_line_count()
		rec["lines"] = label_lines(n)
		rec["cut"] = n.autowrap_mode != TextServer.AUTOWRAP_OFF and n.get_visible_line_count() < n.get_line_count()
	else:
		rec["lines"] = Array(String(n.text).replace(T.WJ, "").split("\n"))
	_texts += 1
	return rec


## Label が 画面に 出す 行（WJ を ぬいた 字で）。Label と 同じ 折りかた：段落（"\n"）ごとに、同じ フォント・大きさ・
## 幅（わくの 分を ひく）・折りかたの しるしで TextParagraph に 折らせる
static func label_lines(l: Label) -> Array:
	var text := l.text
	var out := []
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		for s in text.split("\n"):
			out.append(s.replace(T.WJ, ""))
		return out
	var flags := TextServer.BREAK_MANDATORY
	match l.autowrap_mode:
		TextServer.AUTOWRAP_ARBITRARY:
			flags |= TextServer.BREAK_GRAPHEME_BOUND
		TextServer.AUTOWRAP_WORD:
			flags |= TextServer.BREAK_WORD_BOUND
		TextServer.AUTOWRAP_WORD_SMART:
			flags |= TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	flags |= int(l.get("autowrap_trim_flags"))
	var sb := l.get_theme_stylebox("normal")
	var w := l.size.x - (sb.get_minimum_size().x if sb != null else 0.0)
	var font := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	for para in text.split("\n"):
		var p := TextParagraph.new()
		p.break_flags = flags
		p.width = w
		p.add_string(para, font, fs, l.language)
		for k in p.get_line_count():
			var r := p.get_line_range(k)
			out.append(para.substr(r.x, r.y - r.x).replace(T.WJ, ""))
	return out


## HUD の ピコの ふきだしに 場面の 文を 1 つずつ 入れる（3D は 読みこまない。HUD だけ にせの Level で 出す）
func _hud_texts() -> void:
	Game.unload_level()
	Game._clear_screen()
	Game._ensure_touch_controls()
	for id in EPS:
		var ep: Dictionary = EpisodeDB.get_episode(id)
		for i in ep["scenes"].size():
			var sc: Dictionary = ep["scenes"][i]
			var st: Dictionary = EpisodeDB.scene_stage(ep, i)
			var fake := FakeLevel.new()
			fake.stage = st
			for d in st.get("missions", []):
				fake.missions.append(MissionScript.from_dict(d))
			add_child(fake)
			var hud = HudScene.new()
			hud.theme = Game.theme
			Game.ui_layer.add_child(hud)
			hud.bind_level(fake)
			var says := []   # [名前, 文, タッチか]
			if st.get("intro", "") != "":
				says.append(["intro", st["intro"], false])
			for k in st.get("hints", []).size():
				var h: Dictionary = st["hints"][k]
				says.append(["hint%d" % k, h["text"], false])
				if h.has("text_touch"):
					says.append(["hint%d_touch" % k, h["text_touch"], true])
			for k in st.get("missions", []).size():
				var d: Dictionary = st["missions"][k]
				for e in d.get("each_say", []).size():
					says.append(["m%d_each%d" % [k, e], d["each_say"][e], false])
				if d.get("done_say", "") != "":
					says.append(["m%d_done" % k, d["done_say"], false])
			if st.has("goal_say"):
				says.append(["goal_say", st["goal_say"], false])
			if st.get("clear_say", "") != "":
				says.append(["clear_say", st["clear_say"], false])
			if sc.get("say", "") != "":
				says.append(["say", sc["say"], false])
			var first := true
			for s in says:
				Game.touch_controls.visible = s[2]
				hud.say(s[1], 1000.0)
				for f in SETTLE_FRAMES:
					await get_tree().process_frame
				var sid := "hud:%s:%d:%s" % [id, i, s[0]]
				if first:
					_collect(sid, hud)   # はじめは HUD ぜんぶ（上の 題・ミッション）
					first = false
				else:
					_screens += 1
					_out(_record(sid, 0, hud._msg_label))
			Game.touch_controls.visible = false
			hud.queue_free()
			fake.queue_free()
			await get_tree().process_frame


func _out(d: Dictionary) -> void:
	print("WEBTEXT " + JSON.stringify(d))
