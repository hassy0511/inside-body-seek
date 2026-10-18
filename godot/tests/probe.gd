extends SceneTree
## 地形の当たり判定を調べる：各ステージの MK_player と MK_path の位置から下にレイを飛ばす
func _init() -> void:
	var names := ["stage_esophagus", "stage_vessel", "stage_mouth", "stage_stomach", "stage_heart"]
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
			if mk.name == "MK_player" or mk.name.begins_with("MK_path_00") or mk.name == "MK_goal":
				pts.append([mk.name, mk.global_position])
		pts.sort_custom(func(a, b): return a[0] < b[0])
		print("== %s bodies=%d" % [n, bodies])
		for p in pts.slice(0, 6):
			var from: Vector3 = p[1] + Vector3.UP * 1.5
			var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1)
			var hit := space.intersect_ray(q)
			var q2 := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 30.0, 1)
			var hit2 := space.intersect_ray(q2)
			print("  %s at %s -> down: %s | up: %s" % [p[0], p[1], ("y=%.2f n=%s %s" % [hit.position.y, hit.normal, hit.collider.get_parent().name]) if hit else "none", ("y=%.2f n=%s" % [hit2.position.y, hit2.normal]) if hit2 else "none"])
		env.queue_free()
		await process_frame
	quit()
