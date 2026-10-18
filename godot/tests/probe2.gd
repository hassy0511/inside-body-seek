extends SceneTree
func _init() -> void:
	for n in ["stage_esophagus", "stage_vessel"]:
		var ps = load("res://assets/models/stages/%s.glb" % n)
		var env: Node3D = ps.instantiate()
		root.add_child(env)
		for mi in env.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var faces := m.mesh.get_faces()
			var nan := 0
			var big := 0
			for v in faces:
				if is_nan(v.x) or is_nan(v.y) or is_nan(v.z):
					nan += 1
				elif v.length() > 1000.0:
					big += 1
			print("%s/%s aabb=%s faces=%d nan=%d big=%d xform=%s surfaces=%d" % [n, m.name, m.get_aabb(), faces.size() / 3, nan, big, m.transform.origin, m.mesh.get_surface_count()])
		env.queue_free()
	quit()
