class_name Player
extends HoverBody
## ミクロごう（プレイヤー）。
## 操作：移動、action（おくすり／おうえん）、dash。
## ひろい 場所（arena・rooms）は のりもの みたいに うごかす：←→ で その場で むきを かえ、↑ で まえへ、↓ で ゆっくり うしろへ。
## カメラは いつも 船の うしろに つくので、まわると 景色が まわる。
## くだ（tube）は カメラ基準：カメラが 道の むきを むき、←→ で くだを よこぎる。
## ハートは 3 つ。0 になると最後のチェックポイントへ戻る（ゲームオーバーなし）。

signal hearts_changed(hearts: int)
signal hurt_happened
signal respawned

const MAX_HEARTS := 3
const SPEED := 9.0
const DASH_SPEED := 14.0
const ACCEL := 32.0
const SHOT_COOLDOWN := 0.32
## のりものの 操作（ひろい 場所）。まわる はやさは 1 びょう おすと 約 110 ど（半回転は 1.7 びょう）
const TURN_SPEED := 2.0
const TURN_ACCEL := 18.0      # まわりはじめ（rad/s²）。ちょんと おしても くるっと ならない
const TURN_STOP := 40.0       # はなしたら すぐ とまる（いきすぎは 2 ど くらい）
const BACK_RATE := 0.45       # うしろへは まえの 半分より おそく
const AIM_CONE := 40.0        # のりものの ときの じどうで ねらう はんい（船の まえ ±ど）
const Projectile := preload("res://src/player/projectile.gd")

var hearts := MAX_HEARTS
var inventory: Array[String] = []
var heading := Vector3.FORWARD
var control_enabled := true
var speed_mult := 1.0
var external_push := Vector3.ZERO
## なみ（ぜんどううんどう）に のって いる あいだ、この むきに この はやさ（m/s）より おそく ならない（毎フレーム 0 に もどる。peristalsis.gd が 入れる）
var carry_dir := Vector3.ZERO
var carry_speed := 0.0
## やわらかい ものに ぶつかって ゆっくりに なって いる のこりの 秒（ハートは へらない）
var slow_time := 0.0
const SLOW_MULT := 0.45
const TUBE_START_GUARD := 2.5   # くだの 場所：道の はじめから この m までは うしろへ すすめない（はじめが ひらいた くだ（ちの くだ・はな）から おちない）
## いまの まわる はやさ（rad/s。ひだりまわりが ＋）
var turn_rate := 0.0
var invulnerable := 0.0
var shot_timer := 0.0
var level: Node = null
var camera: Node3D = null
var model: Node3D
var arrow: Node3D
## 矢印の 向き（rad。0 ＝ 画面の 上 ＝ まえ、＋ ＝ 右、±π ＝ うしろ）。テストが 見る
var arrow_angle := 0.0
const ARROW_Y := 1.6
const ARROW_NEAR := 7.0          # この m より 近くて
const ARROW_NEAR_ANGLE := 0.45   # まえ ±26° に ある 行き先には 矢印を 出さない
const ARROW_REF_DEPTH := 4.8     # ふつうの カメラ（うしろ 5.2 m）から 矢印までの ふかさ（約 4.9 m）より 少し 小さく：ひろい ところでは 大きさ そのまま
const ARROW_HALF := 0.06         # 矢じるしの 大きさの 半分（画面の 高さの わり。ひろい ところで 約 80 px ÷ 2 ÷ 720）
const ARROW_EDGE := 0.09         # 矢印の まんなかを 画面の はしから 高さの この わり 内がわに たもつ（矢じるしの 半分より 大きく）
var hitbox: Area3D
var _blink := 0.0
var _propeller: Node3D
var _respawning := false
var _no_floor_time := 0.0
## ゆかが ない まま この 秒 たったら チェックポイントへ もどす。前は 2.5 びょう：口の はしで くちびるを ななめに こえた 船が、
## その あいだ 場所の 外を おちて いた。ふつうに こえる すきま（のう・はい）は 長くて 0.25 びょう
const NO_FLOOR_BACK := 0.8
var _stuck_time := 0.0
var _stuck_from := Vector3.ZERO
var hit_stun := 0.0
var _stuck_count := 0
## うごかない なかまに まっすぐ ぶつかった とき、よこへ すべらせる はやさ（つぎの フレームの 目標に 足す）
var _slip := Vector3.ZERO
## かべで はねかえる（ひろい 場所で ↑ だけ おして かべに ぶつかった とき、じぶんで かべから はなれる 向きへ まがる）。
## 前は かべに まっすぐ ぶつかると 船が とまり、画面が かべで いっぱいの まま 5 びょう（もどしまで）まって いた
const GLIDE_ON := 0.42        # かべへ むかう 度あい（cos。1 ＝ まっすぐ）が これより 大きいと まがりはじめる（かべと 25° より ふかい）。あさい ときは 前と 同じ（かべに そって すべる）
const GLIDE_AWAY := 0.707     # かべから はなれる 向きに この 度あい（sin。45°）まで まがったら やめる。30° だと まるい かべの 近く（2 m いない）を まわり つづけた
const GLIDE_RATE := 1.6       # まがる はやさ（rad/s。子どもが ←→ で まわす はやさ 2.0 より ゆっくり）
const GLIDE_SPEED := 0.35     # かべへ むいて いる あいだ（まがりきる まで）の すすむ はやさの 倍率。はやい ままだと まがりながら かべを ななめに
                              # のぼり、口の くちびるを こえて 外へ 出た（16 本の うち 2 本）
const GLIDE_MAX := 3.5        # ひとつづきで じどうで まがって よい 角（rad。200°。ふくろの ような ところから 出る ぶん）
const GLIDE_KEEP := 0.6       # かべから はなれても この 秒は まがる がわと かべの 向きを おぼえて おく（まがりきる。がわが いったり きたり しない）
const GLIDE_STEER := 0.05     # ←→ が これより 大きいと 子どもが まわして いる：じどうでは まがらない（タッチの すこしの かたむきも 子どもの はやさの まま）
const GLIDE_POOL_LOOK := 40.0 # まがった 先の 道を この m まで 見て、いえきの いけを とおる がわへは まがらない
const GLIDE_HEAD_ON := 0.8    # かべに これより まっすぐ（cos。約 37° いない）ぶつかった ときだけ 行き先の がわへ まがる。ななめなら かたむいて いる がわ
var _glide_side := 0.0        # ＋ ＝ ひだりまわり、－ ＝ みぎまわり、0 ＝ まがって いない
var _glide_on := false
var _glide_turning := false   # いまの turn_rate が じどうの まがりから きて いる
var _glide_free := 0.0        # かべに ふれて いない 秒
var _glide_n := Vector3.ZERO  # さいごに ふれた かべの 向き（かべから 船へ。水平）
var _glide_turned := 0.0      # ひとつづきで じどうで まがった 角（rad）
var _glide_slow := false      # じどうで まがって いて、まだ かべへ むいて いる（ゆっくり すすむ）
## いえきの いけ：1 かい いけで へったら、どの いけからも 1 びょう 出て いるまで もう へらない（いけを よこぎっても 1 つ）
const POOL_REST := 1.0
var _pool_hurt_lock := false
var _pool_out := 0.0
var _in_pool_now := false

## テスト用：ここに座標を入れると その方向へ自動で動く
var autopilot_target: Vector3 = Vector3.INF
var autopilot_shoot := false


func _ready() -> void:
	super._ready()
	hover_height = 1.1
	collision_layer = 2
	collision_mask = 1 | 4 | Friend.SOLID_LAYER  # world + enemy bodies(3rd bit = 4) + うごかない なかまの 中の 当たり
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.55
	shape.shape = s
	add_child(shape)

	model = ModelLib.character("pod", 0.7)
	add_child(model)
	_propeller = model.find_child("Propeller", true, false)

	hitbox = Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 32   # player_area (6)
	hitbox.collision_mask = 16 | 64  # trigger(5) + enemy_touch(7)
	var hs := CollisionShape3D.new()
	var hss := SphereShape3D.new()
	hss.radius = 0.7
	hs.shape = hss
	hitbox.add_child(hs)
	add_child(hitbox)
	hitbox.area_entered.connect(_on_area_entered)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.97, 0.9)
	light.light_energy = 0.9
	light.omni_range = 12.0
	light.position = Vector3(0, 1.0, -0.5)
	add_child(light)

	arrow = _make_arrow()
	add_child(arrow)
	add_to_group("player")


func _make_arrow() -> Node3D:
	# 行き先の 矢印：ひらたい 矢じるしを いつも 画面に 向けて、船の 上に うかべる。
	# 画面の 上 ＝ まえ、右 ＝ みぎ、下 ＝ うしろ（カメラは いつも 船の 後ろに いる）。
	# 前は 円すいを 行き先へ 向けて いた：行き先が まえに ある とき（いちばん 多い）は まうしろから 見る ことに なり、
	# ただの 丸に 見えた（ブラウザ版の 見なおしで、ゴールの 横の「青い 玉」に 見えた）
	var pivot := Node3D.new()
	pivot.name = "Arrow"
	pivot.position = Vector3(0, ARROW_Y, 0)
	var dart := Node3D.new()
	dart.name = "Dart"
	pivot.add_child(dart)
	# 白い ふちの 上に 水色（光る 黄色は ゴールだけ）。光を 受けない 色で 描く（かげで 色が かわらない）
	dart.add_child(_dart_mesh(1.0, Color(1.0, 1.0, 1.0), 0.0))
	dart.add_child(_dart_mesh(0.74, Color(0.22, 0.62, 0.98), 0.012))
	pivot.visible = false
	return pivot


## 矢じるしの 形（上向き。たて 0.66 m・よこ 0.60 m に k を かけた 大きさ）。z は 画面の 手前へ ずらす 量
func _dart_mesh(k: float, color: Color, z: float) -> MeshInstance3D:
	var tip := Vector3(0.0, 0.36, z) * Vector3(k, k, 1.0)
	var right := Vector3(0.30, -0.30, z) * Vector3(k, k, 1.0)
	var notch := Vector3(0.0, -0.12, z) * Vector3(k, k, 1.0)
	var left := Vector3(-0.30, -0.30, z) * Vector3(k, k, 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [tip, right, notch, tip, notch, left]:
		st.add_vertex(v)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _physics_process(delta: float) -> void:
	shot_timer = maxf(shot_timer - delta, 0.0)
	if invulnerable > 0.0:
		invulnerable -= delta
		_blink += delta
		model.visible = fmod(_blink, 0.2) < 0.1
	else:
		model.visible = true

	hover_step(delta)
	# ゆかが見つからないまま落ちつづけたら、チェックポイントへ戻す（セーフティ）
	if floor_found:
		_no_floor_time = 0.0
	else:
		_no_floor_time += delta
		if _no_floor_time > NO_FLOOR_BACK and level and level.has_method("respawn_position") and not _respawning:
			_no_floor_time = 0.0
			global_position = level.respawn_position()
			velocity = Vector3.ZERO
			_face_restart()
	# なみ・いえき などの「乗っている間の効果」は、速度を決める前に集める
	_check_overlaps()
	var input := Vector2.ZERO
	var dash := false
	var shoot := false
	var dir := Vector3.ZERO
	if control_enabled and not _respawning and hit_stun <= 0.0:
		if autopilot_target != Vector3.INF:
			var to := autopilot_target - global_position
			to.y = 0.0
			if to.length() > 0.6:
				dir = to.normalized()
			shoot = autopilot_shoot
			dash = true
		else:
			dash = Input.is_action_pressed("dash")
			shoot = Input.is_action_pressed("action")
			if is_steering():
				# ←→ と ↑↓ を べつべつに よむ（ななめでも まわる はやさ・すすむ はやさが へらない）
				input = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
				dir = _steer_input(input, delta)
			else:
				input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
				dir = _camera_relative(input)
	if not is_steering() or not control_enabled or _respawning or hit_stun > 0.0:
		turn_rate = 0.0
	if hit_stun > 0.0:
		hit_stun -= delta
	if slow_time > 0.0:
		slow_time -= delta
		speed_mult *= SLOW_MULT
	var target_speed := (DASH_SPEED if dash else SPEED) * speed_mult
	var target_vel := dir * target_speed + external_push + _slip
	_slip = Vector3.ZERO
	target_vel = _tube_start_guard(target_vel)
	if carry_speed > 0.0 and hit_stun <= 0.0:
		# なみに のって いる：前へは なみの はやさまで おされる（よこは じぶんで うごける）
		var along := target_vel.dot(carry_dir)
		if along < carry_speed:
			target_vel += carry_dir * (carry_speed - along)
	steer(target_vel, ACCEL if hit_stun <= 0.0 else 5.0, delta)
	velocity = _tube_start_guard(velocity, true)   # はねかえり（hurt・bump）も はじめから 外へ 出さない
	if dir.length() > 0.1 and not is_steering():
		# slerp は 反対向きのとき 軸の正規化エラーを出すことがあるので、普通の補間＋正規化にする
		var h := heading.lerp(dir, minf(1.0, 10.0 * delta))
		heading = h.normalized() if h.length() > 0.05 else dir
	move_and_slide()
	_slip_around_friends(dir)

	# 見た目
	var yaw := HoverBody.yaw_for(heading)
	if is_steering():
		# 向きは もう なめらかに かわって いるので、そのまま 合わせる（カメラと ずれない）
		model.rotation.y = yaw
	else:
		model.rotation.y = lerp_angle(model.rotation.y, yaw, minf(1.0, 8.0 * delta))
	var hv := Vector3(velocity.x, 0, velocity.z)
	var lean := clampf(hv.length() / DASH_SPEED, 0.0, 1.0)
	model.rotation.x = lerp(model.rotation.x, -0.18 * lean, 6.0 * delta)
	var side := hv.length() > 0.5 and dir.length() > 0.1
	var roll_target := 0.0
	if is_steering():
		# まがる ほうへ すこし かたむく（すすんで いる ときだけ）
		roll_target = 0.3 * clampf(turn_rate / TURN_SPEED, -1.0, 1.0) * clampf(hv.length() / SPEED, 0.0, 1.0)
	elif side:
		var right := Vector3(-heading.z, 0, heading.x)
		roll_target = -0.35 * clampf(dir.dot(right), -1.0, 1.0)
	model.rotation.z = lerp(model.rotation.z, roll_target, 6.0 * delta)
	if _propeller:
		_propeller.rotate_z(delta * (12.0 + 30.0 * lean))

	if shoot and shot_timer <= 0.0:
		_shoot()
	_check_stuck(delta, dir)
	speed_mult = 1.0
	external_push = Vector3.ZERO
	carry_speed = 0.0
	_update_arrow(delta)


## うごかない なかま（friend.gd の FriendSolid。まるい 柱）に まっすぐ ぶつかると、柱の まわりを すべれずに 止まる。
## そのときは よこへ すこし おして、まわりを すべって 先へ 行ける ように する（子どもが ↑ を おしつづけても 止まらない）
func _slip_around_friends(dir: Vector3) -> void:
	if dir.length() < 0.1:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider() as Node
		if body == null or not body.is_in_group("friend_solid"):
			continue
		var n := c.get_normal()
		n.y = 0.0
		if n.length() < 0.01:
			continue
		n = n.normalized()
		if dir.dot(-n) < 0.5:
			continue
		var side := Vector3(-n.z, 0.0, n.x)
		if dir.dot(side) < -0.05:   # まっすぐ（ほぼ 0）の ときは いつも 同じ がわへ（ゆれて 止まらない ように）
			side = -side
		_slip = side * SPEED * 0.6


## 船が ぶつかって いるのが うごかない なかまの 当たり だけ か（はさまった ことには しない。よこへ すべるので 止まらない）
func _only_friend_contact() -> bool:
	for i in get_slide_collision_count():
		var body := get_slide_collision(i).get_collider() as Node
		if body == null or not body.is_in_group("friend_solid"):
			return false
	return true


## うごこうとしているのに 5 秒以上 その場から動けないときは、少し後ろへ押し戻す。
## それでもだめなら チェックポイントへ戻す。
func _check_stuck(delta: float, dir: Vector3) -> void:
	if dir.length() < 0.1 or _respawning or get_slide_collision_count() == 0 or _only_friend_contact():
		_stuck_time = 0.0
		_stuck_from = global_position
		return
	if global_position.distance_to(_stuck_from) > 0.8:
		_stuck_time = 0.0
		_stuck_from = global_position
		return
	_stuck_time += delta
	if _stuck_time > 5.0 and level:
		_stuck_time = 0.0
		_stuck_count += 1
		if _stuck_count <= 2 and level.has_method("path_direction_at"):
			# まず 3 m 後ろへ（くだなら道にそって）
			var back: Vector3 = -level.path_direction_at(global_position) if level.path.is_valid() else -heading
			if _in_tube() and level.path.is_valid() and dir.dot(-back) < 0.0:
				# くだで うしろへ おして はさまった（はじめの ふた など）：まえへ もどす
				back = -back
			if is_steering():
				# ひろい 場所：すすもうと した むきの はんたいへ（うしろへ さがって かべに はさまったら まえへ）。
				# 道（MK_path）の ある 場所でも 道の むきは つかわない（スタートの うしろの かべへ おしこむ ことに なる）
				back = -dir.normalized()
			back.y = 0.0
			back = back.normalized() if back.length() > 0.01 else -heading
			var step := _free_step(back, 3.0)
			if step > 0.4:
				global_position += back * step + Vector3.UP * 0.5
				velocity = back * 4.0
			else:
				velocity = Vector3.UP * 2.0
			Game.say("はさまっちゃった！ ちょっと もどるね。", 2.0)
		elif level.has_method("respawn_position"):
			_stuck_count = 0
			global_position = level.respawn_position()
			velocity = Vector3.ZERO
			_face_restart()
			Game.say("あれ？ ぬけられない。チェックポイントから やりなおそう。", 3.0)
		_stuck_from = global_position


## くだの 場所か（カメラが 道に そう）。自動操縦でも くだなら true
func _in_tube() -> bool:
	return camera != null and bool(camera.get("tube_mode"))


## くだの 場所の はじめ（TUBE_START_GUARD m まで）では、道を うしろへ むかう 速さを けす。
## ひらいた はじめから 船が 外へ 出て おちる ことが ない ように。ひろい 場所では なにも しない。
## くだなら 自動操縦（テスト）にも かかる。flat：よこの 速さ（x・z）だけ 見る（はねかえった あとの velocity に つかう）
func _tube_start_guard(v: Vector3, flat := false) -> Vector3:
	if level == null or not _in_tube() or not level.has_method("path_direction_at"):
		return v
	if level.path == null or not level.path.is_valid() or level.path.progress_at(global_position) > TUBE_START_GUARD:
		return v
	var pd: Vector3 = level.path_direction_at(global_position)
	if flat:
		pd.y = 0.0
		if pd.length() < 0.01:
			return v
		pd = pd.normalized()
	var along := v.dot(pd)
	if along < 0.0:
		v -= pd * along
	return v


## はさまった ときに もどす きょり：かべ（world）の 手前で とまり、行き先の 下に ゆかが ある こと。
## かべの 外へ 出して 下へ おちる ことが ない ように する（0 なら うごかさない）
func _free_step(dir: Vector3, want: float) -> float:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.5
	var dist := want
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (want + 1.0), 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		dist = minf(want, from.distance_to(hit["position"]) - 1.0)
	if dist <= 0.0:
		return 0.0
	var to := from + dir * dist
	var down := PhysicsRayQueryParameters3D.create(to, to + Vector3.DOWN * 12.0, 1)
	var g := space.intersect_ray(down)
	if g.is_empty():
		return 0.0
	# 下に あるのが うら向きの 面（かべの 外がわ）なら ゆかでは ない
	if (g["normal"] as Vector3).y < 0.3:
		return 0.0
	return dist


## のりものの 操作を つかうか（ひろい 場所で、自動操縦で ない とき）
func is_steering() -> bool:
	return autopilot_target == Vector3.INF and camera != null and not camera.get("tube_mode")


## のりものの 操作：←→ で heading を まわし、↑↓ で heading の まえ／うしろへ。
## うしろへ さがっても 船の むきは かわらない（カメラも くるっと まわらない）
func _steer_input(input: Vector2, delta: float) -> Vector3:
	var turn := -input.x
	# スティックの すこしだけ たおした ところは ゆっくり（こまかく ねらえる）
	var want := signf(turn) * pow(absf(turn), 1.4) * TURN_SPEED
	var g := _wall_glide(input, delta)
	if g != 0.0:
		want = g
	elif _glide_turning and signf(turn_rate) != signf(want):
		# じどうの まがりは すぐ やめる（手を はなした あとや 子どもが はんたいへ まわす ときに のこらない）
		turn_rate = 0.0
	_glide_turning = g != 0.0
	var rate := TURN_ACCEL if absf(want) > absf(turn_rate) and signf(want) == signf(turn_rate) or turn_rate == 0.0 else TURN_STOP
	turn_rate = move_toward(turn_rate, want, rate * delta)
	if turn_rate != 0.0:
		heading = heading.rotated(Vector3.UP, turn_rate * delta)
		heading.y = 0.0
		heading = heading.normalized()
	var fwd := -input.y
	if fwd < 0.0:
		fwd *= BACK_RATE
	elif _glide_slow:
		fwd *= GLIDE_SPEED
	return heading * fwd


## かべから はなれる ための まわる はやさ（rad/s。0 ＝ まがらない）。
## ↑ だけ おして（←→ なし）かべ（world）に ぶつかって いる ときだけ。子どもが ←→ を すこしでも おしたら やめる（さからわない。
## タッチの すこしの かたむきも 子どもの はやさの まま：前は GLIDE_RATE まで 上げて、たのんだ 3〜4 ばい まわった）。
## まがる がわ：まっすぐ ぶつかった ときは 行き先の がわ（うしろに ある 行き先は 見ない）、ななめなら いま かたむいて いる がわ。
## いけ・てきの いる がわへは まがらない。
## かべと ならんでも やめず、かべから GLIDE_AWAY（45°）はなれる 向きまで まがって へやの 中へ もどる。かべに そって
## すすみ つづけると、かべぞいの てきへ はこばれ、うしろの かべで カメラが よったり はなれたり する（見なおしで 見つかった）。
## かべから はなれた すぐ あとも（GLIDE_KEEP 秒）おぼえた かべの 向きで まがりきる。ふくろの ような ところは 同じ がわへ
## まがり つづけて 出る。ひとつづきで GLIDE_MAX より まがらない（その 先は もどし（_check_stuck）に まかせる）
func _wall_glide(input: Vector2, delta: float) -> float:
	var n := Vector3.ZERO
	var pushing := input.y < -0.3 and absf(input.x) < GLIDE_STEER and control_enabled and hit_stun <= 0.0
	if pushing:
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var body := c.get_collider() as CollisionObject3D
			if body == null or (body.collision_layer & 1) == 0 or body.is_in_group("friend_solid"):
				continue
			var cn := c.get_normal()
			if cn.y > 0.85:
				continue
			cn.y = 0.0
			n += cn
	n.y = 0.0
	var touching := n.length() >= 0.2
	if touching:
		n = n.normalized()
		_glide_n = n
		_glide_free = 0.0
	else:
		_glide_free += delta
		if not pushing or _glide_free > GLIDE_KEEP or _glide_n == Vector3.ZERO:
			_glide_on = false
			_glide_slow = false
			_glide_side = 0.0
			_glide_n = Vector3.ZERO
			_glide_turned = 0.0
			return 0.0
		n = _glide_n
	var into := heading.dot(-n)
	if touching and into > GLIDE_ON:
		_glide_on = true
	elif into < -GLIDE_AWAY:
		# まがりきった：つぎに ぶつかる かべでは また はじめから（せまい 場所で つづけて はねかえると GLIDE_MAX を こえて、
		# その あと まがらなく なって いた）
		if _glide_on:
			_glide_turned = 0.0
		_glide_on = false
	_glide_slow = false
	if not _glide_on or _glide_turned > GLIDE_MAX:
		return 0.0
	if input.x != 0.0:
		# ←→ が ほんの すこし（GLIDE_STEER より 小さい。ゲームパッドの あそびの すぐ 外）：子どもの がわへ まがる（はんたいへは まがらない）
		_glide_side = -signf(input.x)
	elif _glide_side == 0.0:
		_glide_side = _glide_pick_side(n)
	_glide_turned += absf(turn_rate) * delta
	_glide_slow = _glide_side != 0.0 and into > 0.0
	return _glide_side * GLIDE_RATE


## まがる がわ（＋ ＝ ひだり）。かべに そって ひだりまわりで すすむ 向きは (-n) を ＋90° まわした もの
func _glide_pick_side(n: Vector3) -> float:
	var left := (-n).rotated(Vector3.UP, PI / 2.0)
	var side := 0.0
	var head_on := heading.dot(-n) > GLIDE_HEAD_ON
	if head_on and level != null and level.has_method("current_target_position"):
		var tp: Vector3 = level.current_target_position()
		if tp != Vector3.INF:
			var to := tp - global_position
			to.y = 0.0
			if to.length() > 0.5 and to.dot(heading) > 0.0 and absf(to.normalized().dot(left)) > 0.15:
				side = signf(to.dot(left))
	if side == 0.0:
		var lean := heading.dot(left)
		side = 1.0 if lean >= 0.0 else -1.0
	# いけ・ゆかの ない ところ・てきの いる ところへ むかう がわへは まがらない。まっすぐ ぶつかった ときは、もう 片がわの
	# ほうが ましなら そちらへ（同じなら そのまま）。ななめの ときは まがらない（0）：はんたいへ まがると 子どもを ぎゃくもどり させる
	var cost := _side_cost(_glide_exit(left * side, n))
	if cost > 0:
		if not head_on:
			return 0.0
		if _side_cost(_glide_exit(-left * side, n)) < cost:
			side = -side
	return side


## かべに そう 向き along から かべを GLIDE_AWAY はなれた 向き（まがりおわった あと 船が すすむ 向き）
static func _glide_exit(along: Vector3, n: Vector3) -> Vector3:
	return (along * sqrt(1.0 - GLIDE_AWAY * GLIDE_AWAY) + n * GLIDE_AWAY).normalized()


## d の 向きへ まがった ときの わるさ（0 ＝ よい）。まがりおわった 船は つぎの かべまで まっすぐ すすむ：
## ゆかが ない（口の 外など）3、道（9 m）の そばに てきが いる・すぐ 先（12 m いない）に いえきの いけ 2、
## その 先（GLIDE_POOL_LOOK m まで）で いけを とおる 1
func _side_cost(d: Vector3) -> int:
	var cost := 0
	for h in get_tree().get_nodes_in_group("hazard"):
		var pool := h as HazardPool
		if pool == null or (level != null and not level.is_ancestor_of(pool)):
			continue
		var to := pool.global_position - global_position
		to.y = 0.0
		var along := clampf(to.dot(d), 0.0, GLIDE_POOL_LOOK)
		if (to - d * along).length() < pool.radius + 0.5:
			cost = maxi(cost, 2 if along < 12.0 else 1)
	if _enemy_near(d, 9.0):
		cost = maxi(cost, 2)
	var space := get_world_3d().direct_space_state
	for m in [3.0, 6.0]:
		var at: Vector3 = global_position + d * m + Vector3.UP * 2.0
		var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 14.0, 1))
		if g.is_empty() or (g["normal"] as Vector3).y < 0.35:
			return 3
	return cost


## d の 向きへ reach m すすむ 道から near m いないに いきて いる てきが いるか（てきは 数 ひき。まがる がわを えらぶ ときだけ よぶ）。
## near は ピロリきんが かべの さいぼうを まわる 輪（半径 3.5 m）より 少し 大きく
func _enemy_near(d: Vector3, reach: float, near := 4.0) -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D) or not e.get("alive") or (level != null and not level.is_ancestor_of(e)):
			continue
		var to: Vector3 = (e as Node3D).global_position - global_position
		to.y = 0.0
		var along := clampf(to.dot(d), 0.0, reach)
		if (to - d * along).length() < near:
			return true
	return false


static func _hd(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _camera_relative(input: Vector2) -> Vector3:
	if input.length() < 0.05:
		return Vector3.ZERO
	var basis_yaw := 0.0
	if camera != null:
		basis_yaw = camera.global_rotation.y
	var forward := Vector3(-sin(basis_yaw), 0, -cos(basis_yaw))
	var right := Vector3(cos(basis_yaw), 0, -sin(basis_yaw))
	var d := right * input.x + forward * (-input.y)
	if d.length() > 1.0:
		d = d.normalized()
	return d


func _shoot() -> void:
	shot_timer = SHOT_COOLDOWN
	var dir := heading
	var steering := is_steering()
	var target := _auto_aim(steering)
	if target != null:
		var to := (target.global_position - global_position)
		to.y = 0.0
		if to.length() > 0.01:
			dir = to.normalized()
			# のりものの ときは 船の むきを かえない（たまは 船の まえの ほうへ とぶ）
			if not steering:
				heading = dir
	var p := Projectile.new()
	p.direction = dir
	p.owner_level = level
	get_parent().add_child(p)
	p.global_position = global_position + dir * 0.9 + Vector3.UP * 0.1
	Sfx.play("shoot", randf_range(0.95, 1.1))


## front_only：船の まえ（AIM_CONE ど）の てきだけ ねらう（のりものの 操作の とき）
func _auto_aim(front_only := false) -> Node3D:
	var best: Node3D = null
	var best_d := 16.0
	var fallback: Node3D = null
	var fallback_d := 9.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D) or not e.get("alive"):
			continue
		if not e.get("targetable"):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < 0.1:
			continue
		var ang := rad_to_deg(heading.angle_to(to.normalized()))
		if front_only:
			if ang < AIM_CONE and d < best_d:
				best = e
				best_d = d
			continue
		if ang < 70.0 and d < best_d:
			best = e
			best_d = d
		elif d < fallback_d:
			fallback = e
			fallback_d = d
	return best if best != null else fallback


func _on_area_entered(area: Area3D) -> void:
	if area.has_method("on_player_touch"):
		area.on_player_touch(self)


func _check_overlaps() -> void:
	if not hitbox.monitoring:
		return
	# いけの 外に いる 時間（_in_pool_now は いけの on_player_stay が 立てる。前の フレームの ぶん）。
	# へった あとの ちかちか（invulnerable）の あいだは 数えない：へった ときの はねかえりで いけの 外へ 出て、
	# ↑ の まま もどって くると、べつの 1 かいに なって また へって いた（よこぎると 2 つ）
	if _in_pool_now:
		_pool_out = 0.0
	elif invulnerable <= 0.0:
		_pool_out += get_physics_process_delta_time()
		if _pool_out >= POOL_REST:
			_pool_hurt_lock = false
	_in_pool_now = false
	for area in hitbox.get_overlapping_areas():
		if area.is_in_group("enemy_touch") and invulnerable <= 0.0 and not _respawning:
			var src: Node3D = area.get_parent() if area.get_parent() is Node3D else area
			if src.get("alive") == false:
				continue
			hurt(src.global_position)
		elif area.has_method("on_player_stay"):
			area.on_player_stay(self, get_physics_process_delta_time())


func hurt(from: Vector3) -> void:
	if invulnerable > 0.0 or _respawning:
		return
	hearts -= 1
	invulnerable = 1.5
	hit_stun = 0.4
	_blink = 0.0
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		away = -heading
	velocity = away.normalized() * 10.0 + Vector3.UP * 2.0
	hearts_changed.emit(hearts)
	hurt_happened.emit()
	Sfx.play("hurt")
	if hearts <= 0:
		_respawn()


## やわらかい ものに ぶつかった（しょくどうの たべものの かたまり）：はねかえって 少しの あいだ ゆっくり。ハートは へらない
func bump(from: Vector3, strength := 7.0, slow := 1.0) -> void:
	if _respawning:
		return
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		away = -heading
	velocity = away.normalized() * strength + Vector3.UP * 1.5
	hit_stun = 0.25
	slow_time = maxf(slow_time, slow)


## いえきの いけが 毎フレーム よぶ（hazard_pool.gd）。いけで へるのは 1 かい：へった あとは どの いけからも
## POOL_REST 秒 出て いるまで へらない（前は 1.2 びょうごとに へり、いけを よこぎると ハートが 2 つ へった）
func pool_hurt(from: Vector3) -> void:
	_in_pool_now = true
	if _pool_hurt_lock or invulnerable > 0.0 or _respawning:
		return
	hurt(from)
	_pool_hurt_lock = true


func heal(n := 1) -> void:
	hearts = mini(hearts + n, MAX_HEARTS)
	hearts_changed.emit(hearts)


func _respawn() -> void:
	_respawning = true
	control_enabled = false
	velocity = Vector3.ZERO
	var t := create_tween()
	t.tween_property(model, "scale", Vector3.ONE * 0.05, 0.4)
	t.tween_callback(func():
		if level and level.has_method("respawn_position"):
			global_position = level.respawn_position()
			_face_restart()
		hearts = MAX_HEARTS
		hearts_changed.emit(hearts)
		velocity = Vector3.ZERO
	)
	t.tween_property(model, "scale", Vector3.ONE, 0.4)
	t.tween_callback(func():
		_respawning = false
		control_enabled = true
		invulnerable = 2.0
		respawned.emit()
	)


## チェックポイントへ もどした ときに、つぎに 行く 向きを むかせ、カメラも すぐ うしろへ（level.respawn_heading）
func _face_restart() -> void:
	if level == null or not level.has_method("respawn_heading"):
		return
	var h: Vector3 = level.respawn_heading(global_position)
	if h.length() > 0.1:
		heading = h.normalized()
		model.rotation.y = HoverBody.yaw_for(heading)
	turn_rate = 0.0
	_glide_turning = false
	_glide_side = 0.0
	_glide_on = false
	_glide_slow = false
	_glide_n = Vector3.ZERO
	_glide_turned = 0.0
	if camera != null and camera.has_method("snap_to_target"):
		camera.snap_to_target()


func _update_arrow(delta: float) -> void:
	if level == null or not level.has_method("current_target_position"):
		arrow.visible = false
		return
	var tp: Vector3 = level.current_target_position()
	if tp == Vector3.INF:
		arrow.visible = false
		return
	var to := tp - global_position
	to.y = 0.0
	if to.length() < 3.0:
		arrow.visible = false
		return
	# くだの 場所で 行き先が 道の 先に ある ときは 出さない（道は 1 本。まえを 指す 矢印が ずっと 出て いると じゃまに なる）
	if level.get("stage") is Dictionary and level.stage.get("kind", "") == "tube" and level.get("path") != null and level.path.is_valid():
		var pd: Vector3 = level.path.direction_at(global_position)
		pd.y = 0.0
		if pd.length() > 0.01 and pd.normalized().dot(to.normalized()) > cos(deg_to_rad(35.0)):
			arrow.visible = false
			return
	arrow.visible = true
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# いつも 画面に 向ける（大きさは そのまま：撮影の 道具は 大きさ 0 で かくす）
	var sc := arrow.scale
	var cb := cam.global_transform.basis.orthonormalized()
	var bob := sin(Time.get_ticks_msec() / 200.0) * 0.1
	var at := global_position + Vector3.UP * (ARROW_Y + bob)
	# 画面の 上での 大きさは いつも 同じ：カメラが ふだんより 近い（かべの 前）ときは 小さく する。
	# 画面の はしで 切れない ように、はみ出す ときは 内がわへ よせる（前は かべの 前で 大きく なって 上の はしで 切れた）
	var depth := -(cam.global_transform.affine_inverse() * at).z
	var k := clampf(depth / ARROW_REF_DEPTH, 0.1, 1.0)
	(arrow.get_node("Dart") as Node3D).scale = Vector3(k, k, k)
	if depth > cam.near:
		var vs := get_viewport().get_visible_rect().size
		var sp := cam.unproject_position(at)
		var m := ARROW_EDGE * vs.y
		# 上は 場所の 名前の 帯の 下まで（上の はしへ よせると、はんとうめいの 帯の 下に もぐって 見えにくかった）
		var top := m
		if Game.hud != null and is_instance_valid(Game.hud) and Game.hud.has_method("hud_rects"):
			var bar: Rect2 = Game.hud.hud_rects().get("title", Rect2())
			if bar.size.y > 0.0:
				top = maxf(m, bar.end.y + ARROW_HALF * vs.y + 8.0)
		var inside := Vector2(clampf(sp.x, m, vs.x - m), clampf(sp.y, top, vs.y - m))
		if inside != sp:
			at = cam.project_position(inside, depth)
	arrow.global_transform = Transform3D(cb.scaled(sc), at)
	# 行き先を カメラから 見た 向き（x ＝ 右、-z ＝ おく）。0 ＝ まえ（画面の 上）、＋ ＝ 右
	var rel := cb.inverse() * to
	var want := atan2(rel.x, -rel.z)
	arrow_angle = lerp_angle(arrow_angle, want, minf(1.0, 8.0 * delta))
	(arrow.get_node("Dart") as Node3D).rotation.z = -arrow_angle
	# 行き先が すぐ まえに 見えて いる あいだは かくす（矢印が 相手に かぶさる）
	if to.length() < ARROW_NEAR and absf(want) < ARROW_NEAR_ANGLE:
		arrow.visible = false
