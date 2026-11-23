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
## 光：絵と くらべる 向きは、カメラの 左上から 当たる やわらかい 白い 光（--light=studio）。game_* は level.gd の いまの 光と 同じ。
## --light=dark で 暗い ステージを まねた 光、--light=flat で 光なし（色と 焼いた 影だけ）、
## --light=shadow で ゲームの 光に 太陽の 影を 足した もの（ステージが 影を 使う ように なった ときの 見え方）に する。
## --hide=Window のように 書くと、その 名前の 部品を かくして 撮る（中を 見る とき）。--no-omni で 船の 明かり（player.gd の OmniLight）を 消す。
## --stage=mouth [--play=秒] を 書くと、モデルではなく 本物の 場所を 自動操縦で 進めてから、HUD を かくして 撮る
## （ピコの ふきだしが 船に 重なって 見えないので）。画面 全体（stage_<id>.png）と、船の まわりを 3 倍に した 絵（stage_<id>_zoom.png）。

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
	DirAccess.make_dir_recursive_absolute(out)
	if stage != "":
		await _shoot_stage(stage, play, out)
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
		_cam.size = VIEWS[v][2] if VIEWS[v].size() > 2 else 1.72
		_cam.position = at + d * 6.0
		_cam.look_at(at, VIEWS[v][1])
	if mode == "studio":
		_sun.global_transform = Transform3D(_cam.global_transform.basis * Basis.from_euler(Vector3(deg_to_rad(-38), deg_to_rad(28), 0)), Vector3.ZERO)


## 本物の 場所で 撮る。セーブは user://save_pod_views.json（本物の セーブを さわらない）
func _shoot_stage(stage: String, play: float, out: String) -> void:
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
	print("saved ", out.path_join("stage_%s.png" % stage))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
