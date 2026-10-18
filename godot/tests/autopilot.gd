## 自動操縦（テストとスクリーンショットで共用）。
## いまのミッションの目標へ向かい、くだステージでは道にそって進む。敵には近づきすぎない。


static func drive(lvl, tree: SceneTree) -> void:
	var p = lvl.player
	if p == null or not lvl.started or lvl.finished:
		return
	var target: Vector3 = lvl.current_target_position()
	# しんけいパズル：矢印は こたえを 教えないので、テストでは 正解の順番を 直接 読む
	for m in lvl.missions:
		if m.type == "sequence" and not m.done:
			var seq: Array = lvl.sequence_expected()
			if seq.size() > 0 and not lvl._seq_showing and lvl._seq_input < seq.size():
				target = lvl.neurons[seq[lvl._seq_input]].global_position
			else:
				target = Vector3.INF
			break
	# べん（ドア）：真ん中で止まらず、むこうがわへ 抜ける
	for m in lvl.missions:
		if m.type == "gate" and not m.done and target != Vector3.INF:
			target = target + lvl.path_direction_at(target) * 5.0
			break
	var enemy := nearest_enemy(tree, p.global_position)
	var enemy_target := target != Vector3.INF and enemy != null and enemy.global_position.distance_to(target) < 0.5
	p.autopilot_shoot = enemy != null and enemy.global_position.distance_to(p.global_position) < 13.0
	if enemy_target:
		var away: Vector3 = (p.global_position - target)
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3.FORWARD
		target = target + away.normalized() * 5.5
	var tube: bool = lvl.stage.get("kind", "arena") != "arena" and lvl.path.is_valid()
	if target == Vector3.INF:
		p.autopilot_target = Vector3.INF
		return
	if not tube:
		p.autopilot_target = target
		return
	var d := target.distance_to(p.global_position)
	if d < 12.0:
		p.autopilot_target = target
		return
	var prog: float = lvl.path.progress_at(p.global_position)
	var tprog: float = lvl.path.progress_at(target)
	var step := 7.0 if tprog >= prog - 1.0 else -7.0
	p.autopilot_target = lvl.path.sample(clampf(prog + step, 0.0, lvl.path.total)).position


static func nearest_enemy(tree: SceneTree, pos: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for e in tree.get_nodes_in_group("enemy"):
		if not (e is Node3D) or not e.get("alive"):
			continue
		var d: float = e.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = e
	return best
