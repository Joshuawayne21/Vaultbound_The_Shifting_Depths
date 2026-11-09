extends Node3D
## Passive native sphere. Only the cast's detached cursor supplies its pose.
const Definition = preload("res://scripts/expedition/hazard_definition.gd")
const Kit = preload("res://scripts/visual/encounter_visual_kit.gd")
var _profile: Dictionary = {}
var _shape: Dictionary = {}
var _material: Material
var _stone: MeshInstance3D
var _state: StringName = &"idle"
var _distance := 0.0

func configure(profile: Dictionary, shape: Dictionary, materials: Dictionary = {}) -> bool:
	if is_inside_tree() or not _profile.is_empty() or not Definition.valid_shape(profile, shape) or profile.version != 3: return false
	var roles: Array[String] = ["stone"]
	var resolved := Kit.resolve(roles, materials)
	if resolved.is_empty(): return false
	_profile = profile.duplicate(true)
	_shape = shape.duplicate(true)
	_material = resolved.stone
	return true

func _ready() -> void:
	if _profile.is_empty(): return
	top_level = true
	global_transform = Transform3D.IDENTITY
	var mesh := SphereMesh.new()
	mesh.radius = float(_profile.radius)
	mesh.height = float(_profile.radius) * 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	_stone = MeshInstance3D.new()
	_stone.name = "RollingStone"
	_stone.mesh = mesh
	_stone.material_override = _material
	_stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stone.position = Vector3(_shape.start) + Vector3.UP * float(_profile.radius)
	add_child(_stone)
	if not is_instance_valid(self) or not is_inside_tree() or is_queued_for_deletion(): return
	visible = false

func update_travel(state: StringName, travel: Dictionary) -> void:
	if not is_instance_valid(_stone) or travel.size() != 4 or not travel.get("distance") is float \
			or not travel.get("position") is Vector3 or not travel.get("remaining_distance") is float \
			or not travel.get("active") is bool: return
	var distance := float(travel.distance)
	if not is_finite(distance) or distance < 0.0 or distance > float(_profile.axis_length) \
			or not Vector3(travel.position).is_finite(): return
	var expected: Vector3 = Vector3(_shape.start).lerp(_shape.end, distance / float(_profile.axis_length))
	if expected.distance_to(travel.position) > 0.0001: return
	_distance = distance
	_state = state if state in [&"warning", &"active"] else &"idle"
	var direction: Vector3 = (Vector3(_shape.end) - Vector3(_shape.start)).normalized()
	_stone.transform = Transform3D(Basis(Vector3.UP.cross(direction), distance / float(_profile.radius)),
		expected + Vector3.UP * float(_profile.radius))
	visible = _state != &"idle"

func update_pose(_state_value: StringName, _progress: float, _pulse_index: int = 0) -> void:
	# Existing pooled typed/legacy retirement calls only this harmless idle seam.
	_state = &"idle"
	visible = false

func snapshot() -> Dictionary:
	return {"profile": _profile.duplicate(true), "shape": _shape.duplicate(true), "state": String(_state),
		"distance": _distance, "meshes": 1 if is_instance_valid(_stone) else 0, "materials": 1,
		"radial_segments": 32, "rings": 16, "pose": _stone.transform if is_instance_valid(_stone) else Transform3D.IDENTITY}
