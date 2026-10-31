class_name VaultCamera
extends Node3D
## One camera with two compositions. The gameplay controller never changes.
## A sphere sweep is repeated after smoothing so transitions cannot cut through walls.

signal mode_changed(mode_name: String)

const THIRD_PERSON_DISTANCE: float = 6.6
const ISOMETRIC_DISTANCE: float = 16.0
const ISOMETRIC_PITCH: float = 0.91
const ISOMETRIC_YAW: float = 0.785398
const CAMERA_RADIUS: float = 0.24
const SWIPE_SENSITIVITY: float = 0.004

@onready var camera: Camera3D = $Camera3D

var mode_name: String = "THIRD PERSON"
var is_isometric: bool = false
var follow_target: Node3D
var orbit_yaw: float = 0.0
var orbit_pitch: float = 0.32
var mode_blend: float = 0.0
var obstruction_active: bool = false
var _follow_center: Vector3 = Vector3.ZERO
var _has_position: bool = false
var _collision_sphere: SphereShape3D = SphereShape3D.new()


func _ready() -> void:
	_collision_sphere.radius = CAMERA_RADIUS
	# Run after CharacterBody3D movement, avoiding a one-frame tracking offset.
	process_physics_priority = 10


func set_target(value: Node3D) -> void:
	follow_target = value
	_has_position = false


func toggle_mode() -> void:
	is_isometric = not is_isometric
	mode_name = "ISOMETRIC" if is_isometric else "THIRD PERSON"
	mode_changed.emit(mode_name)


func movement_direction(input_vector: Vector2) -> Vector3:
	# Use the rendered camera basis throughout a transition, preserving intuitive
	# screen-relative movement without touching velocity, attacks or targeting.
	var right: Vector3 = camera.global_basis.x
	var back: Vector3 = camera.global_basis.z
	right.y = 0.0
	back.y = 0.0
	return right.normalized() * input_vector.x + back.normalized() * input_vector.y


func reset_position() -> void:
	if not is_instance_valid(follow_target) or not is_node_ready():
		_has_position = false
		return
	_follow_center = _target_center()
	mode_blend = 1.0 if is_isometric else 0.0
	var desired: Vector3 = _follow_center + _camera_offset()
	camera.global_position = _clear_position(_follow_center, desired)
	camera.look_at(_follow_center, Vector3.UP)
	camera.fov = lerpf(64.0, 43.0, mode_blend)
	_has_position = true


func _physics_process(delta: float) -> void:
	var look: Vector2 = InputHub.consume_look_delta()
	if not is_instance_valid(follow_target):
		return
	if InputHub.controls_enabled and not is_isometric:
		orbit_yaw -= look.x * SWIPE_SENSITIVITY
		orbit_pitch = clampf(orbit_pitch + look.y * SWIPE_SENSITIVITY, 0.12, 0.98)
	if not _has_position:
		reset_position()
		return
	mode_blend = move_toward(mode_blend, 1.0 if is_isometric else 0.0, delta * 2.5)
	var anchor: Vector3 = _target_center()
	_follow_center = _follow_center.lerp(anchor, 1.0 - exp(-14.0 * delta))
	var desired: Vector3 = _follow_center + _camera_offset()
	var clear_desired: Vector3 = _clear_position(anchor, desired)
	var candidate: Vector3 = camera.global_position.lerp(clear_desired, 1.0 - exp(-12.0 * delta))
	# Pull inward immediately when a wall enters the sight line; ease outward.
	# Sweep from the actual target, not the lagged aim point, including at corners.
	camera.global_position = _clear_position(anchor, candidate)
	obstruction_active = camera.global_position.distance_to(desired) > 0.8
	var aim: Vector3 = _follow_center
	if camera.global_position.distance_squared_to(aim) < 0.0025:
		aim = camera.global_position + Vector3.FORWARD
	camera.look_at(aim, Vector3.UP)
	camera.fov = lerpf(64.0, 43.0, smoothstep(0.0, 1.0, mode_blend))


func _target_center() -> Vector3:
	return follow_target.global_position + Vector3.UP * 1.35


func _camera_offset() -> Vector3:
	var eased: float = smoothstep(0.0, 1.0, mode_blend)
	var yaw: float = lerp_angle(orbit_yaw, ISOMETRIC_YAW, eased)
	var pitch: float = lerpf(orbit_pitch, ISOMETRIC_PITCH, eased)
	var distance: float = lerpf(THIRD_PERSON_DISTANCE, ISOMETRIC_DISTANCE, eased)
	var offset: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	# A subtle shoulder offset leaves the path immediately ahead visible.
	offset += Vector3(cos(yaw), 0.0, -sin(yaw)) * 0.35 * (1.0 - eased)
	return offset


func _clear_position(anchor: Vector3, desired: Vector3) -> Vector3:
	var motion: Vector3 = desired - anchor
	if motion.length_squared() < 0.0001:
		return desired
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _collision_sphere
	query.transform = Transform3D(Basis.IDENTITY, anchor)
	query.motion = motion
	query.collision_mask = 1 | 8 # World plus camera-only portal veils.
	query.collide_with_areas = false
	query.margin = 0.03
	if follow_target is CollisionObject3D:
		query.exclude = [follow_target.get_rid()]
	var fractions: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
	if fractions.size() >= 1 and fractions[0] < 1.0:
		var safe_fraction: float = maxf(fractions[0] - 0.02 / motion.length(), 0.0)
		return anchor + motion * safe_fraction
	return desired
