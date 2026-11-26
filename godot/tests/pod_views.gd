extends Node3D
const Autopilot := preload("res://tests/autopilot.gd")
## モデル 1 体を 決まった 向きから 撮る（絵と ならべて 見くらべる ため）。
##   tools/pod_views.sh <出力フォルダ> [id]      （中で xvfb-run godot … res://tests/pod_views.tscn を 呼ぶ）
## 撮る 向き（ファイル名）：
##   front / back / side_right / front_right45 / back_right45 / top / bottom   正投影。絵と 同じ 向き（真横は 顔が 画像の 右）
##   face        パイロットの 顔の アップ（pod 用）
##   game        ゲームの カメラ（うしろ上。follow_camera.gd と 同じ 位置・画角）の 画面 そのまま
##   game_zoom   同じ 向きから 大きく
##   game_left / game_right / game_front   ゲームの カメラの まま、船が 左・右・こちらを 向いた とき
## 正投影の 向きは 原点を 写す。形（メッシュの 頂点）が わくから 出る 向き（原点が まん中に ない かべの さいぼうの たて など）だけ、形の はこの まん中を 写す。
## 光：絵と くらべる 向きは、カメラの 左上から 当たる やわらかい 白い 光（--light=studio）。game_* は level.gd の いまの 光と 同じ。
## --light=dark で 暗い ステージを まねた 光、--light=flat で 光なし（色と 焼いた 影だけ）、
## --light=shadow で ゲームの 光に 太陽の 影を 足した もの（ステージが 影を 使う ように なった ときの 見え方）に する。
## --size=2.6 で 正投影の 写す 幅（m。既定 1.72）を 変える（大きい キャラクター 用）。
## --hide=Window のように 書くと、その 名前の 部品を かくして 撮る（中を 見る とき）。--no-omni で 船の 明かり（player.gd の OmniLight）を 消す。
## --stage=mouth [--play=秒] を 書くと、モデルではなく 本物の 場所を 自動操縦で 進めてから、HUD を かくして 撮る
## （ピコの ふきだしが 船に 重なって 見えないので）。画面 全体（stage_<id>.png）と、船の まわりを 3 倍に した 絵（stage_<id>_zoom.png）。
## --enemy も 書くと、てきの まわりの 3 倍の 絵と、その てきを たたいた ときの 絵も 撮る（_shoot_enemy()）。
## てきは id と 同じ 種類（pylori など）が いれば その うち 船に いちばん 近い もの、いなければ 船に いちばん 近い てき。
## 撮る 前に 船を その てきから 約 4 m の ところへ 運び、てきの ほうを 向かせる（遠い てきは 小さすぎて 見えない）。

const VIEWS := {
	"front": [Vector3(0, 0, -1), Vector3.UP],
	"back": [Vector3(0, 0, 1), Vector3.UP],
	"side_right": [Vector3(1, 0, 0), Vector3.UP],
	"front_right45": [Vector3(1, 0, -1), Vector3.UP],
	"back_right45": [Vector3(1, 0.75, 1), Vector3.UP],
	"top": [Vector3(0, 1, 0), Vector3(0, 0, -1)],
	"bottom": [Vector3(0, -1, 0), Vector3(0, 0, -1)],
	"face": [Vector3(0.35, 0.2, -1), Vector3.UP, 0.8, Vector3(0, 0.16, -0.12)],
}
const GAME_YAW := {"game": 0.0, "game_zoom": 0.0, "game_left": 90.0, "game_right": -90.0, "game_front": 180.0}

var _model: Node3D
var _cam: Camera3D
var _env: Environment
var _sun: DirectionalLight3D
var _omni: OmniLight3D
var _floor: MeshInstance3D
var _ortho := 1.72


func _ready() -> void:
	var id := "pod"
	var out := "/tmp/pod_views/"
	var light := ""
	var only := ""
	var hide := ""
	var stage := ""
	var play := 3.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="):
			id = a.substr(8)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--light="):
			light = a.substr(8)
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--hide="):
			hide = a.substr(7)
		elif a.begins_with("--stage="):
			stage = a.substr(8)
		elif a.begins_with("--play="):
			play = float(a.substr(7))
		elif a.begins_with("--size="):
			_ortho = float(a.substr(7))
	DirAccess.make_dir_recursive_absolute(out)
	if stage != "":
		await _shoot_stage(stage, play, out, id)
		get_tree().quit()
		return
	_build()
	_model = ModelLib.character(id, 0.7)
	add_child(_model)
	for h in hide.split(",", false):
		var hn := _model.find_child(h, true, false)
		if hn is Node3D:
			(hn as Node3D).visible = false
	var names: Array = VIEWS.keys() + GAME_YAW.keys()
	for v in names:
		if only != "" and not only.split(",").has(v):
			continue
		_set_view(v, light)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var file := out.path_join("%s_%s.png" % [id, v])
		img.save_png(file)
		print("saved ", file)
	get_tree().quit()


func _build() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	add_child(_sun)
	_omni = OmniLight3D.new()
	add_child(_omni)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_floor = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	_floor.mesh = pm
	_floor.position = Vector3(0, -1.1, 0)
	add_child(_floor)


func _set_view(v: String, light: String) -> void:
	var game := GAME_YAW.has(v)
	var mode := light if light != "" else ("game" if game else "studio")
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 0.9
	_omni.visible = mode != "studio" and not OS.get_cmdline_user_args().has("--no-omni")
	_omni.light_color = Color(1.0, 0.97, 0.9)
	_omni.light_energy = 0.9
	_omni.omni_range = 12.0
	_omni.position = Vector3(0, 1.0, -0.5)
	_sun.light_color = Color(1.0, 0.97, 0.9)
	_sun.rotation_degrees = Vector3(-55, 30, 0)
	_sun.light_energy = 0.75
	_floor.visible = game
	_sun.shadow_enabled = mode == "shadow"
	if mode == "studio" or mode == "flat":
		# 絵の 背景（#E6E6E6）と 同じ 明るさ。白い 光
		_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		_env.tonemap_exposure = 1.0
		_env.background_color = Color("e6e6e6")
		_env.ambient_light_color = Color(1, 1, 1)
		_env.ambient_light_energy = 1.0 if mode == "flat" else 0.80
		_sun.light_color = Color(1, 1, 1)
		_sun.light_energy = 0.0 if mode == "flat" else 0.34
		_omni.visible = false
	elif mode == "dark":
		_env.background_color = Color(0.25, 0.1, 0.16)
		_env.ambient_light_color = Color(0.7, 0.45, 0.6)
		_env.ambient_light_energy = 0.35
		_sun.light_energy = 0.3
		_floor.material_override = ModelLib.flat_material(Color(0.45, 0.2, 0.3))
	else:
		# level.gd の _build_environment() と 同じ（口の ステージの 色）
		_env.background_color = Color(0.96, 0.78, 0.8)
		_env.ambient_light_color = Color(1, 0.9, 0.9)
		_env.ambient_light_energy = 0.55
		_floor.material_override = ModelLib.flat_material(Color("f2a0a4"))
	_model.rotation = Vector3.ZERO
	if game:
		_model.rotation.y = deg_to_rad(GAME_YAW[v])
		# follow_camera.gd：プレイヤーの 2.6 m 上を 中心に、うしろへ 7.5 m、下向き 0.33 rad
		var pitch := -0.33
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.position = Vector3(0, 2.6, 0) + Vector3(0, -sin(pitch), cos(pitch)) * 7.5
		if v == "game":
			_cam.rotation = Vector3(pitch, 0, 0)
			_cam.fov = 68.0
		else:
			_cam.look_at(Vector3.ZERO, Vector3.UP)
			_cam.fov = 14.0
		# 自分の 向きに ついて くる 明かり（player.gd）
		_omni.position = Vector3(0, 1.0, -0.5).rotated(Vector3.UP, _model.rotation.y)
	else:
		var d: Vector3 = (VIEWS[v][0] as Vector3).normalized()
		var at: Vector3 = VIEWS[v][3] if VIEWS[v].size() > 3 else Vector3.ZERO
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = VIEWS[v][2] if VIEWS[v].size() > 2 else _ortho
		_cam.position = at + d * 6.0
		_cam.look_at(at, VIEWS[v][1])
		if VIEWS[v].size() <= 3:
			# 原点を ねらって 形が わくから 出る 向き（原点が まん中に ない かべの さいぼうの 下など）だけ、
			# その 向きの 形の はこの まん中を ねらう。入る ものは 原点の まま（絵との 見くらべの 位置を かえない）
			at += _fit_shift(_cam.global_transform.basis)
			_cam.position = at + d * 6.0
			_cam.look_at(at, VIEWS[v][1])
	if mode == "studio":
		_sun.global_transform = Transform3D(_cam.global_transform.basis * Basis.from_euler(Vector3(deg_to_rad(-38), deg_to_rad(28), 0)), Vector3.ZERO)


## 正投影で 原点を ねらった ときに 形（メッシュの 頂点）が わくから 出る 向き（画面の よこ・たて）だけ、
## その 向きの 形の はばの まん中への ずれを かえす（入る 向きは 0）
func _fit_shift(b: Basis) -> Vector3:
	var half := Vector2(_cam.size * 0.5 * 16.0 / 9.0, _cam.size * 0.5)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var xf := _model.global_transform.affine_inverse() * m.global_transform
		for si in m.mesh.get_surface_count():
			for v in m.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
				var w: Vector3 = xf * v
				var q := Vector2(w.dot(b.x), w.dot(b.y))
				lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
				hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var shift := Vector3.ZERO
	for k in 2:
		if lo[k] < -half[k] or hi[k] > half[k]:
			shift += (b.x if k == 0 else b.y) * (lo[k] + hi[k]) * 0.5
	return shift


## 本物の 場所で 撮る。セーブは user://save_pod_views.json（本物の セーブを さわらない）
func _shoot_stage(stage: String, play: float, out: String, id := "") -> void:
	Game.testing = true
	var main: Node = load("res://src/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	SaveData.use_path("user://save_pod_views.json")
	SaveData.reset()
	SaveData.set_setting("volume", 0.0)
	SaveData.set_setting("touch", "off")
	SaveData.data["opening_seen"] = true
	Game.start_stage(stage)
	var waited := 0
	while (Game.level == null or not Game.level.started) and waited < 600:
		await get_tree().process_frame
		waited += 1
	var t := 0.0
	while t < play and Game.level and not Game.level.finished:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		Autopilot.drive(Game.level, get_tree())
	if Game.hud and is_instance_valid(Game.hud):
		Game.hud.visible = false
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join("stage_%s.png" % stage))
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var cam := get_viewport().get_camera_3d()
	if player and cam:
		var c := Vector2i(cam.unproject_position(player.global_position))
		var r := Rect2i(c - Vector2i(120, 100), Vector2i(240, 200)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var zoom := img.get_region(r)
		zoom.resize(r.size.x * 3, r.size.y * 3, Image.INTERPOLATE_NEAREST)
		zoom.save_png(out.path_join("stage_%s_zoom.png" % stage))
	if OS.get_cmdline_user_args().has("--enemy"):
		await _shoot_enemy(stage, out, cam, id)
	print("saved ", out.path_join("stage_%s.png" % stage))


## --enemy：撮る 前に 船を てきから この m の ところへ 運ぶ
const ENEMY_NEAR := 4.0


## --enemy：えらんだ てきの まわりを 3 倍に した 絵（stage_<id>_enemy.png）と、
## その てきを 1 回 たたいた あとの 絵（_hit：時間を 1/20 に して ゲームの 0.1 秒あと。HP 1 なら やられて ふくらむ ところ／
## _gone：のこりの HP を たたいて 40 フレームあと）。切りとる 場所は いつも その てきの いる（いた）ところ。
func _shoot_enemy(stage: String, out: String, cam: Camera3D, id: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		print("saved nothing: no ship")
		return
	var best: Node3D = null
	var bd := INF
	for want_kind in [true, false]:
		for e in get_tree().get_nodes_in_group("enemy"):
			var en := e as Node3D
			if en == null or not en.get("alive") or (want_kind and en.get("kind") != id):
				continue
			var d := en.global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				best = en
		if best != null:
			break
	if best == null:
		print("saved nothing: no enemy in the place")
		return
	# 船を てきから ENEMY_NEAR m の ところへ。いまの 船の ほうから、かべに あたらない 向きを さがす
	var from: Vector3 = player.global_position - best.global_position
	from.y = 0.0
	from = from.normalized() if from.length() > 0.1 else Vector3.BACK
	var space := get_viewport().get_world_3d().direct_space_state
	var dir := from
	for k in 12:
		var a := deg_to_rad(30.0 * ((k + 1) / 2) * (1 if k % 2 == 0 else -1))
		var c := from.rotated(Vector3.UP, a)
		var q := PhysicsRayQueryParameters3D.create(best.global_position + Vector3.UP * 0.5, best.global_position + Vector3.UP * 0.5 + c * (ENEMY_NEAR + 1.5), 1)
		if space.intersect_ray(q).is_empty():
			dir = c
			break
	player.autopilot_target = Vector3.INF
	player.autopilot_shoot = false
	player.control_enabled = false
	player.invulnerable = 1.0e6
	player.velocity = Vector3.ZERO
	player.heading = -dir
	# 撮り おわる まで てきを その 場に とめる（まわる てき（ピロリきん）が はなれて いかない ように）。たたく ときに もどす
	best.set_physics_process(false)
	for i in 30:
		# うく 高さが おちつく まで、よこの 位置は とめて おく（さかで すべらない ように）
		var to: Vector3 = best.global_position + dir * ENEMY_NEAR
		player.global_position = Vector3(to.x, player.global_position.y if i > 0 else best.global_position.y, to.z)
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
	# 船を とめ、行き先の 矢印を かくす（矢印が てきの 上に 重なって 見えない ため）
	player.set_physics_process(false)
	player.arrow.visible = false
	var camn = player.get("camera")
	if camn != null and camn.has_method("snap_to_target"):
		camn.snap_to_target()
	for i in 4:
		await get_tree().process_frame
	cam = get_viewport().get_camera_3d()
	var flat: Vector3 = best.global_position - player.global_position
	print("saved: enemy %s at %.1f m from the ship (%.1f m across, %.1f m up), %.1f m from the camera" % [best.get("kind"), flat.length(), Vector2(flat.x, flat.z).length(), flat.y, best.global_position.distance_to(cam.global_position)])
	var at := best.global_position
	for s in [["enemy", 0], ["hit", 1], ["gone", 40]]:
		if s[0] == "hit":
			# 撮影は 1 フレームが 長いので、時間を ゆっくりに して ふくらむ ところを 撮る
			Engine.time_scale = 0.05
			best.set_physics_process(true)
			best.call("take_hit", 1, best.global_position - dir)
		elif s[0] == "gone":
			Engine.time_scale = 1.0
			if is_instance_valid(best) and best.get("alive"):
				best.call("take_hit", int(best.get("hp")), best.global_position - dir)
		# hit は ゲームの 時間で 0.1 秒（やられた てきが いちばん ふくらむ ころ）。撮影の 1 フレームは 長さが ばらつく ので 時間で 数える
		var waited := 0.0
		var n := 0
		while n < int(s[1]) + 1 or (s[0] == "hit" and waited < 0.1 and n < 400):
			await get_tree().process_frame
			waited += get_process_delta_time()
			n += 1
			if is_instance_valid(best):
				at = best.global_position
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var c := Vector2i(cam.unproject_position(at))
		var r := Rect2i(c - Vector2i(80, 70), Vector2i(160, 140)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var crop := img.get_region(r)
		crop.resize(r.size.x * 3, r.size.y * 3, Image.INTERPOLATE_NEAREST)
		crop.save_png(out.path_join("stage_%s_%s.png" % [stage, s[0]]))
		print("saved %s: %s at screen %s, alive=%s" % [s[0], best.get("kind") if is_instance_valid(best) else "(freed)", c, best.get("alive") if is_instance_valid(best) else false])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
