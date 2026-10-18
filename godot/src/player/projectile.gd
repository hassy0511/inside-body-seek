extends Area3D
## おくすりバブル。まっすぐ飛んで、敵に当たると take_hit(1)。

var direction := Vector3.FORWARD
var speed := 26.0
var life := 1.3
var owner_level: Node = null
var _mesh: MeshInstance3D


func _ready() -> void:
	collision_layer = 8        # projectile(4)
	collision_mask = 1 | 64    # world + enemy_touch
	monitoring = true
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.35
	cs.shape = s
	add_child(cs)
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	_mesh.mesh = sm
	_mesh.material_override = ModelLib.flat_material(Color(0.6, 0.95, 1.0), Color(0.3, 0.8, 1.0), 0.85)
	add_child(_mesh)
	area_entered.connect(_on_area)
	body_entered.connect(func(_b): _pop())


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	life -= delta
	_mesh.scale = Vector3.ONE * (1.0 + 0.15 * sin(life * 40.0))
	if life <= 0.0:
		_pop()


func _on_area(area: Area3D) -> void:
	if area.is_in_group("enemy_touch"):
		var e := area.get_parent()
		if e and e.has_method("take_hit") and e.get("alive"):
			e.take_hit(1, global_position)
			_pop(true)


func _pop(hit := false) -> void:
	if hit:
		Sfx.play("hit", randf_range(0.9, 1.1))
	set_physics_process(false)
	set_deferred("monitoring", false)
	queue_free()
