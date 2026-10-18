extends SceneTree
## 地形の当たり判定を調べる：各ステージの MK_player / MK_path / MK_goal の位置から下にレイを飛ばし、
## ゆかが見つからない場所があれば失敗（終了コード 1）にする。
##   godot --headless --path godot --script res://tests/probe.gd
var failures := 0


func _init() -> void:
	var names: Array = []
	for s in StageDB.STAGES:
		names.append(s["env"])
	for n in names:
		var ps = load("res://assets/models/stages/%s.glb" % n)
		var env: Node3D = ps.instantiate()
		root.add_child(env)
		var bodies := 0
		for mi in env.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.name.begins_with("NC_"):
				continue
			m.create_trimesh_collision()
			for c in m.get_children():
				if c is StaticBody3D:
					bodies += 1
					c.collision_layer = 1
		await physics_frame
		await physics_frame
		var space := root.world_3d.direct_space_state
		var pts: Array = []
		for mk in env.find_children("MK_*", "Node3D", true, false):
			var nm := String(mk.name)
			if nm == "MK_player" or nm.begins_with("MK_path_") or nm == "MK_goal" or nm.begins_with("MK_enemy") or nm.begins_with("MK_friend") or nm.begins_with("MK_pickup") or nm.begins_with("MK_neuron") or nm.begins_with("MK_checkpoint"):
				pts.append([nm, mk.global_position])
		pts.sort_custom(func(a, b): return a[0] < b[0])
		var bad := 0
		for p in pts:
			var from: Vector3 = p[1] + Vector3.UP * 4.0
			var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1)
			var hit := space.intersect_ray(q)
			var ok := not hit.is_empty() and hit.normal.y > 0.35 and (p[1].y - hit.position.y) > -3.5 and (p[1].y - hit.position.y) < 6.0
			if not ok:
				bad += 1
				failures += 1
				print("  [probe] %s/%s at %s -> %s" % [n, p[0], p[1], ("floor y=%.2f n=%s (%s)" % [hit.position.y, hit.normal, hit.collider.get_parent().name]) if hit else "NO FLOOR"])
		print("== %s bodies=%d markers_checked=%d bad=%d" % [n, bodies, pts.size(), bad])
		env.queue_free()
		await process_frame
	print("PROBE RESULT: %s" % ("OK" if failures == 0 else "%d problem(s)" % failures))
	quit(1 if failures > 0 else 0)
