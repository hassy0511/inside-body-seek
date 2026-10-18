class_name HoverBody
extends CharacterBody3D
## ゆかの上を ふわふわ浮く体の共通部分（プレイヤーも敵も使う）。
## 下向きにレイを飛ばして「ゆか」を探し、hover_height の高さに ばねで寄せる。

@export var hover_height := 1.0
@export var hover_spring := 9.0

var floor_found := false
var floor_point := Vector3.ZERO
var floor_normal := Vector3.UP
var _ray_query: PhysicsRayQueryParameters3D
var _shadow: MeshInstance3D


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.collision_mask = 1  # world
	_ray_query.exclude = [get_rid()]
	_shadow = _make_shadow(0.7)
	add_child(_shadow)


## ゆかに落ちる丸いかげ（見やすさのため）
func _make_shadow(radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 20
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.05, 0.1, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	mi.material_override = m
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func hover_step(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	_ray_query.from = global_position + Vector3.UP * 4.0
	_ray_query.to = global_position + Vector3.DOWN * 16.0
	var hit := space.intersect_ray(_ray_query)
	if not hit.is_empty() and hit["normal"].y > 0.35:
		floor_found = true
		floor_point = hit["position"]
		floor_normal = hit["normal"]
		var target_y: float = floor_point.y + hover_height
		var dy := target_y - global_position.y
		velocity.y = clampf(dy * hover_spring, -14.0, 14.0)
		if _shadow:
			_shadow.visible = true
			_shadow.global_position = floor_point + Vector3.UP * 0.06
			var h := clampf(global_position.y - floor_point.y, 0.0, 4.0)
			_shadow.scale = Vector3.ONE * (1.0 - h * 0.12)
	else:
		floor_found = false
		velocity.y = move_toward(velocity.y, -5.0, 12.0 * delta)
		if _shadow:
			_shadow.visible = false


func steer(target_vel: Vector3, accel: float, delta: float) -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	hv = hv.move_toward(Vector3(target_vel.x, 0.0, target_vel.z), accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z


static func yaw_for(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)
