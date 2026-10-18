class_name FollowCamera
extends Node3D
## 自動追尾カメラ。プレイヤーのうしろに回り込む。カメラ操作はいらない。
## くだ（tube）ステージでは道の向きを「前」にして、まっすぐ進みやすくする。

var target: Node3D = null
var level: Node = null
var yaw := 0.0
var pitch := -0.33
var distance := 7.5
var height := 2.6
var tube_mode := false
var _arm: SpringArm3D
var _cam: Camera3D
var _ray: PhysicsRayQueryParameters3D


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
	rotation = Vector3(pitch, yaw, 0)


func _desired_yaw() -> float:
	if target == null:
		return yaw
	var dir: Vector3 = target.get("heading") if target.get("heading") != null else Vector3.FORWARD
	if tube_mode and level != null and level.has_method("path_direction_at"):
		var pd: Vector3 = level.path_direction_at(target.global_position)
		if pd.length() > 0.1:
			dir = pd
	return HoverBody.yaw_for(dir)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var want := target.global_position + Vector3.UP * height
	var w := 1.0 - exp(-6.0 * delta)
	global_position = global_position.lerp(want, w)
	var moving := Vector3(target.velocity.x, 0, target.velocity.z).length() > 1.0 if target is CharacterBody3D else true
	var ty := _desired_yaw()
	var yw := 1.0 - exp(-(2.6 if moving or tube_mode else 0.6) * delta)
	yaw = lerp_angle(yaw, ty, yw)
	rotation = Vector3(pitch, yaw, 0)
	_arm.spring_length = distance


func camera() -> Camera3D:
	return _cam
