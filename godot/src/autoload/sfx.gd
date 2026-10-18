extends Node
## 効果音と BGM。assets/audio/<name>.wav があれば鳴らす（なければ無音で何もしない）。

const DIR := "res://assets/audio/"
const POOL_SIZE := 12

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _bgm: AudioStreamPlayer
var _bgm_name := ""
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	add_child(_bgm)
	set_volume(float(SaveData.setting("volume", 0.8)))


func set_volume(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(0, v <= 0.0001)


func _stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := DIR + name + ".wav"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_streams[name] = s
	return s


## 効果音を鳴らす。pitch で音程を変えられる（しんけいパズルの音階など）。
func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var s := _stream(name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func play_bgm(name: String) -> void:
	if _bgm_name == name and _bgm.playing:
		return
	_bgm_name = name
	var s := _stream(name)
	if s == null:
		_bgm.stop()
		return
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(round(s.get_length() * s.mix_rate))  # 圧縮形式（QOA）でも正しい
	_bgm.stream = s
	_bgm.volume_db = -8.0
	_bgm.play()


func stop_bgm() -> void:
	_bgm_name = ""
	_bgm.stop()
