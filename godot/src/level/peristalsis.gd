class_name Peristalsis
extends Node3D
## しょくどうの なみ（ぜんどううんどう）。場所の "waves" が ある とき Level が 1 つ 作る。
##
## ・なみは スタートの うしろから「every」秒ごとに 来て、道に そって「speed」m/s で すすむ。
##   なみの 先頭（w）では かべの きんにくの わ（GLB の NC_Ring_NNN）が じゅんばんに きゅっと しまる（見た目だけ。当たり判定は 動かない）。
## ・しまる わの すぐ 前（w − ZONE_BACK 〜 w ＋ ZONE_FRONT）に いる ミクロごうは なみに のる：
##   前へは なみの はやさより おそく ならない（player.carry_*）。よこは じぶんで うごける。
##   のった しゅんかんに 音、カメラが 少し ひろがり、左上の「なみに のって ○ センチ」が のびる。
##   出す 数は 本物の からだの 長さ（"waves" の "body_cm"。しょくどうは やく 25 cm）に なおす（ゲームの 道は 400 m より 長い）。
## ・場面の "lumps"（かず）が あれば、のみこんだ ばかりの たべものの かたまりを 出す（カルテ 2）。かたまりは ゆっくり くだり、
##   わが しまる ときに ぐっと おされる。い（胃）の 入口まで いくと スタートの うしろから また 来る（つぎの ひとくち）。
##   ミクロごうが ぶつかると はねかえって なみから おち、少しの あいだ ゆっくり（ハートは へらない）。つぎの なみが また のせて くれる。
## ・こうとうがい（NC_Epiglottis）は ひらいた ところから、ミクロごうが 近づくと とじる（きかんに 入れない）。
## ・い（胃）の 入口の わ（NC_Cardia）は なみが 来ると 少し ひらく。
## ・きかんの あなを ふさぐ TracheaPlug（当たる だけ）は 見えなく する。ゴールは 光の はしらを 消して カメラへ かたむけ、
##   ゴールの 面（道の m）を こえたら 輪の よこを とおっても つく。

const LumpScript := preload("res://src/entities/lump.gd")
const T := preload("res://src/ui/ui_theme.gd")

const ZONE_BACK := 2.0       # しまる わより うしろ 2 m まで（わに おいつかれた ところ）
const ZONE_FRONT := 9.0      # しまる わの 前 9 m まで（ここで なみに つかまる）
const SQUEEZE := 0.3         # わが いちばん しまった ときに 細く なる 分（0.3 ＝ 30%。ゲームの カメラから わかる 大きさ）
const SQUEEZE_W := 6.0       # しまる はば（m。2〜3 本の わが いっしょに しまる）
const SQUEEZE_GLOW := Color("#FFA0A0")   # しまって いる わが ぽっと 明るく なる 色
const OFF_TIME := 0.5        # ぶつかった あと この 秒は どの なみにも のれない（はねかえって いる あいだ）
const BUMP_SLOW := 1.0       # ぶつかって ゆっくりに なる 秒
const LUMP_SPEED := 4.0      # かたまりの ふだんの はやさ（m/s）
const LUMP_PUSH := 7.0       # わが しまる ときに 足される はやさ
const LUMP_SIDE_MAX := 4.2    # かたまりの よこの ずれの はば（m。ゆかの 平らな ところ）
const EPI_OPEN := 55.0       # こうとうがいが ひらいて いる 角度（度）
const EPI_SHUT := 14.0       # とじた ときも 少し うかせる（ふた だと わかる。入口の ふちは なんこつの わが かくす）
const EPI_CLOSE := [14.0, 6.0]   # ふたは わかれ道の この m 手前から この m 手前で とじる（ひらいた ふたを 長く 見せる）
const LUMP_KEEP := 1.4       # かたまりの ふちと 船の あいだに あける きょり（うしろから 来た かたまりは 船を すりぬけない）
const LUMP_END := 6.0        # かたまりは 道の おわりの この m 手前で い（胃）に 入る（その 前の 10 m で 小さく なる）

var level: Node = null
var every := 3.0
var speed := 20.0
var body_cm := 25.0                   # 本物の からだでの 長さ（cm）。出す 数は ride_m を この 長さに なおす
var waves: Array[float] = []          # なみの 先頭の 位置（道の m）
var _wave_ids: Array[int] = []        # waves と 同じ ならびの 番号
var _lost := {}                       # ぶつかって おちた なみの 番号（その なみには もう のれない。つぎの なみは のせて くれる）
var _next_id := 0
var lumps: Array[FoodLump] = []
var riding := false
var ride_m := 0.0                     # なみに のって すすんだ きょり（m）
var ride_count := 0                   # なみに のった 回数
var bumps := 0                        # かたまりに ぶつかった 回数
var _timer := 1.2
var _off := 0.0
var _since_ride := 9.0               # なみから はなれて からの 秒（ちょっと はなれた だけでは「また のった」に しない）
var _last_prog := 0.0
var _best_prog := -INF                # いちばん すすんだ ところ（なみに のって「あたらしく」すすんだ ぶんだけ 数える）
var _goal_prog := INF                 # ゴールの 面（道の m）。ここを こえたら ゴールの よこを とおっても ついた ことに する
var _food_cp: Dictionary = {}         # ものしりカード「food」の 点（いちばん 近い かたまりを さす）
var _boost := 0.0
var _rings: Array[Dictionary] = []    # {node, prog, basis, t}
var _cardia: Dictionary = {}
var _flap: Node3D = null
var _flap_basis := Basis.IDENTITY
var _flap_prog := 0.0
var _flap_ang := EPI_OPEN
var _head: Node3D                     # いちばん 近い なみの 先頭（ものしりカード「wave」の 点）
var _readout: PanelContainer
var _readout_label: Label
var _pulse := 0.0
var _box_on: StyleBoxFlat = T.rounded(Color(1.0, 0.86, 0.35, 0.92), 18, 0)
var _box_off: StyleBoxFlat = T.rounded(Color(1, 1, 1, 0.82), 18, 0)


func setup(lvl: Node) -> void:
	level = lvl
	var cfg: Dictionary = lvl.stage.get("waves", {})
	every = float(cfg.get("every", every))
	speed = float(cfg.get("speed", speed))
	body_cm = float(cfg.get("body_cm", body_cm))


func _ready() -> void:
	process_physics_priority = -10      # プレイヤーより 先に（carry を 入れてから 船が うごく）
	var path: LevelPath = level.path
	for n in level.env.find_children("NC_Ring_*", "MeshInstance3D", true, false):
		_rings.append(_ring_entry(n as Node3D))
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.albedo_color = Color.BLACK
		glow.disable_fog = true
		(n as MeshInstance3D).material_overlay = glow
		_rings[-1]["glow"] = glow
	var c := level.env.find_child("NC_Cardia", true, false) as Node3D
	if c != null:
		_cardia = _ring_entry(c)
	# きかんの あなを ふさぐ「当たるだけ」の 面（見えない。船は きかんに 入れない）
	var plug := level.env.find_child("TracheaPlug", true, false) as GeometryInstance3D
	if plug != null:
		plug.visible = false
	if level.goal != null:
		_goal_prog = path.progress_at(level.goal.global_position)
		# ゴールの 光の はしらは くだの 天井を つきぬけ、輪の うしろの だいだい色の 板に 見える：くだでは 輪だけ（雰囲気画）
		var beam = level.goal.get("_beam")
		if beam is Node3D:
			(beam as Node3D).visible = false
		# 輪を カメラの ほうへ 35 度 かたむける：カメラは 輪と ほぼ 同じ 高さなので、水平の ままだと 黄色い 線に しか 見えない
		var gd: Vector3 = path.direction_at(level.goal.global_position)
		gd.y = 0.0
		if gd.length() > 0.01:
			var rgt := gd.normalized().cross(Vector3.UP)
			level.goal.global_basis = Basis(rgt, deg_to_rad(35.0)) * level.goal.global_basis
	_flap = level.env.find_child("NC_Epiglottis", true, false) as Node3D
	if _flap != null:
		_flap_basis = _flap.transform.basis
		_flap_prog = path.progress_at(_flap.global_position)
		_set_flap(_flap_ang)
	_head = Node3D.new()
	_head.name = "WaveHead"
	add_child(_head)
	_head.global_position = path.start() + Vector3.DOWN * 1000.0   # なみが 来るまでは とおくに
	level._add_card_point("wave", Vector3.INF, _head)
	var n_lumps := int(level.stage.get("lumps", 0))
	for i in n_lumps:
		var lp := LumpScript.new()
		lp.peri = self
		lp.radius = 1.25 + 0.3 * float(i % 3) / 2.0
		lp.prog = lerpf(45.0, path.total - 40.0, (float(i) + 0.5) / float(n_lumps))
		lp.side = [-2.6, 1.2, -0.6, 2.8, 0.2, -1.8, 2.0, -3.0, 0.8, -1.0][i % 10]
		lp.base_speed = LUMP_SPEED * (0.85 + 0.3 * float((i * 7) % 5) / 4.0)
		add_child(lp)
		lumps.append(lp)
		_place_lump(lp, 0.0)
		level._add_card_point("food", Vector3.INF, lp)
	for cp in level.card_points:
		if cp["key"] == "food":
			_food_cp = cp


func _ring_entry(n: Node3D) -> Dictionary:
	var path: LevelPath = level.path
	var p := path.progress_at(n.global_position)
	var a: Vector3 = path.sample(maxf(p - 1.5, 0.0))["position"]
	var b: Vector3 = path.sample(minf(p + 1.5, path.total))["position"]
	var t := (b - a).normalized() if a.distance_to(b) > 0.01 else Vector3.FORWARD
	return {"node": n, "prog": p, "basis": n.global_transform.basis, "t": t}


## 道の むきを のこして、それに 直角な むきだけ k 倍（わが しまる）、むきは f 倍（わが ふとる）
static func squeeze_basis(b0: Basis, t: Vector3, k: float, f: float) -> Basis:
	var cols: Array[Vector3] = []
	for i in 3:
		var e := Vector3.ZERO
		e[i] = 1.0
		cols.append(e * k + t * (t[i] * (f - k)))
	return Basis(cols[0], cols[1], cols[2]) * b0


func squeeze_at(p: float) -> float:
	var s := 0.0
	for w in waves:
		var d := (p - w) / SQUEEZE_W
		if absf(d) < 3.0:
			s = maxf(s, exp(-d * d))
	return s


func _physics_process(delta: float) -> void:
	if level == null or not level.started or level.finished:
		_update_readout(delta)
		return
	var path: LevelPath = level.path
	# なみを 出す・すすめる
	_timer -= delta
	if _timer <= 0.0:
		_timer = every
		waves.append(-8.0)
		_wave_ids.append(_next_id)
		_next_id += 1
	for i in range(waves.size() - 1, -1, -1):
		waves[i] += speed * delta
		if waves[i] > path.total + 12.0:
			waves.remove_at(i)
			_lost.erase(_wave_ids[i])
			_wave_ids.remove_at(i)
	# わを しめる
	for r in _rings:
		var a := squeeze_at(r["prog"])
		(r["node"] as Node3D).global_transform.basis = squeeze_basis(r["basis"], r["t"], 1.0 - SQUEEZE * a, 1.0 + 0.35 * a)
		(r["glow"] as StandardMaterial3D).albedo_color = SQUEEZE_GLOW * (0.32 * a)
	if not _cardia.is_empty():
		var a := 0.0
		for w in waves:
			a = maxf(a, 1.0 - smoothstep(0.0, 14.0, absf(w - float(_cardia["prog"]))))
		(_cardia["node"] as Node3D).global_transform.basis = squeeze_basis(_cardia["basis"], _cardia["t"], 1.0 + 0.12 * a, 1.0)
	var player: Player = level.player
	if player == null:
		return
	var pp := path.progress_at(player.global_position)
	# いちばん 近い なみの 先頭（うしろから 来る なみ）
	var near := INF
	for w in waves:
		if w <= pp + ZONE_FRONT and absf(pp - w) < absf(pp - near):
			near = w
	if near != INF:
		_head.global_position = path.sample(clampf(near + ZONE_FRONT * 0.5, 0.0, path.total))["position"]
	# のる
	_off = maxf(_off - delta, 0.0)
	var on := false
	if _off <= 0.0 and player.control_enabled and player.hearts > 0 and pp < path.total - 6.0:
		var front := ZONE_FRONT + (4.0 if riding else 0.0)   # のって いる ときは 少し ゆるく（ふちで ついたり きえたり しない）
		for i in waves.size():
			if pp >= waves[i] - ZONE_BACK and pp <= waves[i] + front and not _lost.has(_wave_ids[i]):
				on = true
				break
	if on:
		var d: Vector3 = path.direction_at(player.global_position)
		player.carry_dir = d
		player.carry_speed = speed
		if not riding and _since_ride > 0.6:
			ride_count += 1
			_pulse = 1.0
			Sfx.play("heal", 1.15)
		ride_m += maxf(pp - maxf(_best_prog, _last_prog), 0.0)   # もどって もう いちど とおった ところは 数えない
		_since_ride = 0.0
	else:
		_since_ride += delta
	riding = on
	_last_prog = pp
	_best_prog = maxf(_best_prog, pp)
	# ゴールの 面を こえたら つき（ふんもんの 中で ゴールの よこを すりぬけても おくで はさまらない）
	if pp >= _goal_prog and level.goal != null and not level.goal.locked:
		level.goal.on_player_touch(player)
	_boost = lerpf(_boost, 1.0 if on else 0.0, 1.0 - exp(-4.0 * delta))
	if level.camera != null and "boost" in level.camera:
		level.camera.boost = _boost
	# かたまり
	var ship_side := _side_of(player.global_position, pp)
	var nearest: FoodLump = null
	var nd := INF
	for lp in lumps:
		var v := lp.base_speed + LUMP_PUSH * squeeze_at(lp.prog)
		var before := lp.prog
		lp.prog += v * delta
		# うしろから 来て 船に かさなりそうな かたまりは よこへ よける（すりぬけない）。よけきれない ときは 船の うしろで まつ
		var keep := lp.radius + LUMP_KEEP
		if before <= pp and lp.prog > pp - keep and absf(lp.side - ship_side) < keep:
			var away := signf(lp.side - ship_side)
			if away == 0.0:
				away = 1.0 if ship_side <= 0.0 else -1.0
			lp.side = clampf(lp.side + away * 8.0 * delta, -LUMP_SIDE_MAX, LUMP_SIDE_MAX)
			if absf(lp.side - ship_side) < keep:
				lp.prog = minf(lp.prog, pp - keep)
		if lp.prog > path.total - LUMP_END:
			lp.prog = -6.0       # い（胃）に 入った。つぎの ひとくちが うしろから
		lp.scale = Vector3.ONE * clampf((path.total - LUMP_END - lp.prog) / 10.0, 0.05, 1.0)
		_place_lump(lp, v * delta)
		var dd := lp.global_position.distance_squared_to(player.global_position)
		if dd < nd:
			nd = dd
			nearest = lp
	# ものしりカード「food」は いちばん 近い かたまりで 見つかる（どの かたまりの そばを とおっても）
	if nearest != null and not _food_cp.is_empty():
		_food_cp["node"] = nearest
	# こうとうがい：ミクロごうが 近づくと とじる（一度 とじたら ひらかない）
	if _flap != null:
		var want := lerpf(EPI_OPEN, EPI_SHUT, smoothstep(_flap_prog - EPI_CLOSE[0], _flap_prog - EPI_CLOSE[1], pp))
		_flap_ang = minf(_flap_ang, want)
		_set_flap(_flap_ang)
	_update_readout(delta)


## 道の まんなかから 右へ 何 m か（左は −）
func _side_of(pos: Vector3, prog: float) -> float:
	var smp: Dictionary = level.path.sample(clampf(prog, 0.0, level.path.total))
	var dd: Vector3 = smp["direction"]
	var right := Vector3(dd.x, 0.0, dd.z).normalized().cross(Vector3.UP)
	return (pos - (smp["position"] as Vector3)).dot(right)


func _set_flap(deg: float) -> void:
	_flap.transform.basis = _flap_basis * Basis(Vector3.RIGHT, deg_to_rad(deg))


func _place_lump(lp: FoodLump, moved: float) -> void:
	var path: LevelPath = level.path
	var s: Dictionary = path.sample(clampf(lp.prog, 0.0, path.total))
	var d: Vector3 = s["direction"]
	var flat := Vector3(d.x, 0.0, d.z).normalized()
	var right := flat.cross(Vector3.UP)
	var p: Vector3 = s["position"] + d * minf(lp.prog, 0.0) + right * lp.side
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 14.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var y: float = hit["position"].y if not hit.is_empty() else p.y - 2.5
	lp.global_position = Vector3(p.x, y + lp.radius * 0.72, p.z)
	if flat.length() > 0.1:
		lp.look_at(lp.global_position + flat, Vector3.UP)
	lp._body.rotation.x -= moved / lp.radius * 0.6


func on_lump_touched(lp: FoodLump, player: Node) -> void:
	if level == null or level.finished or _off > 0.0:
		return
	_off = OFF_TIME
	# いま のって いる なみ（と すぐ うしろに 来て いる なみ）からは おちる
	var pp: float = level.path.progress_at(player.global_position)
	for i in waves.size():
		if waves[i] > pp - 12.0 and waves[i] < pp + ZONE_FRONT + 6.0:
			_lost[_wave_ids[i]] = true
	riding = false
	bumps += 1
	# かたまりも ぷるんと よこへ ずれる（同じ かたまりに なんども ぶつからない）
	var smp: Dictionary = level.path.sample(clampf(pp, 0.0, level.path.total))
	var dd: Vector3 = smp["direction"]
	var right := Vector3(dd.x, 0.0, dd.z).normalized().cross(Vector3.UP)
	var ship_side: float = (player.global_position - (smp["position"] as Vector3)).dot(right)
	var away := signf(lp.side - ship_side)
	if away == 0.0:
		away = 1.0 if lp.side <= 0.0 else -1.0
	lp.side = clampf(lp.side + away * 2.4, -LUMP_SIDE_MAX, LUMP_SIDE_MAX)
	if absf(lp.side - ship_side) < 1.5:      # はしで これ いじょう ずれない ときは はんたいがわへ
		lp.side = clampf(ship_side - away * 2.6, -LUMP_SIDE_MAX, LUMP_SIDE_MAX)
	lp.wobble()
	player.bump(lp.global_position, 7.0, BUMP_SLOW)
	Sfx.play("pop", 0.75)


## クリアの ひとこと：なみに のった きょりを 足す（のって いなければ そのまま）
func clear_text(base: String) -> String:
	if ride_m < 1.0 or ride_cm() < 1:
		return base
	return "%s なみに のって %d センチ すすんだよ！" % [base, ride_cm()]


## なみに のって すすんだ 長さを 本物の からだの センチに なおした 数（カードの「やく 25 cm」と 合う）
func ride_cm() -> int:
	var total: float = level.path.total if level != null and level.path != null else 0.0
	if total <= 0.0:
		return 0
	return int(round(clampf(ride_m / total, 0.0, 1.0) * body_cm))


# ---------------------------------------------------------------- 左上の「なみに のって ○ センチ」
func _make_readout() -> void:
	if Game.hud == null or not is_instance_valid(Game.hud):
		return
	_readout = PanelContainer.new()
	_readout.name = "RideReadout"
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.position = Vector2(24, 84)
	_readout.add_theme_stylebox_override("panel", _box_off)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(40, 34)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func(): _draw_wave_icon(icon))
	hb.add_child(icon)
	_readout_label = T.label("", 24, T.INK)
	hb.add_child(_readout_label)
	_readout.add_child(hb)
	Game.hud.add_child(_readout)


## なみの しるし（字で なく 形で 描く：ブラウザ版の フォントに 無い 記号を つかわない）
func _draw_wave_icon(c: Control) -> void:
	var col := Color(0.93, 0.42, 0.5) if riding else Color(0.75, 0.55, 0.6)
	for row in 2:
		var pts := PackedVector2Array()
		for i in 21:
			var x := 2.0 + i * 1.8
			pts.append(Vector2(x, 11.0 + row * 12.0 + sin(i * 0.62 + (Time.get_ticks_msec() * 0.008 if riding else 0.0)) * 4.0))
		c.draw_polyline(pts, col, 4.0, true)


func _update_readout(delta: float) -> void:
	if _readout == null:
		_make_readout()   # HUD は Level の あとに できる
	if _readout == null or not is_instance_valid(_readout):
		return
	_pulse = maxf(_pulse - delta * 2.0, 0.0)
	_readout_label.text = ("なみに のってる！ %d センチ" if riding else "なみに のって %d センチ") % ride_cm()
	_readout.add_theme_stylebox_override("panel", _box_on if riding else _box_off)
	_readout.pivot_offset = _readout.size * 0.5
	_readout.scale = Vector2.ONE * (1.0 + Game.HudScene.READOUT_PULSE * _pulse)
	for c in _readout.get_child(0).get_children():
		if not (c is Label):
			c.queue_redraw()


func _exit_tree() -> void:
	if _readout != null and is_instance_valid(_readout):
		_readout.queue_free()
