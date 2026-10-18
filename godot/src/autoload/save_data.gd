extends Node
## セーブデータ（user://save.json）。星・クリア・見たカード・設定。

const PATH := "user://save.json"

var data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()


func _defaults() -> Dictionary:
	return {
		"version": 1,
		"stars": {},          # stage_id -> int(0..3)
		"cleared": [],        # stage_id の配列
		"cards_seen": [],     # "stage_id/key" の配列
		"story_seen": false,
		"settings": {"volume": 0.8, "touch": "auto", "unlock_all": false},
	}


func load_data() -> void:
	data = _defaults()
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for k in parsed.keys():
					if k == "settings" and parsed[k] is Dictionary:
						for sk in parsed[k].keys():
							data["settings"][sk] = parsed[k][sk]
					else:
						data[k] = parsed[k]


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func reset() -> void:
	data = _defaults()
	save()


func stars(stage_id: String) -> int:
	return int(data["stars"].get(stage_id, 0))


func record_clear(stage_id: String, star_count: int) -> void:
	if not data["cleared"].has(stage_id):
		data["cleared"].append(stage_id)
	data["stars"][stage_id] = max(stars(stage_id), star_count)
	save()


func is_cleared(stage_id: String) -> bool:
	return data["cleared"].has(stage_id)


func is_unlocked(stage_id: String) -> bool:
	if data["settings"].get("unlock_all", false):
		return true
	var ids: Array[String] = StageDB.stage_ids()
	var i := ids.find(stage_id)
	if i <= 0:
		return true
	return is_cleared(ids[i - 1])


func total_stars() -> int:
	var t := 0
	for v in data["stars"].values():
		t += int(v)
	return t


func card_key(stage_id: String, key: String) -> String:
	return stage_id + "/" + key


func card_seen(stage_id: String, key: String) -> bool:
	return data["cards_seen"].has(card_key(stage_id, key))


func mark_card(stage_id: String, key: String) -> void:
	var k := card_key(stage_id, key)
	if not data["cards_seen"].has(k):
		data["cards_seen"].append(k)
		save()


func setting(key: String, default = null):
	return data["settings"].get(key, default)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	save()
