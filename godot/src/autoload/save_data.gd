extends Node
## セーブデータ（user://save.json）。カルテごとの ほし・つづき・見た カード・設定。version 3。
## v3：ハートの 印（nd）は 場面の キーごと（scene_key：場所の id。同じ 場所の 2 回め からは「nose#1」）。
##     場面の 番号は とおりみちが 入ると ずれるので 使わない。つづきには おえた 場面の キーも 書く。
## v2（場面の 番号ごと）は V2_PLACES で 場所に 読みかえて 引きつぐ（とおりみちを 入れる 前の 場面）。

const VERSION := 3
## v2 の ときの 各話の 場面の 場所（v2 の nd と つづきの 番号を 場所に 読みかえる。かえない こと）
const V2_PLACES := {"ep01": ["mouth"], "ep02": ["esophagus", "stomach"], "ep03": ["stomach", "intestine"]}

var path := "user://save.json"
var data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()


func _defaults() -> Dictionary:
	return {
		"version": VERSION,
		"episodes": {},        # ep_id -> {"clear": bool, "quiz": bool, "nd": {場面の キー: bool}}（nd[キー] ＝ その 場面を ハートを へらさずに クリアした ことが ある）
		"resume": {},          # とちゅうの カルテ：{"ep": id, "cleared": おえた 場面の 数（1〜）, "key": おえた 場面の キー, "guess": さいしょの よそう}。無ければ 空
		"cards_seen": [],      # "場所id/key" と "epNN/karte"（みつけた カード。ずかんで 読める）
		"cards_new": [],       # みつけたが まだ 開いて いない カード（cards_seen の 一部。ずかんに しるし）。無い セーブは みんな 読んだ ことに する
		"opening_seen": false,
		"steer_guide_seen": false,   # はじめての そうじゅうの てびき（steer_guide.gd）を おえた
		"settings": {"volume": 0.8, "touch": "auto", "unlock_all": false},
	}


## テスト・撮影用：べつの ファイルを 使う（本物の セーブを さわらない）
func use_path(p: String) -> void:
	path = p
	load_data()


func load_data() -> void:
	data = _defaults()
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK or not (json.data is Dictionary):
		return   # こわれた ファイル：既定値で 始める（つぎの save() で 上書き）
	var parsed: Dictionary = json.data
	var ver := int(parsed["version"]) if typeof(parsed.get("version")) in [TYPE_INT, TYPE_FLOAT] else 1
	# どの 版でも 引きつぐ：設定と 見た カード（カードの キーは v1 から「場所id/key」の まま）
	if parsed.get("settings") is Dictionary:
		for k in data["settings"].keys():
			if typeof(parsed["settings"].get(k)) == typeof(data["settings"][k]):
				data["settings"][k] = parsed["settings"][k]
	if parsed.get("cards_seen") is Array:
		for c in parsed["cards_seen"]:
			if c is String and not data["cards_seen"].has(c):
				data["cards_seen"].append(c)
	if parsed.get("cards_new") is Array:
		for c in parsed["cards_new"]:
			if c is String and data["cards_seen"].has(c) and not data["cards_new"].has(c):
				data["cards_new"].append(c)
	if ver != 2 and ver != VERSION:
		# v1（ステージごとの ほし）や 知らない 版：ほしと クリアは 引きつがない。元の ファイルは 写して のこす
		DirAccess.copy_absolute(path, "%s.v%d.json" % [path.get_basename(), ver])
		save()
		return
	if parsed.get("opening_seen") is bool:
		data["opening_seen"] = parsed["opening_seen"]
	if parsed.get("steer_guide_seen") is bool:
		data["steer_guide_seen"] = parsed["steer_guide_seen"]
	if parsed.get("episodes") is Dictionary:
		for id in parsed["episodes"].keys():
			var e = parsed["episodes"][id]
			if e is Dictionary:
				data["episodes"][String(id)] = {"clear": _yes(e.get("clear")), "quiz": _yes(e.get("quiz")), "nd": _read_nd(String(id), e.get("nd"), ver)}
	var r = parsed.get("resume")
	if r is Dictionary and r.get("ep") is String and typeof(r.get("cleared")) in [TYPE_INT, TYPE_FLOAT]:
		var ep := EpisodeDB.get_episode(r["ep"]) if EpisodeDB.ids().has(r["ep"]) else {}
		var cleared := _resume_index(ep, int(r["cleared"]), r.get("key", r.get("place")), ver)
		if cleared >= 1:
			data["resume"] = {"ep": r["ep"], "cleared": cleared, "key": scene_key(ep, cleared - 1), "guess": r["guess"] if r.get("guess") is String else ""}
	if ver != VERSION:
		# v2 から 読みかえた：元の ファイルは 写して のこし、新しい 形で 書きなおす
		DirAccess.copy_absolute(path, "%s.v%d.json" % [path.get_basename(), ver])
		save()


## ハートの 印を {場面の キー: bool} に する。v2 は 場面の 番号の 配列（V2_PLACES で 場所に 読みかえる。v2 の 話に 同じ 場所の くりかえしは ないので キー ＝ 場所。知らない 話は すてる）
func _read_nd(ep_id: String, v, ver: int) -> Dictionary:
	var out := {}
	if ver == 2:
		var places: Array = V2_PLACES.get(ep_id, [])
		if v is Array:
			for i in mini(v.size(), places.size()):
				if _yes(v[i]):
					out[places[i]] = true
	elif v is Dictionary:
		for k in v.keys():
			if k is String and _yes(v[k]):
				out[k] = true
	return out


## つづきの「おえた 場面の 数」を いまの 場面の 列に 合わせる（合わなければ 0 ＝ つづき なし）。
## key（おえた 場面の キー）が あれば それで さがす（場面の 数が かわっても ずれない）。v2 は V2_PLACES で 場所に する
func _resume_index(ep: Dictionary, cleared: int, key, ver: int) -> int:
	if ep.is_empty():
		return 0
	var n: int = ep["scenes"].size()
	var want := ""
	if ver == 2:
		var places: Array = V2_PLACES.get(ep["id"], [])
		want = places[cleared - 1] if cleared >= 1 and cleared <= places.size() else ""
		if want == "":
			return 0
	elif key is String:
		want = key
	if want != "":
		for i in n:
			if scene_key(ep, i) == want:
				return i + 1
		return 0
	return cleared if cleared >= 1 and cleared <= n else 0


## true の ときだけ true（JSON の 数や 文字と「== true」で くらべると 型の エラーに なる）
static func _yes(v) -> bool:
	return v is bool and v


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func reset() -> void:
	data = _defaults()
	save()


func _entry(ep_id: String) -> Dictionary:
	if not data["episodes"].has(ep_id):
		data["episodes"][ep_id] = {"clear": false, "quiz": false, "nd": {}}
	var e: Dictionary = data["episodes"][ep_id]
	if not (e.get("nd") is Dictionary):
		e["nd"] = {}
	return e


## 場面の キー：場所の id。同じ 話で 同じ 場所を 2 回め・3 回め に 使う ときは「nose#1」「nose#2」（ハートの 印と つづきが 使う）
static func scene_key(ep: Dictionary, i: int) -> String:
	var sc: Array = ep.get("scenes", [])
	if i < 0 or i >= sc.size():
		return ""
	var place: String = sc[i].get("place", "")
	var before := 0
	for k in i:
		if sc[k].get("place", "") == place:
			before += 1
	return place if before == 0 else "%s#%d" % [place, before]


## ハートの ほしを 数える 場面（とおりみちは 数えない）の 番号
static func heart_scenes(ep_id: String) -> Array[int]:
	var out: Array[int] = []
	if not EpisodeDB.ids().has(ep_id):
		return out
	var ep := EpisodeDB.get_episode(ep_id)
	for i in ep["scenes"].size():
		if not EpisodeDB.is_pass(ep, i):
			out.append(i)
	return out


## ハートの ほしを 数える 場面ごと（heart_scenes の 順）：ハートを へらさずに クリアした ことが あるか
func scene_flags(ep_id: String) -> Array[bool]:
	var out: Array[bool] = []
	var nd = data["episodes"].get(ep_id, {}).get("nd", {})
	var ep := EpisodeDB.get_episode(ep_id) if EpisodeDB.ids().has(ep_id) else {}
	for i in heart_scenes(ep_id):
		out.append(nd is Dictionary and _yes(nd.get(scene_key(ep, i))))
	return out


## [カルテ かんせい, 全部の 場面で ハートを へらさずに, クイズ せいかい]。2 つめ・3 つめは クリアして はじめて つく。
## 2 つめは とおりみちを 数えない（てきも いけも ないので、入れても 入れなくても かわらない ように）
func star_flags(ep_id: String) -> Array[bool]:
	var e: Dictionary = data["episodes"].get(ep_id, {})
	var clear: bool = e.get("clear", false)
	var sf := scene_flags(ep_id)
	return [clear, clear and not sf.is_empty() and not sf.has(false), clear and e.get("quiz", false)]


func stars(ep_id: String) -> int:
	return star_flags(ep_id).count(true)


func is_cleared(ep_id: String) -> bool:
	return data["episodes"].get(ep_id, {}).get("clear", false)


## 場面を クリアした（ほしの 印は 回を またいで たまる。1 回 とった 印は 消えない）。とおりみちは 記録しない
func record_scene(ep_id: String, scene: int, no_damage: bool) -> void:
	var e := _entry(ep_id)
	if heart_scenes(ep_id).has(scene):
		var key := scene_key(EpisodeDB.get_episode(ep_id), scene)
		e["nd"][key] = _yes(e["nd"].get(key)) or no_damage
	save()


func record_clear(ep_id: String) -> void:
	_entry(ep_id)["clear"] = true
	save()


func record_quiz(ep_id: String, correct: bool) -> void:
	var e := _entry(ep_id)
	e["quiz"] = e["quiz"] or correct
	save()


## とちゅうの カルテ（無ければ 空の 辞書）
func resume() -> Dictionary:
	return data["resume"]


func set_resume(ep_id: String, cleared: int, guess: String) -> void:
	var key := ""
	if EpisodeDB.ids().has(ep_id) and cleared >= 1 and cleared <= EpisodeDB.scene_count(ep_id):
		key = scene_key(EpisodeDB.get_episode(ep_id), cleared - 1)
	data["resume"] = {"ep": ep_id, "cleared": cleared, "key": key, "guess": guess}
	save()


## ep_id の つづきを 消す（"" なら どの 話でも）
func clear_resume(ep_id := "") -> void:
	if not data["resume"].is_empty() and (ep_id == "" or data["resume"].get("ep", "") == ep_id):
		data["resume"] = {}
		save()


func steer_guide_seen() -> bool:
	return _yes(data.get("steer_guide_seen"))


func mark_steer_guide_seen() -> void:
	if not steer_guide_seen():
		data["steer_guide_seen"] = true
		save()


func is_unlocked(ep_id: String) -> bool:
	if data["settings"].get("unlock_all", false):
		return true
	var ids: Array[String] = EpisodeDB.ids()
	var i := ids.find(ep_id)
	return i <= 0 or is_cleared(ids[i - 1])


func total_stars() -> int:
	var t := 0
	for id in EpisodeDB.ids():
		t += stars(id)
	return t


func card_key(owner_id: String, key: String) -> String:
	return owner_id + "/" + key


func card_seen(owner_id: String, key: String) -> bool:
	return data["cards_seen"].has(card_key(owner_id, key))


## 見た（読んだ）ことに する：まとめ・カルテの 紙など、読む 画面で 出した もの
func mark_card(owner_id: String, key: String) -> void:
	var k := card_key(owner_id, key)
	if not data["cards_seen"].has(k):
		data["cards_seen"].append(k)
		save()
	open_card(owner_id, key)


## ゲームの とちゅうで みつけた（ずかんに 入る。まだ 開いて いない しるし つき）。はじめて みつけたら true
func find_card(owner_id: String, key: String) -> bool:
	var k := card_key(owner_id, key)
	if data["cards_seen"].has(k):
		return false
	data["cards_seen"].append(k)
	data["cards_new"].append(k)
	save()
	return true


## みつけたが まだ 開いて いないか
func card_is_new(owner_id: String, key: String) -> bool:
	return data["cards_new"].has(card_key(owner_id, key))


## 開いて 読んだ（しるしを 消す）
func open_card(owner_id: String, key: String) -> void:
	var k := card_key(owner_id, key)
	if data["cards_new"].has(k):
		data["cards_new"].erase(k)
		save()


func setting(key: String, default = null):
	return data["settings"].get(key, default)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	save()
