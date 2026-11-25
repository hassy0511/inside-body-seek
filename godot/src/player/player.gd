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
var hitbox: Area3D
var _blink := 0.0
var _propeller: Node3D
var _respawning := false
var _no_floor_time := 0.0
var _stuck_time := 0.0
var _stuck_from := Vector3.ZERO
var hit_stun := 0.0
var _stuck_count := 0

## テスト用：ここに座標を入れると その方向へ自動で動く
var autopilot_target: Vector3 = Vector3.INF
var autopilot_shoot := false


func _ready() -> void:
	super._ready()
	hover_height = 1.1
	collision_layer = 2
	collision_mask = 1 | 4  # world + enemy bodies(3rd bit = 4)
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
	var pivot := Node3D.new()
	pivot.name = "Arrow"
	pivot.position = Vector3(0, 1.9, 0)
	var mi := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.28
	cone.height = 0.7
	mi.mesh = cone
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.position = Vector3(0, 0, -0.5)
	# 水色（光る 黄色は ゴールだけに する。黄色い 矢印は まうしろから 見ると まるく、ゴールの 輪と まちがえた）。
	# 光らせすぎない：色を 足しすぎると 白い 玉に 見える
	mi.material_override = ModelLib.flat_material(Color(0.30, 0.74, 1.0), Color(0.05, 0.22, 0.42))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)
	pivot.visible = false
	return pivot


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
		if _no_floor_time > 2.5 and level and level.has_method("respawn_position") and not _respawning:
			_no_floor_time = 0.0
			global_position = level.respawn_position()
			velocity = Vector3.ZERO
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
	var target_vel := dir * target_speed + external_push
	target_vel = _tube_start_guard(target_vel)
	if carry_speed > 0.0 and hit_stun <= 0.0:
		# なみに のって いる：前へは なみの はやさまで おされる（よこは じぶんで うごける）
		var along := target_vel.dot(carry_dir)
		if along < carry_speed:
			target_vel += carry_dir * (carry_speed - along)
	steer(target_vel, ACCEL if hit_stun <= 0.0 else 5.0, delta)
	if dir.length() > 0.1 and not is_steering():
		# slerp は 反対向きのとき 軸の正規化エラーを出すことがあるので、普通の補間＋正規化にする
		var h := heading.lerp(dir, minf(1.0, 10.0 * delta))
		heading = h.normalized() if h.length() > 0.05 else dir
	move_and_slide()

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


## うごこうとしているのに 5 秒以上 その場から動けないときは、少し後ろへ押し戻す。
## それでもだめなら チェックポイントへ戻す。
func _check_stuck(delta: float, dir: Vector3) -> void:
	if dir.length() < 0.1 or _respawning or get_slide_collision_count() == 0:
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
			if not is_steering() and level.path.is_valid() and dir.dot(-back) < 0.0:
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
			Game.say("あれ？ ぬけられない。チェックポイントから やりなおそう。", 3.0)
		_stuck_from = global_position


## くだの 場所の はじめ（TUBE_START_GUARD m まで）では、道を うしろへ むかう 速さを けす。
## ひらいた はじめから 船が 外へ 出て おちる ことが ない ように（ひろい 場所と 自動操縦は そのまま）
func _tube_start_guard(v: Vector3) -> Vector3:
	if level == null or camera == null or not camera.get("tube_mode") or not level.has_method("path_direction_at"):
		return v
	if level.path == null or not level.path.is_valid() or level.path.progress_at(global_position) > TUBE_START_GUARD:
		return v
	var pd: Vector3 = level.path_direction_at(global_position)
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
	var rate := TURN_ACCEL if absf(want) > absf(turn_rate) and signf(want) == signf(turn_rate) or turn_rate == 0.0 else TURN_STOP
	turn_rate = move_toward(turn_rate, want, rate * delta)
	if turn_rate != 0.0:
		heading = heading.rotated(Vector3.UP, turn_rate * delta)
		heading.y = 0.0
		heading = heading.normalized()
	var fwd := -input.y
	if fwd < 0.0:
		fwd *= BACK_RATE
	return heading * fwd


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
	# くだの 場所で 行き先が 道の 先に ある ときは 出さない（道は 1 本。まうしろから 見た 矢印は 黄色い まるに 見え、ゴールと まちがえる）
	if level.get("stage") is Dictionary and level.stage.get("kind", "") == "tube" and level.get("path") != null and level.path.is_valid():
		var pd: Vector3 = level.path.direction_at(global_position)
		pd.y = 0.0
		if pd.length() > 0.01 and pd.normalized().dot(to.normalized()) > cos(deg_to_rad(35.0)):
			arrow.visible = false
			return
	arrow.visible = true
	var yaw := HoverBody.yaw_for(to.normalized())
	arrow.rotation.y = lerp_angle(arrow.rotation.y, yaw, minf(1.0, 8.0 * delta))
	arrow.position.y = 1.9 + sin(Time.get_ticks_msec() / 200.0) * 0.1
