class_name Level
extends Node3D
## ステージ本体（カルテの 場面 1 つ、または 場所モードの 場所 1 つ）。
## 1. GLB（blender/ で生成）を読み、MK_ で始まる Empty をスポーン位置として使う
## 2. ミッションを組み立てて進行を見る
## 3. はじめて出会ったものの「ものしりカード」を出す
##
## Level は カルテ（話）を 知らない。setup() に わたされた stage 辞書だけを 読む：
## 場所の 辞書（StageDB）か、それに 場面の 上書きを 重ねた もの（EpisodeDB.scene_stage()）。
## 場面が 上書きできる キー：missions・intro・hints・spawn（skip／swap）・arrow・goal_say・clear_say・flow_speed・bgm など。
## "pass": true（とおりみち）の ときは、やる ことも あぶない ものも 出さない（PASS_KEEP の マーカーだけ）。ゴールは はじめから 開く。
##
## マーカー名のきまり: MK_<種類>_<名前>[_<番号>]
##   MK_player            プレイヤーの開始位置
##   MK_goal              ゴール
##   MK_checkpoint_1      チェックポイント
##   MK_path_000 ...      道（くだステージの中心線。番号順）
##   MK_enemy_<kind>_1    敵      (mushiba / pylori / akudama / virus)
##   MK_boss_<kind>       ボス    (boss_virus)
##   MK_friend_<kind>_1   なかま  (wallcell / zendama / rbc / wbc)
##   MK_pickup_<kind>_1   ひろうもの (nutrient / heart_item)
##   MK_deliver_<kind>_1  とどけ先 (villus)
##   MK_hazard_acid_r5_1  いえきの いけ（r のあとは半径）
##   MK_gate_1            べん（ドア）。向きは Empty の回転
##   MK_neuron_1          しんけい
##   MK_sign_<key>        かんばん（文字は SIGN_TEXT）
##   MK_card_<key>        近づくとカードが出るだけの点

signal cleared(stage_id: String, no_damage: bool)
signal missions_changed
signal hearts_changed(hearts: int)

const PlayerScene := preload("res://src/player/player.tscn")
const FollowCameraScript := preload("res://src/player/follow_camera.gd")
const EnemyScript := preload("res://src/entities/enemy.gd")
const BossScript := preload("res://src/entities/boss.gd")
const FriendScript := preload("res://src/entities/friend.gd")
const PickupScript := preload("res://src/entities/pickup.gd")
const DeliverScript := preload("res://src/entities/deliver_zone.gd")
const GoalScript := preload("res://src/entities/goal.gd")
const CheckpointScript := preload("res://src/entities/checkpoint.gd")
const HazardScript := preload("res://src/entities/hazard_pool.gd")
const PeristalsisScript := preload("res://src/level/peristalsis.gd")
const GateScript := preload("res://src/entities/valve_gate.gd")
const NeuronScript := preload("res://src/entities/neuron.gd")
const LevelPathScript := preload("res://src/level/level_path.gd")
const MissionScript := preload("res://src/level/mission.gd")

## spawn の ルール（skip／swap）で かえられない マーカーの 種類（EpisodeDB.SPAWN_LOCKED と 同じ）
const SPAWN_LOCKED := ["player", "goal", "path", "checkpoint"]
## とおりみちで 出す マーカーの 種類（てき・ボス・いえき・ドア・しんけい・なかま・とどけ先は 出さない）。
## ひろうもの は げんきの つぶ（heart_item）だけ（ミッションが 数える ものは 出さない）
const PASS_KEEP := ["player", "goal", "path", "checkpoint", "sign", "card"]
## マーカー名に 種類の ことばが 無い ときの 種類（MK_enemy_1 → mushiba）
const DEFAULT_KIND := {"enemy": "mushiba", "friend": "zendama", "pickup": "nutrient", "deliver": "villus"}

const SIGN_TEXT := {
	"ra": "みぎの しんぼう", "rv": "みぎの しんしつ", "la": "ひだりの しんぼう", "lv": "ひだりの しんしつ",
	"lung": "→ はいへ", "aorta": "だいどうみゃく\n（からだじゅうへ）", "start": "スタート", "goal": "ゴール", "heart": "→ しんぞうへ",
	"vein": "だいじょうみゃく\n（からだから）", "pa": "はいどうみゃく\n（はいへ）", "pv": "はいじょうみゃく\n（はいから）",
	"throat": "のど", "trachea": "きかん（くうきの みち）", "esophagus": "しょくどう（たべものの みち）",
}

var stage: Dictionary = {}
var stage_id := ""
var flow_speed := 0.0
var player: Player
var camera: Node3D
var path: LevelPath
var missions: Array[Mission] = []
var goal: Goal = null
var env: Node3D = null
var started := false
var finished := false
var elapsed := 0.0
var damage_taken := false
var respawn_point := Vector3.ZERO
var spawn_point := Vector3.ZERO
var markers: Array[Dictionary] = []
var card_points: Array[Dictionary] = []   # {key, position, node}
var neurons: Array[Neuron] = []
var gates: Array[ValveGate] = []
var _hints: Array = []
var _card_cd := 0.0
var _card_check := 0.0
var peristalsis: Peristalsis = null   # しょくどうの なみ（場所の "waves" が ある とき）
var _seq: Array[int] = []
var _seq_input := 0
var _seq_round := 0
var _seq_showing := false
var _seq_input_started := 0.0
var _seq_pending := false
var _spawn_heading := Vector3.FORWARD
var _sign_font: Font
var data_warnings: Array[String] = []   # データの まちがい（テストが 失敗に する）


func setup(s: Dictionary) -> void:
	stage = s
	stage_id = s["id"]
	flow_speed = float(s.get("flow_speed", 0.0))
	_hints = s.get("hints", []).duplicate()


func _ready() -> void:
	_sign_font = Game.font_bold
	_build_environment()
	_load_env()
	_collect_markers()
	_build_path()
	_spawn_all()
	_build_missions()
	_spawn_player()
	if stage.has("waves") and path.is_valid():
		peristalsis = PeristalsisScript.new()
		peristalsis.setup(self)
		add_child(peristalsis)


## すぐ 遊びはじめる（場所の カードは クリアの あとに Game が 出す。遊ぶ 前の 文を へらす）
func begin() -> void:
	started = true
	var intro: String = stage.get("intro", "")
	if intro != "":
		say_story(intro, 6.0)


## 読む 時間：1 字 0.25 秒（6〜7 さいの 読む はやさ）。base より 短くは しない
static func read_time(text: String, base: float) -> float:
	return maxf(base, text.length() * 0.25)


## 物語の ひとこと（intro・each_say・done_say・goal_say・clear_say）。長さに 合わせて 出し、出てから 2 秒は ほかの 文に 上書きさせない
func say_story(text: String, base := 3.0) -> void:
	Game.say(text, read_time(text, base), 2.0)


# ---------------------------------------------------------------- 環境
func _build_environment() -> void:
	# 光・きり・たいよう。場所の "look" で 変えられる（無ければ いままでの 値。stage_look.gd）
	StageLook.environment(self, stage)


func _load_env() -> void:
	env = ModelLib.instance("stages/" + stage["env"])
	if env == null:
		push_warning("stage model not found: %s (fallback arena)" % stage["env"])
		env = _fallback_env()
	env.name = "Env"
	if is_pass():
		_clean_spots(env, stage.get("pass_clean", {}))
	add_child(env)
	_ensure_collisions(env)
	StageLook.apply(env, stage)


## とおりみちで 見せない しるし（むしばの あな）：まるの 中の 頂点の 色を、まるの まわり（半径〜半径＋1 m）の 色の 平均に ぬりかえる。
## メッシュは 写しを 作って かえる（ほかの 場面の GLB は そのまま）
func _clean_spots(root: Node3D, spots: Dictionary) -> void:
	for mesh_name in spots.keys():
		var mi := root.find_child(String(mesh_name), true, false) as MeshInstance3D
		if mi == null or not (mi.mesh is ArrayMesh):
			data_warnings.append("%s: pass_clean の「%s」が GLB に ない" % [stage_id, mesh_name])
			continue
		var src := mi.mesh as ArrayMesh
		var out := ArrayMesh.new()
		for si in src.get_surface_count():
			var arrays := src.surface_get_arrays(si)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_COLOR] is PackedColorArray and not (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).is_empty():
				var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				for spot in spots[mesh_name]:
					var c: Vector3 = spot[0]
					var r := float(spot[1])
					var sum := Color(0, 0, 0, 0)
					var cnt := 0
					for k in pos.size():
						var d := pos[k].distance_to(c)
						if d >= r and d < r + 1.0:
							sum += col[k]
							cnt += 1
					if cnt == 0:
						continue
					var ring := sum / float(cnt)
					for k in pos.size():
						var d := pos[k].distance_to(c)
						if d < r:
							col[k] = col[k].lerp(ring, 1.0 - smoothstep(r * 0.75, r, d))
				arrays[Mesh.ARRAY_COLOR] = col
			out.add_surface_from_arrays(src.surface_get_primitive_type(si), arrays)
			out.surface_set_material(si, src.surface_get_material(si))
			out.surface_set_name(si, src.surface_get_name(si))
		mi.mesh = out


## GLB が無いときの代わりの広場（平らな円＋かべ）。マーカーも適当に置く。
func _fallback_env() -> Node3D:
	var root := Node3D.new()
	var floor_mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 40.0
	cm.bottom_radius = 40.0
	cm.height = 1.0
	floor_mi.mesh = cm
	floor_mi.position = Vector3(0, -0.5, 0)
	floor_mi.material_override = ModelLib.flat_material(stage.get("fog", Color(0.9, 0.7, 0.7)).darkened(0.2))
	root.add_child(floor_mi)
	var wall := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 38.0
	tm.outer_radius = 44.0
	wall.mesh = tm
	wall.position = Vector3(0, 0, 0)
	wall.material_override = ModelLib.flat_material(stage.get("fog", Color(0.9, 0.7, 0.7)).darkened(0.35))
	root.add_child(wall)
	var mk := func(n: String, p: Vector3):
		var m := Node3D.new()
		m.name = n
		m.position = p
		root.add_child(m)
	mk.call("MK_player", Vector3(0, 0, 20))
	mk.call("MK_goal", Vector3(0, 0, -30))
	mk.call("MK_checkpoint_1", Vector3(0, 0, -5))
	var i := 1
	for m in stage.get("missions", []):
		var kind: String = m.get("target", "")
		var n: int = int(m.get("count", 1))
		var prefix := ""
		match m.get("type", ""):
			"defeat": prefix = "MK_enemy_"
			"cheer": prefix = "MK_friend_"
			"collect": prefix = "MK_pickup_"
			"deliver": prefix = "MK_deliver_"; n = 1
			"boss": prefix = "MK_boss_"; n = 1
			"sequence": prefix = "MK_neuron_"; kind = ""; n = 5
			"gate": prefix = "MK_gate_"; kind = ""; n = 4
		if prefix == "":
			continue
		for j in n:
			var a := TAU * (i * 0.37 + j * 0.13)
			var r := randf_range(8.0, 26.0)
			var nm := prefix + (kind + "_" if kind != "" else "") + str(j + 1)
			mk.call(nm, Vector3(cos(a) * r, 0, sin(a) * r))
			i += 1
	for j in 12:
		var a := TAU * j / 12.0
		mk.call("MK_path_%03d" % j, Vector3(cos(a) * 20.0, 0, sin(a) * 20.0))
	return root


func _ensure_collisions(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name.begins_with("NC_") or m.mesh == null:
			continue
		var has_body := false
		for c in m.get_children():
			if c is StaticBody3D:
				has_body = true
		if not has_body:
			m.create_trimesh_collision()
		for c in m.get_children():
			if c is StaticBody3D:
				(c as StaticBody3D).collision_layer = 1
				(c as StaticBody3D).collision_mask = 0


func _collect_markers() -> void:
	markers.clear()
	var rules: Dictionary = stage.get("spawn", {})
	var used := {}
	for n in env.find_children("MK_*", "Node3D", true, false):
		(n as Node3D).visible = false
		var mk_name := _apply_spawn_rules(String(n.name), rules, used)
		if mk_name == "":
			continue
		var parts: PackedStringArray = mk_name.split("_")
		if parts.size() < 2:
			continue
		var kind := String(parts[1])
		var rest: Array = Array(parts.slice(2))
		if is_pass() and not PASS_KEEP.has(kind) and not (kind == "pickup" and _kind_and_index(rest, DEFAULT_KIND["pickup"])["kind"] == "heart_item"):
			continue
		markers.append({"node": n, "kind": kind, "rest": rest, "name": mk_name, "position": (n as Node3D).global_position, "basis": (n as Node3D).global_transform.basis})
	for p in rules.get("skip", []) + rules.get("swap", {}).keys():
		if not used.has(p):
			data_warnings.append("%s: spawn の「%s」に 合う マーカーが ない" % [stage_id, p])


## 場面の spawn ルールを マーカー名に かける。"" を 返したら その マーカーは 出さない。
##   "skip": ["enemy_pylori"]                       名前が この 語で 始まる マーカーを 出さない
##   "swap": {"friend_rbc_2": "friend_wbc"}        種類を 読みかえる（番号は のこる：MK_friend_wbc_2）
## 合わせかた：「MK_」を 取った 名前が p と 同じ、または p + "_" で 始まる（spawn_rule_matches）。
## えいようの マーカーは 番号が 2 つ（MK_pickup_nutrient_<しゅるい>_<通し番号>）。"pickup_nutrient_1" は しゅるい 1 の 全部に 合う。
## player・goal・path・checkpoint は かえられない（SPAWN_LOCKED）。used には 合った ルールを 書きこむ。
static func _apply_spawn_rules(mk_name: String, rules: Dictionary, used: Dictionary) -> String:
	var key := mk_name.substr(3)
	if rules.is_empty() or key.get_slice("_", 0) in SPAWN_LOCKED:
		return mk_name
	for p in rules.get("skip", []):
		if spawn_rule_matches(key, p):
			used[p] = true
			return ""
	var swap: Dictionary = rules.get("swap", {})
	for p in swap.keys():
		if spawn_rule_matches(key, p):
			used[p] = true
			# 番号は のこす：前方一致なら のこり全部（"_2"）、ぴったり 同じなら さいごの 番号
			var tail := key.substr(String(p).length())
			var last := key.get_slice("_", key.get_slice_count("_") - 1)
			if tail == "" and last.is_valid_int():
				tail = "_" + last
			return "MK_" + String(swap[p]) + tail
	return mk_name


## spawn の ルール p が マーカー（「MK_」を 取った 名前 key）に 合うか：同じ、または p + "_" で 始まる
static func spawn_rule_matches(key: String, p: String) -> bool:
	return key == p or key.begins_with(p + "_")


## とおりみち（とおるだけの 場面）か
func is_pass() -> bool:
	var v = stage.get("pass", false)
	return v is bool and v


func _markers_of(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in markers:
		if m["kind"] == kind:
			out.append(m)
	out.sort_custom(func(a, b): return a["name"] < b["name"])
	return out


func _build_path() -> void:
	path = LevelPathScript.new()
	var pts: Array = []
	for m in _markers_of("path"):
		pts.append(m["position"])
	if pts.size() < 2:
		var ps := _markers_of("player")
		var gs := _markers_of("goal")
		if ps.size() > 0 and gs.size() > 0:
			pts = [ps[0]["position"], gs[0]["position"]]
	path.setup(pts)


# ---------------------------------------------------------------- スポーン
func _spawn_all() -> void:
	var cards: Dictionary = stage.get("cards", {})
	for m in markers:
		var kind: String = m["kind"]
		var rest: Array = m["rest"]
		var pos: Vector3 = m["position"]
		match kind:
			"player":
				spawn_point = pos
				respawn_point = pos
			"goal":
				goal = GoalScript.new()
				goal.level = self
				goal.position = pos
				add_child(goal)
				goal.reached.connect(_on_goal_reached)
				_add_card_point("goal", pos, goal)
			"checkpoint":
				var cp := CheckpointScript.new()
				cp.level = self
				cp.position = pos
				add_child(cp)
				cp.activated.connect(func(c):
					if not path.is_valid() or path.progress_at(c.global_position) >= path.progress_at(respawn_point):
						respawn_point = c.global_position
					Game.say_soft("チェックポイント！ ここから やりなおせるよ。", 2.5))
			"enemy":
				spawn_enemy_at(_kind_and_index(rest, DEFAULT_KIND["enemy"])["kind"], pos)
			"boss":
				var b := BossScript.new()
				b.level = self
				b.position = pos
				add_child(b)
				b.died.connect(_on_enemy_died)
				_add_card_point("boss_virus", pos, b)
			"friend":
				var fk: String = _kind_and_index(rest, DEFAULT_KIND["friend"])["kind"]
				var f := FriendScript.create(fk)
				f.level = self
				f.position = pos
				add_child(f)
				f.cheered.connect(_on_friend_cheered)
				_add_card_point(fk, pos, f)
			"pickup":
				var ki := _kind_and_index(rest, DEFAULT_KIND["pickup"])
				var pk: String = ki["kind"]
				var idx: int = ki["index"]
				var p := PickupScript.create(pk, idx)
				p.level = self
				p.position = pos
				add_child(p)
				p.collected.connect(_on_pickup_collected)
				_add_card_point(pk, pos, p)
			"deliver":
				var dk: String = _kind_and_index(rest, DEFAULT_KIND["deliver"])["kind"]
				var d := DeliverScript.new()
				d.kind = dk
				d.level = self
				d.position = pos
				add_child(d)
				d.delivered.connect(_on_delivered)
				_add_card_point(dk, pos, d)
			"hazard":
				var hk := String(rest[0]) if rest.size() > 0 else "acid"
				var h := HazardScript.new()
				h.kind = hk
				for r in rest:
					var rs := String(r)
					if rs.begins_with("r") and rs.substr(1).is_valid_float():
						h.radius = float(rs.substr(1))
				h.level = self
				h.position = pos
				add_child(h)
				_add_card_point(hk, pos, h)
			"gate":
				var g := GateScript.new()
				g.index = gates.size()
				g.level = self
				g.position = pos
				add_child(g)
				g.global_transform.basis = m["basis"]
				g.passed.connect(_on_gate_passed)
				gates.append(g)
				_add_card_point("valve", pos, g)
			"neuron":
				var nn := NeuronScript.new()
				nn.index = neurons.size()
				nn.level = self
				nn.position = pos
				add_child(nn)
				nn.touched.connect(_on_neuron_touched)
				neurons.append(nn)
				_add_card_point("neuron", pos, nn)
			"sign":
				var key := String(rest[0]) if rest.size() > 0 else ""
				_spawn_sign(SIGN_TEXT.get(key, key), pos)
			"card":
				var ck := String(rest[0]) if rest.size() > 0 else ""
				if cards.has(ck):
					_add_card_point(ck, pos, null)
			"path":
				pass
	if goal == null and path.is_valid():
		goal = GoalScript.new()
		goal.level = self
		goal.position = path.end()
		add_child(goal)
		goal.reached.connect(_on_goal_reached)


func spawn_enemy_at(kind: String, pos: Vector3) -> Node:
	var e := EnemyScript.create(kind)
	e.level = self
	e.position = pos
	add_child(e)
	e.died.connect(_on_enemy_died)
	_add_card_point(kind, pos, e)
	return e


## マーカー名の のこり（["heart", "item", "1"] など）を 種類と番号に分ける
static func _kind_and_index(rest: Array, default_kind: String) -> Dictionary:
	var words: Array = []
	var nums: Array = []
	for r in rest:
		if String(r).is_valid_int():
			nums.append(int(r))
		else:
			words.append(String(r))
	var kind: String = "_".join(PackedStringArray(words)) if words.size() > 0 else default_kind
	return {"kind": kind, "index": (nums[0] if nums.size() > 1 else 0), "nums": nums}


func _spawn_sign(text: String, pos: Vector3) -> void:
	if not SIGN_TEXT.values().has(text):
		push_warning("sign text not found for marker: %s" % text)
	var board := _sign_board(text)
	if board != null:
		board.position = pos + Vector3.UP * 3.0
		add_child(board)
		return
	var l := Label3D.new()
	l.text = text
	l.font = _sign_font
	l.font_size = 64
	l.pixel_size = 0.02
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1, 1, 1)
	l.outline_modulate = Color(0.3, 0.1, 0.15)
	l.outline_size = 14
	l.position = pos + Vector3.UP * 3.0
	add_child(l)


## かんばんの 板：res://assets/ui/sign_board.png（クリーム色の まるい ふきだし、下に しっぽ）に 文字を のせた 絵。
## 板は 文字の 長さに あわせて よこに のばす（まるい はしと しっぽは そのまま、あいだの まっすぐな ところだけ）。
## 板と 文字を 1 まいの 絵（SubViewport）に して から 出す（重なりの 順が くずれない）。画像が 無ければ null（文字だけの かんばん）
const SIGN_BOARD := "res://assets/ui/sign_board.png"
## 画像の 中の 板の 外形（px。2048 四方の 画像の まま）と、のばさない 部分（左の はし、しっぽ、右の はし）
const SIGN_RECT := Rect2i(421, 698, 1204, 729)
const SIGN_BODY_PX := 652.0          # しっぽを のぞいた 板の 高さ
const SIGN_PARTS := [Vector2i(0, 380), Vector2i(439, 639), Vector2i(873, 1204)]   # 左はし・しっぽ・右はし（SIGN_RECT の 中の x）
const SIGN_FILL := Vector2i(392, 428)                                             # のばす たての 帯
const SIGN_INK := Color("#5A2630")
const SIGN_EM_M := 1.28              # 文字の 大きさ m（前の 文字だけの かんばんと 同じ）
const SIGN_MAX_W := 7.0            # 板の はばの 上限 m
const SIGN_HIDE_NEAR := 4.0          # カメラから この m より 近い かんばんは 消す（画面を ふさがない）
const SIGN_SCALE := 2                # 画像を この 分の 1 に してから つかう（かるく する）
static var _sign_src: Image = null


func _sign_board(text: String) -> Sprite3D:
	if _sign_src == null:
		if not ResourceLoader.exists(SIGN_BOARD):
			return null
		var tex := load(SIGN_BOARD) as Texture2D
		if tex == null:
			return null
		_sign_src = tex.get_image().get_region(SIGN_RECT)
		_sign_src.decompress()
		_sign_src.convert(Image.FORMAT_RGBA8)
		_sign_src.resize(SIGN_RECT.size.x / SIGN_SCALE, SIGN_RECT.size.y / SIGN_SCALE, Image.INTERPOLATE_LANCZOS)
	var k := 1.0 / SIGN_SCALE
	var h := _sign_src.get_height()
	var body := SIGN_BODY_PX * k
	# 文字（板の 絵の px で）
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_override("font", _sign_font)
	lab.add_theme_font_size_override("font_size", 64)
	lab.add_theme_color_override("font_color", SIGN_INK)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ts := _sign_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 64)
	# 板の 高さ ＝ 文字の 高さ ＋ よはく。絵ごと 大きさを 変える（2 行の 板は まるい はしも 大きく なる）
	var grow := (ts.y + 64.0 * 0.8) / body
	var fixed := int((SIGN_PARTS[0].y - SIGN_PARTS[0].x + SIGN_PARTS[1].y - SIGN_PARTS[1].x + SIGN_PARTS[2].y - SIGN_PARTS[2].x) * k)
	var want := int((ts.x + body * grow * 0.75) / grow)          # 文字の よこに まるい はしの よはく
	var fill := maxi(int((want - fixed) / 2), 2)
	var img := Image.create(fixed + fill * 2, h, false, Image.FORMAT_RGBA8)
	var strip := _sign_src.get_region(Rect2i(int(SIGN_FILL.x * k), 0, int((SIGN_FILL.y - SIGN_FILL.x) * k), h))
	strip.resize(fill, h, Image.INTERPOLATE_BILINEAR)
	var x := 0
	for i in 3:
		var part: Vector2i = SIGN_PARTS[i]
		var w := int((part.y - part.x) * k)
		img.blit_rect(_sign_src, Rect2i(int(part.x * k), 0, w, h), Vector2i(x, 0))
		x += w
		if i < 2:
			img.blit_rect(strip, Rect2i(0, 0, fill, h), Vector2i(x, 0))
			x += fill
	img.resize(int(img.get_width() * grow), int(h * grow), Image.INTERPOLATE_BILINEAR)
	var vp := SubViewport.new()
	vp.name = "SignView"
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.size = img.get_size()
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.size = Vector2(img.get_size())
	vp.add_child(tr)
	lab.position = Vector2.ZERO
	lab.size = Vector2(img.get_width(), body * grow)
	vp.add_child(lab)
	var sp := Sprite3D.new()
	sp.name = "SignBoard"
	sp.add_child(vp)
	sp.texture = vp.get_texture()
	# 長い かんばんは 小さく（くだの かべに はしが うまらない ように。前は 文字だけでも はしが かくれた）
	sp.pixel_size = minf(SIGN_EM_M / 64.0, SIGN_MAX_W / float(img.get_width()))
	sp.offset = Vector2(0, (h - body) * grow * 0.5)     # 板の まんなかを マーカーの 上に（しっぽは 下に 出る）
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.modulate = Color(0.94, 0.94, 0.94)      # つやなし。光る ゴールより 明るく しない
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.visibility_range_begin = SIGN_HIDE_NEAR
	sp.visibility_range_begin_margin = 2.0
	sp.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return sp


func _add_card_point(key: String, pos: Vector3, node: Node) -> void:
	if not stage.get("cards", {}).has(key):
		return
	if SaveData.card_seen(stage_id, key):
		return
	for cp in card_points:
		if cp["key"] == key:
			# もう登録してあるときは、いちばん新しいものを指す
			if cp["node"] == null or not is_instance_valid(cp["node"]):
				cp["node"] = node
				cp["position"] = pos
			return
	card_points.append({"key": key, "position": pos, "node": node})


func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	player.level = self
	add_child(player)
	player.global_position = spawn_point + Vector3.UP * 1.0
	var ps := _markers_of("player")
	if ps.size() > 0:
		var b: Basis = ps[0]["basis"]
		var fwd := -b.z
		fwd.y = 0.0
		if fwd.length() > 0.1:
			player.heading = fwd.normalized()
	elif path.is_valid():
		player.heading = path.direction_at(spawn_point)
	camera = FollowCameraScript.new()
	camera.target = player
	camera.level = self
	camera.tube_mode = stage.get("kind", "arena") == "tube"
	add_child(camera)
	camera.snap_to_target()
	player.camera = camera
	player.hearts_changed.connect(func(h): hearts_changed.emit(h))
	player.hurt_happened.connect(func(): damage_taken = true)
	_spawn_heading = player.heading
	player.respawned.connect(func():
		if player.inventory.size() > 0:
			Game.say("ちょっと きゅうけい。ポケットの えいようは そのままだよ！", 3.0)
		else:
			Game.say("ちょっと きゅうけい。もういっかい いこう！", 3.0))


# ---------------------------------------------------------------- ミッション
func _build_missions() -> void:
	missions.clear()
	for d in stage.get("missions", []):
		var m := MissionScript.from_dict(d)
		if m.type == "sequence":
			m.count = int(d.get("count", 3))
		m.progressed.connect(_on_mission_progressed)
		m.completed.connect(_on_mission_completed)
		missions.append(m)
	_fit_missions()
	missions_changed.emit()
	_update_goal_lock()


## 出る マーカーの 数（種類 kind、その 中の 種類 sub）。spawn の ルールを かけた あとの markers から 数える。
## グループからは 数えない：前の Level の ノードは queue_free しても フレームの 終わりまで グループに のこる。
func _count_markers(kind: String, sub := "") -> int:
	var n := 0
	for m in markers:
		if m["kind"] == kind and (sub == "" or _kind_and_index(m["rest"], DEFAULT_KIND.get(kind, ""))["kind"] == sub):
			n += 1
	return n


## 出てこない ものを 数える ミッションが あると ゴールが 開かない。出る 数に 合わせ、0 なら 外す。
## 合わせた ときは data_warnings に 書く（子どもは 詰まらず、テストは 失敗に なる）。
func _fit_missions() -> void:
	var keep: Array[Mission] = []
	for m in missions:
		var have := m.count
		match m.type:
			"defeat": have = _count_markers("enemy", m.target)
			"boss": have = _count_markers("boss")
			"cheer": have = _count_markers("friend", m.target)
			"collect": have = _count_markers("pickup", m.target)
			"deliver": have = _count_markers("pickup", "nutrient") if _count_markers("deliver") > 0 else 0
			"gate": have = gates.size()
			"sequence": have = m.count if neurons.size() >= 2 else 0
		if have < m.count:
			data_warnings.append("%s: ミッション「%s」は %d こ いるが、出るのは %d こ" % [stage_id, m.text, m.count, have])
			m.count = have
		if m.count > 0 or m.is_reach():
			keep.append(m)
	missions = keep


func _mission(type: String, target := "") -> Mission:
	for m in missions:
		if m.type == type and (target == "" or m.target == target or m.target == ""):
			return m
	return null


func _on_mission_progressed(m: Mission) -> void:
	missions_changed.emit()
	if m.current < m.count and m.current >= 1 and m.current <= m.each_say.size():
		say_story(m.each_say[m.current - 1], 3.0)


func _on_mission_completed(m: Mission) -> void:
	Sfx.play("mission")
	if not m.is_reach() and not _non_reach_done():
		say_story(m.done_say if m.done_say != "" else "やったね！「%s」クリア！" % m.text, 3.5)
	_update_goal_lock()
	missions_changed.emit()


func _non_reach_done() -> bool:
	for m in missions:
		if not m.is_reach() and not m.done:
			return false
	return true


func _update_goal_lock() -> void:
	if goal:
		var was := goal.locked
		goal.set_locked(not _non_reach_done())
		if was and not goal.locked and started:
			say_story(stage.get("goal_say", "やったね！ ぜんぶ できた！ きいろい わっかの ゴールへ いこう！"), 5.0)


func remaining_text() -> String:
	var parts: Array[String] = []
	for m in missions:
		if not m.done and not m.is_reach():
			parts.append(m.text)
	return "、".join(parts)


func _on_enemy_died(e: Node) -> void:
	var kind: String = e.get("kind")
	var m := _mission("boss", kind) if kind == "boss_virus" else _mission("defeat", kind)
	if m:
		m.add(1)


func _on_friend_cheered(f: Node) -> void:
	var m := _mission("cheer", f.get("kind"))
	if m:
		m.add(1)


func _on_pickup_collected(p: Node) -> void:
	var m := _mission("collect", p.get("kind"))
	if m:
		m.add(1)
	missions_changed.emit()


func _on_delivered(_zone: Node, n: int) -> void:
	# 先に 言う（m.add() の 中で 出る done_say／goal_say を 上書きしない）
	Game.say_soft("えいようを とどけた！ からだが げんきに なるよ。", 2.5)
	var m := _mission("deliver")
	if m:
		m.add(n)


func _on_gate_passed(_g: Node) -> void:
	var m := _mission("gate")
	if m:
		m.add(1)


func _on_goal_reached() -> void:
	if finished or not started:
		return
	if not _non_reach_done():
		return
	var rm := _mission("reach")
	if rm:
		rm.add(1)
	finish()


func finish() -> void:
	if finished:
		return
	finished = true
	var no_damage := not damage_taken
	player.control_enabled = false
	player.velocity = Vector3.ZERO
	player.invulnerable = 1.0e9
	player.hitbox.set_deferred("monitoring", false)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.set_physics_process(false)
	Sfx.play("clear")
	var cs: String = stage.get("clear_say", "クリア！")
	if peristalsis != null:
		cs = peristalsis.clear_text(cs)   # なみに のった きょり
	say_story(cs, 3.0)
	if stage.has("ep"):
		Game.find_card(stage_id, "stage", true)   # 場所の カードは はじめて クリアした ときに みつかる（カルテの 場面だけ）。音は クリアの 曲に まかせる
	var t := create_tween()
	# なみに のった きょりを 足した ときは 長めに 見せる（読みおわる 前に つぎの 画面に ならない）
	var hold := 3.6 if peristalsis != null and peristalsis.ride_m >= 1.0 else 1.6
	t.tween_interval(0.2 if Game.testing else hold)
	t.tween_callback(func(): cleared.emit(stage_id, no_damage))


func respawn_position() -> Vector3:
	return respawn_point + Vector3.UP * 1.0


## 矢印が指す「いま向かうところ」
func current_target_position() -> Vector3:
	if stage.get("arrow", "") == "nearest":
		var near := _nearest_open_target()
		if near != Vector3.INF:
			return near
	for m in missions:
		if m.done:
			continue
		match m.type:
			"defeat":
				return _nearest_in_group("enemy", func(n): return n.get("kind") == m.target and n.get("alive"))
			"boss":
				return _nearest_in_group("enemy", func(n): return n.get("kind") == "boss_virus" and n.get("alive"))
			"cheer":
				return _nearest_in_group("friend", func(n): return n.get("kind") == m.target and not n.get("is_cheered"))
			"collect":
				if player.inventory.size() > 0 and _mission("deliver") != null:
					return _nearest_in_group("deliver", func(_n): return true)
				return _nearest_in_group("pickup", func(n): return n.get("kind") == m.target)
			"deliver":
				if player.inventory.size() > 0:
					return _nearest_in_group("deliver", func(_n): return true)
				return _nearest_in_group("pickup", func(_n): return true)
			"gate":
				for g in gates:
					if not g._counted:
						return g.global_position
			"sequence":
				# こたえを 教えないように、しんけいの まんなかを 遠くからだけ指す
				if neurons.is_empty():
					return Vector3.INF
				var c := Vector3.ZERO
				for nn in neurons:
					c += nn.global_position
				c /= neurons.size()
				return c if c.distance_to(player.global_position) > 16.0 else Vector3.INF
			"reach":
				if goal:
					return goal.global_position
	return Vector3.INF


## "arrow": "nearest" の 場面：開いている ミッションの 相手の うち、いちばん 近い ものを 指す
## （リストの 順だと、あとの ミッションの 相手を 通りすぎてから もどる ことに なる 場面で 使う）
func _nearest_open_target() -> Vector3:
	var best := Vector3.INF
	var bd := INF
	for m in missions:
		if m.done:
			continue
		var t := Vector3.INF
		match m.type:
			"defeat":
				t = _nearest_in_group("enemy", func(n): return n.get("kind") == m.target and n.get("alive"))
			"cheer":
				t = _nearest_in_group("friend", func(n): return n.get("kind") == m.target and not n.get("is_cheered"))
			"collect":
				t = _nearest_in_group("pickup", func(n): return n.get("kind") == m.target)
			"deliver":
				if player.inventory.size() > 0:
					t = _nearest_in_group("deliver", func(_n): return true)
		if t != Vector3.INF and t.distance_to(player.global_position) < bd:
			bd = t.distance_to(player.global_position)
			best = t
	return best


func _nearest_in_group(group: String, pred: Callable) -> Vector3:
	var best := Vector3.INF
	var bd := INF
	for n in get_tree().get_nodes_in_group(group):
		if not (n is Node3D) or not pred.call(n):
			continue
		var d: float = (n as Node3D).global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = (n as Node3D).global_position
	return best


# ---------------------------------------------------------------- 道・流れ
func path_direction_at(pos: Vector3) -> Vector3:
	return path.direction_at(pos) if path.is_valid() else Vector3.FORWARD


func path_sample(dist: float) -> Dictionary:
	return path.sample(dist)


func path_is_end(pos: Vector3) -> bool:
	return path.is_valid() and path.progress_at(pos) >= path.total - 4.0


func path_start_position() -> Vector3:
	return path.start() if path.is_valid() else spawn_point


# ---------------------------------------------------------------- 進行
func _physics_process(delta: float) -> void:
	if not started or finished:
		return
	elapsed += delta
	# 流れ
	if flow_speed > 0.0 and path.is_valid() and player:
		player.external_push += path.direction_at(player.global_position) * flow_speed
	# ヒント
	if _hints.size() > 0 and missions.size() > 1 and _non_reach_done():
		_hints.clear()   # やる ことが 全部 おわったら、もう ヒントは 出さない（「さわってね」と 言われて もどって しまう）
	if _hints.size() > 0 and elapsed >= float(_hints[0]["at"]) and not Game.hud_busy():
		var h: Dictionary = _hints[0]
		_hints.remove_at(0)
		var on_touch: bool = Game.touch_controls != null and is_instance_valid(Game.touch_controls) and Game.touch_controls.visible
		var ht := String(h.get("text_touch", h["text"])) if on_touch else String(h["text"])
		Game.say(ht, read_time(ht, 5.0))
	# カード
	_card_cd = maxf(_card_cd - delta, 0.0)
	_card_check -= delta
	if _card_check <= 0.0:
		_card_check = 0.3
		_check_cards()
	# しんけいパズル
	var sm := _mission("sequence")
	if sm != null and not sm.done and _seq.is_empty() and not _seq_showing and not _seq_pending and not neurons.is_empty():
		var c := Vector3.ZERO
		for nn in neurons:
			c += nn.global_position
		c /= neurons.size()
		if elapsed > 8.0 or player.global_position.distance_to(c) < 16.0:
			_start_sequence_round()


## ものしりカードの 点に ちかづいた（9 m）：カードを みつける（Game.find_card：音と HUD の 小さい しらせ）。
## ゲームは 止めない・ポップアップも 出さない。読むのは クリアの あと（「みつけた ものしりカード」）と ずかん
func _check_cards() -> void:
	if _card_cd > 0.0 or elapsed < 2.5:
		return
	for i in card_points.size():
		var cp: Dictionary = card_points[i]
		var key: String = cp["key"]
		if SaveData.card_seen(stage_id, key):
			continue
		var pos: Vector3 = cp["position"]
		var node = cp["node"]
		if node != null and is_instance_valid(node) and node is Node3D:
			pos = (node as Node3D).global_position
		if pos == Vector3.INF:
			continue
		if pos.distance_to(player.global_position) < 9.0:
			_card_cd = 3.0      # しらせ（2.5 秒）が 重ならない
			Game.find_card(stage_id, key)
			return


# ---------------------------------------------------------------- しんけいパズル
func _start_sequence_round() -> void:
	if neurons.is_empty():
		return
	var length := 3 + _seq_round
	_seq = []
	var last := -1
	for i in length:
		var n := randi() % neurons.size()
		if n == last:
			n = (n + 1) % neurons.size()
		_seq.append(n)
		last = n
	_seq_input = 0
	_show_sequence()


func _show_sequence() -> void:
	_seq_showing = true
	for nn in neurons:
		nn.armed = false
	# カメラを 上から見る位置にして、ぜんぶの しんけいを 見せる（プレイヤーは その場で待つ）
	player.control_enabled = false
	player.velocity = Vector3.ZERO
	var c := Vector3.ZERO
	for nn in neurons:
		c += nn.global_position
	c /= neurons.size()
	camera.set_overview(c)
	Game.say("よく みてね！", 2.0)
	var t := create_tween()
	t.tween_interval(1.6)
	for idx in _seq:
		var n := neurons[idx]
		t.tween_callback(func(): n.light_up(0.6))
		t.tween_interval(0.75)
	t.tween_callback(func():
		_seq_showing = false
		_seq_input = 0
		_seq_input_started = elapsed
		for nn in neurons:
			nn.armed = true
		camera.clear_overview()
		if not finished:
			player.control_enabled = true
		Game.say("きみの ばん！ おなじ じゅんばんに さわろう。", 3.0)
	)


func _on_neuron_touched(n: Neuron) -> void:
	if _seq.is_empty() or _seq_showing:
		return
	var m := _mission("sequence")
	if m == null or m.done:
		return
	if n.index == _seq[_seq_input]:
		n.light_up(0.5)
		_seq_input += 1
		if _seq_input >= _seq.size():
			_seq_round += 1
			m.add(1)
			_seq = []
			if not m.done:
				_seq_pending = true
				Game.say("せいかい！ つぎは もっと ながいよ。", 2.0)
				var t := create_tween()
				t.tween_interval(2.0)
				t.tween_callback(func():
					_seq_pending = false
					_start_sequence_round())
	elif elapsed - _seq_input_started < 0.6 and _seq_input == 0:
		# はじまった しゅんかんに たまたま 乗っていた しんけいは 数えない
		n.armed = false
	else:
		Sfx.play("wrong")
		Game.say("ざんねん！ もういちど みてね。", 2.0)
		_seq_input = 0
		_seq_showing = true  # もう一度見せるまで さわっても数えない
		for nn in neurons:
			nn.armed = false
		var t := create_tween()
		t.tween_interval(1.5)
		t.tween_callback(_show_sequence)


## テスト用：いまの正解の順番
func sequence_expected() -> Array[int]:
	return _seq
