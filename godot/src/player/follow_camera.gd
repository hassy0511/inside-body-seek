class_name FollowCamera
extends Node3D
## 自動追尾カメラ。プレイヤーのうしろに回り込む。カメラ操作はいらない。
## くだ（tube）ステージでは道の向きを「前」にして、まっすぐ進みやすくする。
## ひろい 場所で 船を のりものの ように うごかす ときは（Player.is_steering）、いつも 船の すぐ うしろに つく。
## 船の 向きは なめらかに しか かわらないので、ここでは かるく おくれる だけに する（よわないように ゆらさない）。

## のりものの ときの 回りこむ はやさ（1/秒）。まわって いる あいだの おくれは 約 12 ど、はなせば 0.3 びょうで ほぼ 0
const STEER_FOLLOW := 9.5
## ひろい 場所で かべが うしろに ある とき：まず 上がって 見おろす 角を ふかく して（MAX_RISE まで）きょりを たもつ
## （前は ちぢむ だけで、ドームと パイロットの あたまが 画面の 下 半分を うめた。ブラウザ版の 見なおし）。
## それでも たりない ときは かべを ぬけて 船から MIN_DIST を たもつ。場所の 面は うらを 描かない（stage_clay.gdshader の cull_back）
## ので、ひだの うらからでも 中が 見える。ただし ぬけた 先で 場所の 外（何も ない ところ）が 画面に 入る ときは
## （_sees_void。ブラウザ版で かべを せに まわると 画面の 4 わり ちかくが 平らな 色で うまった）かべの 手前まで よる。
## その ときも 船の まんなかから HARD_DIST より 近よらない（船の 中に 入らない）。
## くだの 場所と 俯瞰は 前の まま（SpringArm3D が かべの 手前で ちぢめる）
const MIN_DIST := 3.6
const HARD_DIST := 2.2
const VOID_FAR := 90.0         # 画面の 向きに この m まで 場所の 面が ない ＝ 外が 見える
const VOID_NEAR := 1.2         # 画面の 向きに この m より 近く 場所の 面が ある ＝ かべを なめて 見て いる（同じく よる）
const KEEP_LEN := 4.2          # うでが この 長さより ちぢむ ときに 上がる（少し ちぢむ だけなら 上がらず、まえが 見える 角の まま）
const MAX_RISE := 0.6          # 見おろす 角を ふやして よい 量（rad。ふつう 19 ど → いちばん 53 ど）
const RISE_STEP := 0.1
const RISE_RATE := 2.0         # 角が 目あてに 近づく はやさ（1/秒）
const RISE_SPEED := 0.6        # 角が かわる いちばん はやい はやさ（rad/秒 ＝ 34 ど/秒）：ぐらっと しない
const RISE_HOLD := 0.8         # 上がった あと この 秒は 下がらない（下がる ときは 半分の はやさ）
const SETTLE_OVER := 1.5       # うでが ふつうの この 倍より 長い あいだ（俯瞰から もどる とちゅう）は すぐ 合わせる
const SHORTEN_RATE := 12.0     # かべで ちぢむ はやさ（1/秒）。おそいと カメラが かべの 外に 出て、外の 色が 画面の はしに 見える
const STRETCH_RATE := 2.0      # かべから はなれて のびる はやさ（1/秒）
const ARM_SPEED := 3.0         # のびる ときの いちばん はやい はやさ（m/秒）
const SHORTEN_SPEED := 6.0     # ちぢむ ときの いちばん はやい はやさ（m/秒）：ぐっと よらない
const SNAP_SPEED := 18.0       # 外が 見える ときに かべの 手前へ よる いちばん はやい はやさ（m/秒。0.3 m/フレーム）
const CAM_RADIUS := 0.3

var target: Node3D = null
var level: Node = null
var yaw := 0.0
var pitch := -0.33
var distance := 5.2   # 絵（雰囲気画）の 近さに 寄せた。ミクロごうは 画面の 幅の 1 割ほど
var height := 0.8   # ミクロごうが 画面の まん中より 少し 下（ふきだしの 上）に 来る 高さ
var tube_mode := false
## 0〜1：はやく はこばれて いる（しょくどうの なみ）。画角を 少し ひろげる（peristalsis.gd が 入れる）
var boost := 0.0
const BOOST_FOV := 9.0
## 俯瞰モード（しんけいパズルで ぜんぶの しんけいを 見せるとき）
var overview_center: Vector3 = Vector3.INF
var _cur_distance := 5.2
var _cur_pitch := -0.33
var _cur_height := 0.8
var _arm: SpringArm3D
var _rise := 0.0       # かべの ために ふやした 見おろす 角（rad）
var _short := 0.0      # かべの ために ちぢめた 長さ（m）
var _rise_hold := 0.0
var _arm_ray: PhysicsRayQueryParameters3D
var _probe: PhysicsShapeQueryParameters3D
var _cam: Camera3D
var _ray: PhysicsRayQueryParameters3D
var _void_ray: PhysicsRayQueryParameters3D


func _ready() -> void:
	_arm = SpringArm3D.new()
	_arm.spring_length = distance
	_arm.collision_mask = 1
	_arm.margin = 0.4
	_arm.shape = SphereShape3D.new()
	(_arm.shape as SphereShape3D).radius = 0.3
	add_child(_arm)
	_cam = Camera3D.new()
	_cam.fov = 68.0
	_cam.near = 0.1
	_cam.far = 400.0
	_arm.add_child(_cam)
	_cam.current = true
	top_level = true


func snap_to_target() -> void:
	if target == null:
		return
	global_position = target.global_position + Vector3.UP * height
	yaw = _desired_yaw()
	_cur_height = height
	_cur_distance = distance
	_cur_pitch = pitch
	_rise = 0.0
	_short = 0.0
	_rise_hold = 0.0
	rotation = Vector3(pitch, yaw, 0)
	if _keeps_distance():
		# もどした すぐ あとも かべの 中から はじめない（目あての 角と 長さに すぐ 合わせる）
		_arm.collision_mask = 0
		_rise = _want_rise(_cur_distance)
		rotation.x = _cur_pitch - _rise
		_short = _cur_distance - _arm_length(_cur_distance)
		_arm.spring_length = _cur_distance - _short
		_cam.position = Vector3(0, 0, _arm.spring_length)


func _desired_yaw() -> float:
	if target == null:
		return yaw
	var dir: Vector3 = target.get("heading") if target.get("heading") != null else Vector3.FORWARD
	if tube_mode and level != null and level.has_method("path_direction_at"):
		var pd: Vector3 = level.path_direction_at(target.global_position)
		if pd.length() > 0.1:
			dir = pd
	return HoverBody.yaw_for(dir)


func set_overview(center: Vector3) -> void:
	overview_center = center


func clear_overview() -> void:
	overview_center = Vector3.INF


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_step(delta)
	# カメラが うごいた あとで 矢印を 置く（船の ほうが 先に うごくので、船の 中で 置くと 1 コマ前の カメラに 合わせて しまう）
	if target.has_method("camera_moved"):
		target.camera_moved(delta)


func _step(delta: float) -> void:
	var ov := overview_center != Vector3.INF
	var want_h := 6.0 if ov else height
	var want_d := 36.0 if ov else distance
	var want_p := -1.25 if ov else pitch
	var want_fov := 85.0 if ov else 68.0 + BOOST_FOV * boost
	var pw := 1.0 - exp(-3.0 * delta)
	_cur_height = lerpf(_cur_height, want_h, pw)
	_cur_distance = lerpf(_cur_distance, want_d, pw)
	_cur_pitch = lerpf(_cur_pitch, want_p, pw)
	_cam.fov = lerpf(_cam.fov, want_fov, pw)
	var focus: Vector3 = target.global_position
	if ov:
		focus = overview_center - Vector3(-sin(yaw), 0, -cos(yaw)) * 9.0
	var want := focus + Vector3.UP * _cur_height
	# はやく はこばれて いる ときは おくれを へらす（まがる くだで カメラが かべの 外に 出ない）
	var w := 1.0 - exp(-(6.0 + 14.0 * boost) * delta)
	global_position = global_position.lerp(want, w)
	var moving := Vector3(target.velocity.x, 0, target.velocity.z).length() > 1.0 if target is CharacterBody3D else true
	var ty := _desired_yaw()
	var yw := 1.0 - exp(-((2.6 + 4.0 * boost) if moving or tube_mode else 0.6) * delta)
	var steering: bool = target.has_method("is_steering") and target.is_steering()
	if steering:
		yw = 1.0 - exp(-STEER_FOLLOW * delta)
	elif not tube_mode:
		# カメラのほうへ下がるときは 回り込まない（くるくる回るのを防ぐ）
		var cam_fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var h: Vector3 = target.get("heading") if target.get("heading") != null else cam_fwd
		yw *= clampf(h.dot(cam_fwd), 0.0, 1.0)
	if ov:
		yw = 0.0
	yaw = lerp_angle(yaw, ty, yw)
	rotation = Vector3(_cur_pitch, yaw, 0)
	if not _keeps_distance():
		# 俯瞰に かわる ときは 上げた 角を なめらかに もどす（くだの 場所は はじめから 0）
		_arm.collision_mask = 1
		_rise = move_toward(_rise, 0.0, RISE_SPEED * delta)
		rotation.x = _cur_pitch - _rise
		_short = 0.0
		_arm.spring_length = _cur_distance
		return
	# かべで きょりが たりない ときは まず 上がる。なめらかに（めあてが かわっても ぐらっと しない）
	_arm.collision_mask = 0
	var want_rise := _want_rise(_cur_distance)
	# 俯瞰から もどる とちゅう（うでが まだ ふつうより ずっと 長い）は、なめらかに せず すぐ 合わせる。なめらかに よると、
	# 36 m 先（場所の 外）から SNAP_SPEED で もどる 1〜2 秒、外が 見えて 船が 見えなかった（のうの しんけいの 見本の あと）
	var settling := _cur_distance > distance * SETTLE_OVER
	# 上がった あと すぐには 下がらない（RISE_HOLD 秒 まって、半分の はやさで）：かべぞいで 上下に ゆれない
	_rise_hold = RISE_HOLD if want_rise > _rise else maxf(_rise_hold - delta, 0.0)
	if settling:
		_rise = want_rise
	elif want_rise > _rise or _rise_hold <= 0.0:
		var down := RISE_SPEED * (1.0 if want_rise > _rise else 0.5) * delta
		_rise += clampf((want_rise - _rise) * (1.0 - exp(-RISE_RATE * delta)), -down, down)
	rotation.x = _cur_pitch - _rise
	var clear := _clear_length(_rise, _cur_distance)
	var hard := _min_length(HARD_DIST)
	var keep := maxf(clear, _min_length(MIN_DIST))
	if keep > clear + 0.05 and _sees_void(keep):
		keep = maxf(clear, hard)
	var want_short := _cur_distance - keep
	if settling:
		_short = want_short
	else:
		var k := 1.0 - exp(-(SHORTEN_RATE if want_short > _short else STRETCH_RATE) * delta)
		_short += clampf((want_short - _short) * k, -ARM_SPEED * delta, SHORTEN_SPEED * delta)
	var arm := maxf(_cur_distance - _short, hard)
	# なめらかに よる とちゅうでも 外が 見える 長さには しない（かべの 手前まで。ただし 1 フレームで とばず SNAP_SPEED で よる）。
	# よった ぶんは _short に のこす（外が 見えなく なっても もとの 長さへ ぱっと もどらず、ARM_SPEED で のびる）
	if not settling and arm > clear + 0.05 and _sees_void(arm):
		arm = maxf(maxf(clear, hard), _arm.spring_length - SNAP_SPEED * delta)
		_short = _cur_distance - arm
	_arm.spring_length = arm
	# SpringArm3D は つぎの フレームで カメラを うごかす ので、ここで おいて おく（1 フレーム おくれて 近よらない）
	_cam.position = Vector3(0, 0, _arm.spring_length)


## かべを よけて きょりを たもつ のは ひろい 場所の ふつうの ときだけ
func _keeps_distance() -> bool:
	return not tube_mode and overview_center == Vector3.INF and is_inside_tree()


## うでの 向き（カメラの 位置への 向き）を 角 rise ぶん 上げた ときに、かべに あたらない 長さ。球（半径 CAM_RADIUS）を うごかして はかる。
## 口の こまかい 面では 1 回 1.5 ミリ秒 かかるので、1 フレームに よぶのは 決まった 角の 1 回だけ（前の SpringArm3D と 同じ 重さ）。
## 角を さがす ほうは 線で はかる（_ray_length）
func _clear_length(rise: float, length: float) -> float:
	var b := Basis.from_euler(Vector3(_cur_pitch - rise, yaw, 0))
	if _probe == null:
		_probe = PhysicsShapeQueryParameters3D.new()
		var sh := SphereShape3D.new()
		sh.radius = CAM_RADIUS
		_probe.shape = sh
		_probe.collision_mask = 1
	_probe.transform = Transform3D(Basis(), global_position)
	_probe.motion = b.z * length
	var r := get_world_3d().direct_space_state.cast_motion(_probe)
	return length * r[0]


## _clear_length の かるい 版：線 3 本（まんなかと、よこへ CAM_RADIUS ずらした 2 本。1 本 0.005 ミリ秒）。角を さがす 7 回に つかう
## （球で 7 回 はかると 口で 1 フレーム 10 ミリ秒を こえた）。ほそい ものは 線の あいだを ぬけるので、決まった 角の 長さは 球で はかる。
## よこへ ずらす とちゅうに かべが ある ときは 0（球が はじめから かべに ふれて いる のと 同じ）
func _ray_length(rise: float, length: float) -> float:
	var b := Basis.from_euler(Vector3(_cur_pitch - rise, yaw, 0))
	var dir := b.z
	var space := get_world_3d().direct_space_state
	if _arm_ray == null:
		_arm_ray = PhysicsRayQueryParameters3D.new()
		_arm_ray.collision_mask = 1
	var best := length
	for s in [0.0, 1.0, -1.0]:
		var from := global_position
		if s != 0.0:
			_arm_ray.from = global_position
			_arm_ray.to = global_position + b.x * (s * CAM_RADIUS)
			if not space.intersect_ray(_arm_ray).is_empty():
				return 0.0
			from = _arm_ray.to
		_arm_ray.from = from
		_arm_ray.to = from + dir * (length + CAM_RADIUS)
		var h := space.intersect_ray(_arm_ray)
		if not h.is_empty():
			best = minf(best, maxf(from.distance_to(h["position"]) - CAM_RADIUS, 0.0))
	return best


## かべで きょりが たりない とき、どれだけ 上がるか：うでが KEEP_LEN（ふつうより みじかい ときは その 長さ）とれる いちばん ひくい 角。
## どの 角でも とれない ときは いちばん 長く とれる 角（同じ くらいなら 高い ほう：かべに おしつけて いる あいだに
## 角が もどって 横から かべを ぬけ、船に よって 見える のを ふせぐ）
func _want_rise(length: float) -> float:
	var need := minf(length, KEEP_LEN)
	var best := 0.0
	var best_len := -1.0
	var rise := 0.0
	while rise <= MAX_RISE + 0.001:
		var l := _ray_length(rise, length)
		if l >= need - 0.05:
			return rise
		if l > best_len - 0.2:
			best = rise
			best_len = maxf(l, best_len)
		rise += RISE_STEP
	return best


## いまの 角で かべに あたらない 長さ（MIN_DIST を たもつ ために かべを ぬける のは、外が 見えない ときだけ）
func _arm_length(length: float) -> float:
	var clear := _clear_length(_rise, length)
	var keep := maxf(clear, _min_length(MIN_DIST))
	if keep > clear + 0.05 and _sees_void(keep):
		keep = maxf(clear, _min_length(HARD_DIST))
	return keep


## うでの 長さ length の ところから 見た 画面に、場所の 外（どの 面の おもてにも あたらない 向き）が 入るか。
## 画面の はしと まんなかの 15 本の 線で しらべる（うらの 面は 描かれないので とおりぬける）。かべの おもてを すぐ そば（VOID_NEAR）で
## なめる ように 見る ときも 同じ（画面の はしが 平らな こい 色で うまる）。かべの うしろに いる ときだけ よぶ
func _sees_void(length: float) -> bool:
	var b := Basis.from_euler(rotation)
	var at := global_position + b.z * length
	var ty := tan(deg_to_rad(_cam.fov) * 0.5)
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)
	var tx := ty * vs.x / maxf(vs.y, 1.0)
	var space := get_world_3d().direct_space_state
	if _void_ray == null:
		_void_ray = PhysicsRayQueryParameters3D.new()
		_void_ray.collision_mask = 1
		_void_ray.hit_back_faces = false
	_void_ray.from = at
	for v in [-1.0, 0.0, 1.0]:
		for u in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var dir := (b * Vector3(u * tx, v * ty, -1.0)).normalized()
			_void_ray.to = at + dir * VOID_FAR
			var h := space.intersect_ray(_void_ray)
			if h.is_empty():
				return true
			# かべの おもてが VOID_NEAR m より 近い：かべを なめる ように 見て、画面の はしが 平らな こい 色で うまる
			if (h["position"] as Vector3).distance_to(at) < VOID_NEAR:
				return true
	return false


## 船の まんなかから dist はなれる うでの 長さ（カメラの 中心は 船より 上・おくれて ついて くる ので、計算で もとめる）
func _min_length(dist: float) -> float:
	if target == null:
		return 0.0
	var u := Basis.from_euler(rotation).z
	var g: Vector3 = global_position - target.global_position
	var b := u.dot(g)
	var c := g.length_squared() - dist * dist
	var disc := b * b - c
	if disc <= 0.0:
		return 0.0
	return maxf(-b + sqrt(disc), 0.0)


func camera() -> Camera3D:
	return _cam
