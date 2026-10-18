class_name Mission
## ひとつのミッション（やっつける・あつめる・とどける・おうえん・たどりつく など）。

signal progressed(m: Mission)
signal completed(m: Mission)

var type := "defeat"
var target := ""
var count := 1
var current := 0
var text := ""
var done := false


static func from_dict(d: Dictionary) -> Mission:
	var m := Mission.new()
	m.type = d.get("type", "defeat")
	m.target = d.get("target", "")
	m.count = int(d.get("count", 1))
	m.text = d.get("text", "")
	return m


func add(n := 1) -> void:
	if done:
		return
	current = mini(current + n, count)
	progressed.emit(self)
	if current >= count:
		done = true
		completed.emit(self)


func label() -> String:
	if type == "reach":
		return text
	return "%s  %d / %d" % [text, current, count]


func is_reach() -> bool:
	return type == "reach"
