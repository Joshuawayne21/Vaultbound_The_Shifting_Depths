extends Node3D
## Small rooted pod prototype. The parent core alone owns health, collision,
## targeting, defenders and death. This presenter never processes itself.
const Kit = preload("res://scripts/visual/encounter_visual_kit.gd")
## Tests may retain exact renderer submissions; normal play retains none.
var capture_geometry_for_validation := false
var _materials: Dictionary = {}
var _state: StringName = &"dormant"
var _body: Node3D
var _ribs: MultiMeshInstance3D
var _windows: MultiMeshInstance3D
var _motes: MultiMeshInstance3D
var _clock := 0.0
var _death := 0.0
var _motion := 1.0
var _mote_count := 2

func configure(shared_materials: Dictionary = {}) -> bool:
	if is_inside_tree() or not _materials.is_empty(): return false
	var roles: Array[String] = ["root_shell", "root_detail", "fungal_cap", "emissive"]
	_materials = Kit.resolve(roles, shared_materials)
	return not _materials.is_empty()

func _ready() -> void:
	if _materials.is_empty(): return
	add_to_group("visual_quality")
	_body = Node3D.new()
	_body.name = "RootedPod"
	add_child(_body)
	Kit.piece(_body, "RootFoot", Kit.cylinder(0.74, 0.64, 0.18), _materials.root_shell, Vector3(0, 0.09, 0))
	Kit.piece(_body, "PodShell", Kit.cylinder(0.62, 0.53, 1.25), _materials.root_shell, Vector3(0, 0.75, 0))
	Kit.piece(_body, "FungalCrown", Kit.cylinder(0.61, 0.22, 0.30), _materials.fungal_cap, Vector3(0, 1.48, 0))
	_ribs = Kit.batch(_body, "RootRibs", Kit.cylinder(0.065, 0.04, 1.0, 6), _materials.root_detail, 3)
	_windows = Kit.batch(_body, "EmeraldWindows", Kit.sphere(0.11), _materials.emissive, 3)
	_motes = Kit.batch(_body, "HaloMotes", Kit.sphere(0.025), _materials.emissive, 4)
	_pose()
	var settings := get_node_or_null("/root/VisualSettings")
	if settings != null: settings.apply_to(self)

func set_state(state: StringName) -> void:
	if state not in [&"dormant", &"warning", &"active", &"paused", &"dead"]: return
	if _state == &"dead" and state != &"dead": return
	_state = state
	_pose()

func tick_visual(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or _state in [&"dormant", &"paused"]: return
	var step := minf(delta, 0.25)
	if _state == &"dead": _death = minf(_death + step, 0.6)
	else: _clock = fmod(_clock + step * _motion, TAU * 10.0)
	_pose()

func apply_visual_settings(settings: Dictionary) -> void:
	_mote_count = Kit.mote_count(settings)
	_motion = 0.0 if bool(settings.get("reduced_motion", false)) else 1.0
	if _motion == 0.0: _clock = 0.0
	_pose()

func _pose() -> void:
	if _body == null: return
	_body.scale.y = 1.0 - 0.75 * (_death / 0.6)
	var awake := _state in [&"warning", &"active"]
	var opening := 0.035 if awake else 0.0
	for index in range(3):
		var angle := TAU * index / 3.0
		var axis := Vector3(cos(angle), 0, sin(angle))
		var rib_at := axis * (0.65 + opening) + Vector3.UP * 0.75
		Kit.submit(_ribs, index, Transform3D(Basis(Vector3.UP, -angle), rib_at), capture_geometry_for_validation)
		var glow_scale := 0.80 + (0.12 * sin(_clock * 3.0 + index) if awake else 0.0)
		Kit.submit(_windows, index, Transform3D(Basis.from_scale(Vector3.ONE * glow_scale), axis * 0.57 + Vector3.UP * 1.0), capture_geometry_for_validation)
	for index in range(4):
		var angle := TAU * index / 4.0 + _clock * 0.15
		var at := Vector3(cos(angle) * 0.63, 1.62 + 0.07 * sin(_clock + index), sin(angle) * 0.63)
		Kit.submit(_motes, index, Transform3D(Basis.IDENTITY, at), capture_geometry_for_validation)
	_motes.multimesh.visible_instance_count = _mote_count if awake else 0

func snapshot() -> Dictionary:
	var result := Kit.counters(self)
	result["state"] = _state
	result["optional_visible"] = _motes.multimesh.visible_instance_count if _motes != null else 0
	result["prototype_art"] = true
	return result
