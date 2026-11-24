extends Node
## 効果音と 音楽。ファイルが 無い 名前は 何も しない（エラーに しない）。
## - 効果音：assets/audio/<name>.wav。小さいので 1 回 読んだら 覚えておく。
## - 音楽：assets/audio/<name>.ogg。bgm_* は ループ（.import で loop=true）、jingle_* と clear.wav は 1 回だけの 短い 曲。
##   作りかたは docs/audio.md（tools/music/ で 楽譜から 作る）。
## - どこで どの 曲か：場所は StageDB の "bgm"（ボスの いる 場面は bgm_boss。stage_music()）、
##   画面は フェーズ（Game.phase_changed → on_phase()。PHASE_MUSIC・PHASE_JINGLE）。
## - 曲の 切りかえは FADE 秒の クロスフェード。短い 曲は 音楽を DUCK_DB 下げて その 上に 鳴らす。
## - 音楽は 覚えておかない（鳴らして いる 曲と、消えて いく とちゅうの 曲だけ 持つ）。
##   ブラウザ版では 音楽を Stream 再生に する（Sample 再生だと Godot は OGG を 丸ごと ほどいて
##   Web Audio に 登録し、登録を はずさない。曲を 変える たびに 止まり、メモリも ふえる。docs/audio.md）。

const DIR := "res://assets/audio/"
const POOL_SIZE := 12
## 音楽の 音量。曲は −18 LUFS（短い 曲 −16）、効果音は 0.4 秒の 大きさの 山が −19〜−2（中央 −8）LUFS。
## −5 dB で 音楽は 平均 −23 LUFS（いちばん 大きい 所で −18）。ふつうの 効果音は それより 10 dB 以上 上に 出る
const MUSIC_DB := -5.0
## 短い 曲（ジングル・クリア）の 音量と、その あいだ 音楽を 下げる 量。
## 短い 曲は ハ長調で、場所の 曲は 調が ちがう（口は ニ長調、食道は イ長調…）。少し 下げるだけだと
## 2 つの 曲が 同時に 聞こえて にごるので、ほとんど 聞こえない ところまで 下げる
const SHORT_DB := 0.0
const DUCK_DB := -24.0
const DUCK_ATTACK := 0.12
const DUCK_RELEASE := 0.6
## 曲を 変える ときの クロスフェード（秒）
const FADE := 0.6
## Sfx.play() で 呼ばれても「短い 曲」として 鳴らす 名前（jingle_* は いつも）
const SHORT_PIECES := ["clear"]
## フェーズ → 曲。書いて いない フェーズ（scene・hop・しらない もの）は 今の 曲の まま。
## scene の 曲は Game._start_level() が stage_music() で 決める。hop（みちの ちず）は 通って きた 場所の 曲を つづける
const PHASE_MUSIC := {
	"consult": "bgm_clinic", "guess": "bgm_clinic", "after": "bgm_clinic",
	"enter": "bgm_clinic", "exit": "bgm_clinic", "karte": "bgm_karte",
}
## フェーズに 入った ときの 短い 曲（カルテの jingle_karte は karte.gd の「かいけつ！」で 鳴らす）
const PHASE_JINGLE := {"enter": "jingle_enter", "exit": "jingle_exit"}
## 場所に "bgm" が 無い ときの 曲
const DEFAULT_STAGE_MUSIC := "bgm_title"

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next := 0

## 音楽：2 つの プレーヤーを 交互に 使う（クロスフェード）
var _music: Array[AudioStreamPlayer] = []
var _gain := [0.0, 0.0]          # それぞれの フェードの 大きさ（0〜1）
var _target := [0.0, 0.0]
var _cur := 0                     # いまの 曲の プレーヤー
var _bgm_name := ""
var _short: AudioStreamPlayer
var _duck := 1.0                  # 短い 曲の あいだ 下げる（1 ＝ 下げない）
var _js_cb = null                 # ブラウザの 確かめ用（_web_test_hook）


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	_short = AudioStreamPlayer.new()
	_short.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_short.volume_db = SHORT_DB
	_short.finished.connect(func(): _short.stream = null)
	add_child(_short)
	set_volume(float(SaveData.setting("volume", 0.8)))
	_web_test_hook()


func set_volume(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(0, v <= 0.0001)


## 音の ファイル（.ogg を 先に、無ければ .wav）。無ければ ""
static func path_of(name: String) -> String:
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(DIR + name + ext):
			return DIR + name + ext
	return ""


func _stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := path_of(name)
	var s: AudioStream = load(path) if path != "" else null
	_streams[name] = s
	return s


static func is_short_piece(name: String) -> bool:
	return name.begins_with("jingle_") or SHORT_PIECES.has(name)


## 効果音を鳴らす。pitch で音程を変えられる（しんけいパズルの音階など）。短い 曲の 名前なら play_short()
func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if is_short_piece(name):
		play_short(name)
		return
	var s := _stream(name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## 短い 曲（ジングル）を 音楽の 上に 鳴らす。鳴って いる あいだ 音楽を DUCK_DB 下げる。前の 短い 曲は 止める
func play_short(name: String) -> void:
	var path := path_of(name)
	if path == "":
		return
	_short.stop()
	_short.stream = load(path)
	_short.play()


## ループの 曲に 切りかえる（同じ 曲なら そのまま）。無い 名前・"" なら 音楽を 消す
func play_bgm(name: String) -> void:
	if _bgm_name == name and _music[_cur].playing:
		return
	_bgm_name = name
	var path := path_of(name) if name != "" else ""
	_target[_cur] = 0.0                # いまの 曲は 消えて いく（_process で 止めて 手ばなす）
	if path == "":
		return
	var nxt := 1 - _cur
	var p := _music[nxt]
	p.stop()
	p.stream = load(path)
	_gain[nxt] = 0.0
	_target[nxt] = 1.0
	_apply(nxt)
	p.play()
	_cur = nxt


func stop_bgm() -> void:
	play_bgm("")


## いま 鳴らして いる（鳴らそうと して いる）ループの 曲の 名前
func bgm_name() -> String:
	return _bgm_name


## 場所（場面）の 曲：ボスの いる 場面は bgm_boss、ほかは 場所の "bgm"
static func stage_music(stage: Dictionary) -> String:
	for m in stage.get("missions", []):
		if m is Dictionary and m.get("type", "") == "boss":
			return "bgm_boss"
	return String(stage.get("bgm", DEFAULT_STAGE_MUSIC))


## フェーズの 曲（"" ＝ 今の まま）
static func phase_music(phase: String) -> String:
	return PHASE_MUSIC.get(phase, "")


## Game.phase_changed に つなぐ。しらない フェーズは 何も しない
func on_phase(phase: String, _index: int = 0) -> void:
	var m := phase_music(phase)
	if m != "":
		play_bgm(m)
	if PHASE_JINGLE.has(phase):
		play_short(PHASE_JINGLE[phase])


func _process(delta: float) -> void:
	var step := delta / FADE
	for i in 2:
		if _gain[i] != _target[i]:
			_gain[i] = move_toward(_gain[i], _target[i], step)
		if _gain[i] <= 0.0 and _target[i] <= 0.0 and _music[i].stream != null:
			_music[i].stop()
			_music[i].stream = null   # 手ばなす（ResourceLoader の 覚えも 消える）
	var want := db_to_linear(DUCK_DB) if _short.playing else 1.0
	var rate := (1.0 - db_to_linear(DUCK_DB)) * delta / (DUCK_ATTACK if want < _duck else DUCK_RELEASE)
	_duck = move_toward(_duck, want, rate)
	for i in 2:
		_apply(i)


func _apply(i: int) -> void:
	# 等パワーの クロスフェード（sin）× ダッキング
	var g: float = sin(_gain[i] * PI * 0.5) * _duck
	_music[i].volume_db = MUSIC_DB + linear_to_db(maxf(g, 0.00001))


## ブラウザ版の 音の 確かめ（docs/audio.md）：URL に ?musictest が ある ときだけ、
## window.godotMusic(name) で 曲を 変えられる（ページの 外から フェーズを 進めずに 曲を 回す）
func _web_test_hook() -> void:
	if not OS.has_feature("web"):
		return
	if not str(JavaScriptBridge.eval("location.search", true)).contains("musictest"):
		return
	_js_cb = JavaScriptBridge.create_callback(func(args: Array):
		var n := str(args[0]) if args.size() > 0 else ""
		if n.begins_with("jingle_") or n == "clear":
			play_short(n)
		else:
			play_bgm(n))
	JavaScriptBridge.get_interface("window").godotMusic = _js_cb
