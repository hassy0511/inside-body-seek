extends Node
## セーブデータ（user://save.json）。カルテごとの ほし・つづき・見た カード・設定。version 2。

var path := "user://save.json"
var data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()


func _defaults() -> Dictionary:
	return {
		"version": 2,
		"episodes": {},        # ep_id -> {"clear": bool, "quiz": bool, "nd": [bool, …]}（nd[i] ＝ 場面 i を ハートを へらさずに クリアした ことが ある）
		"resume": {},          # とちゅうの カルテ：{"ep": id, "cleared": おえた 場面の 数（1〜）, "guess": さいしょの よそう}。無ければ 空
		"cards_seen": [],      # "場所id/key" と "epNN/karte"
		"opening_seen": false,
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
	if ver != 2:
		# v1（ステージごとの ほし）や 知らない 版：ほしと クリアは 引きつがない。元の ファイルは 写して のこす
		DirAccess.copy_absolute(path, "%s.v%d.json" % [path.get_basename(), ver])
		save()
		return
	if parsed.get("opening_seen") is bool:
		data["opening_seen"] = parsed["opening_seen"]
	if parsed.get("episodes") is Dictionary:
		for id in parsed["episodes"].keys():
			var e = parsed["episodes"][id]
			if e is Dictionary:
				var nd: Array = []
				if e.get("nd") is Array:
					for v in e["nd"]:
						nd.append(_yes(v))
				data["episodes"][String(id)] = {"clear": _yes(e.get("clear")), "quiz": _yes(e.get("quiz")), "nd": nd}
	var r = parsed.get("resume")
	if r is Dictionary and r.get("ep") is String and typeof(r.get("cleared")) in [TYPE_INT, TYPE_FLOAT]:
		var n := EpisodeDB.scene_count(r["ep"])   # 知らない 話なら 0
		if int(r["cleared"]) >= 1 and int(r["cleared"]) <= n:
			data["resume"] = {"ep": r["ep"], "cleared": int(r["cleared"]), "guess": r["guess"] if r.get("guess") is String else ""}


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
		data["episodes"][ep_id] = {"clear": false, "quiz": false, "nd": []}
	var e: Dictionary = data["episodes"][ep_id]
	e["nd"].resize(EpisodeDB.scene_count(ep_id))
	for i in e["nd"].size():
		e["nd"][i] = _yes(e["nd"][i])
	return e


## 場面ごと：ハートを へらさずに クリアした ことが あるか
func scene_flags(ep_id: String) -> Array[bool]:
	var out: Array[bool] = []
	var nd: Array = data["episodes"].get(ep_id, {}).get("nd", [])
	for i in EpisodeDB.scene_count(ep_id):
		out.append(i < nd.size() and _yes(nd[i]))
	return out


## [カルテ かんせい, 全部の 場面で ハートを へらさずに, クイズ せいかい]。2 つめ・3 つめは クリアして はじめて つく
func star_flags(ep_id: String) -> Array[bool]:
	var e: Dictionary = data["episodes"].get(ep_id, {})
	var clear: bool = e.get("clear", false)
	var sf := scene_flags(ep_id)
	return [clear, clear and not sf.is_empty() and not sf.has(false), clear and e.get("quiz", false)]


func stars(ep_id: String) -> int:
	return star_flags(ep_id).count(true)


func is_cleared(ep_id: String) -> bool:
	return data["episodes"].get(ep_id, {}).get("clear", false)


## 場面を クリアした（ほしの 印は 回を またいで たまる。1 回 とった 印は 消えない）
func record_scene(ep_id: String, scene: int, no_damage: bool) -> void:
	var e := _entry(ep_id)
	if scene >= 0 and scene < e["nd"].size():
		e["nd"][scene] = e["nd"][scene] or no_damage
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
	data["resume"] = {"ep": ep_id, "cleared": cleared, "guess": guess}
	save()


## ep_id の つづきを 消す（"" なら どの 話でも）
func clear_resume(ep_id := "") -> void:
	if not data["resume"].is_empty() and (ep_id == "" or data["resume"].get("ep", "") == ep_id):
		data["resume"] = {}
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


func mark_card(owner_id: String, key: String) -> void:
	var k := card_key(owner_id, key)
	if not data["cards_seen"].has(k):
		data["cards_seen"].append(k)
		save()


func setting(key: String, default = null):
	return data["settings"].get(key, default)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	save()
