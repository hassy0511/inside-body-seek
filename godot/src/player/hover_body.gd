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


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.collision_mask = 1  # world
	_ray_query.exclude = [get_rid()]


func hover_step(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	_ray_query.from = global_position + Vector3.UP * 1.5
	_ray_query.to = global_position + Vector3.DOWN * 14.0
	var hit := space.intersect_ray(_ray_query)
	if not hit.is_empty() and hit["normal"].y > 0.35:
		floor_found = true
		floor_point = hit["position"]
		floor_normal = hit["normal"]
		var target_y: float = floor_point.y + hover_height
		var dy := target_y - global_position.y
		velocity.y = clampf(dy * hover_spring, -14.0, 14.0)
	else:
		floor_found = false
		velocity.y = move_toward(velocity.y, -5.0, 12.0 * delta)


func steer(target_vel: Vector3, accel: float, delta: float) -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	hv = hv.move_toward(Vector3(target_vel.x, 0.0, target_vel.z), accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z


static func yaw_for(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)
