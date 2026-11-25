extends Control
## ものしりカードの 3D の 絵（card.gd の _model_picture）を、キャラクターの GLB ぜんぶ について ならべた 1 枚に する。
##   tools/card_sheet.sh <出力.png> [--angles=-50,0,50] [--still] [--size=320x400]
## 1 行 ＝ 1 体（godot/assets/models/characters/*.glb の 名前じゅん）、1 列 ＝ 1 つの 向き（絵の まわる 軸の 角度。0 ＝ 顔が 正面）。
## --still を 書くと、さいごの 列に 止まった 絵（タイルと 同じ、spin = false の まま）を 足す。
## 絵の まわりの うすい わくが カードの 絵の わく。ここから 出た ところは カードでは 切れる。

const CardPopup := preload("res://src/ui/card.gd")
const PAD := 8


func _ready() -> void:
	var out := "/tmp/card_sheet.png"
	var angles: Array[float] = [-50.0, 0.0, 50.0]
	var still := false
	var size := Vector2i(320, 400)   # カードの 絵の わく（card.gd の PIC_SIZE）
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--angles="):
			angles.clear()
			for s in a.substr(9).split(",", false):
				angles.append(float(s))
		elif a == "--still":
			still = true
		elif a.begins_with("--size="):
			var p := a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	var kinds: Array[String] = []
	for f in DirAccess.get_files_at("res://assets/models/characters/"):
		if f.ends_with(".glb"):
			kinds.append(f.get_basename())
	kinds.sort()
	var cols := angles.size() + (1 if still else 0)
	var sheet := Image.create(PAD + cols * (size.x + PAD), PAD + kinds.size() * (size.y + PAD), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.55, 0.5, 0.52))
	for r in kinds.size():
		var pics: Array = []
		for c in cols:
			var pic: Control = CardPopup._model_picture(kinds[r], Vector2(size), false)
			pic.position = Vector2(c * (size.x + 4), 0)
			add_child(pic)
			pics.append(pic)
		await get_tree().process_frame
		for c in angles.size():
			var pv := _pivot(pics[c])
			if pv:
				pv.rotation.y = deg_to_rad(angles[c])
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		for c in cols:
			var sv := pics[c].find_children("*", "SubViewport", true, false)[0] as SubViewport
			var img := sv.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var bg := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
			bg.fill(Color(1.0, 0.98, 0.95))
			if img.get_size() != size:
				img.resize(size.x, size.y)
			bg.blend_rect(img, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
			sheet.blit_rect(bg, Rect2i(Vector2i.ZERO, size), Vector2i(PAD + c * (size.x + PAD), PAD + r * (size.y + PAD)))
		for p in pics:
			p.queue_free()
		print("row ", r, " ", kinds[r])
	sheet.save_png(out)
	print("saved ", out, " rows: ", ", ".join(PackedStringArray(kinds)))
	get_tree().quit()


## 絵の 中で まわる 台（モデルの 親）
static func _pivot(pic: Control) -> Node3D:
	var sv := pic.find_children("*", "SubViewport", true, false)[0] as SubViewport
	for c in sv.get_children():
		if c is Node3D and not (c is Camera3D or c is Light3D or c is WorldEnvironment):
			return c
	return null
