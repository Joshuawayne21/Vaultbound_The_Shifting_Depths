extends Node3D
## Original native prototypes: a grounded thorn lane and a small spore bed.
## The wrapper owns world alignment, damage, warnings, pooling and lifetime.
const Kit = preload("res://scripts/visual/encounter_visual_kit.gd")
## Tests may retain exact renderer submissions; normal play retains none.
var capture_geometry_for_validation := false
var _kind: StringName = &""
var _state: StringName = &"idle"
var _materials: Dictionary = {}
var _bases: MultiMeshInstance3D
var _tips: MultiMeshInstance3D
var _accents: MultiMeshInstance3D
var _progress := 0.0
var _pulse := 0
var _mote_count := 2
var _motion := 1.0

func configure(kind: StringName, shared_materials: Dictionary = {}) -> bool:
	if is_inside_tree() or not _kind.is_empty() or kind not in [&"root_spike_lane", &"root_spore_patch"]: return false
	var roles: Array[String] = []
	roles.assign(["stone", "root_detail", "flower_bud"] if kind == &"root_spike_lane" else ["root_detail", "fungal_cap", "emissive"])
	var resolved := Kit.resolve(roles, shared_materials)
	if resolved.is_empty(): return false
	_kind = kind
	_materials = resolved
	return true

func _ready() -> void:
	if _kind.is_empty(): return
	add_to_group("visual_quality")
	if _kind == &"root_spike_lane":
		_bases = Kit.batch(self, "StoneSockets", Kit.cylinder(0.28, 0.24, 0.06, 6), _materials.stone, 9)
		_tips = Kit.batch(self, "BarkThorns", Kit.cylinder(0.15, 0.0, 1.0, 5), _materials.root_detail, 9)
		_accents = Kit.batch(self, "AmberSeals", Kit.cylinder(0.20, 0.20, 0.008, 6), _materials.flower_bud, 9)
	else:
		_bases = Kit.batch(self, "FungalStems", Kit.cylinder(0.07, 0.05, 0.22, 6), _materials.root_detail, 6)
		_tips = Kit.batch(self, "FungalCaps", Kit.cylinder(0.22, 0.045, 0.13), _materials.fungal_cap, 6)
		_accents = Kit.batch(self, "SporeMotes", Kit.sphere(0.025), _materials.emissive, 4)
	update_pose(_state, _progress, _pulse)
	var settings := get_node_or_null("/root/VisualSettings")
	if settings != null: settings.apply_to(self)

func update_pose(state: StringName, progress: float, pulse_index: int = 0) -> void:
	_state = state if state in [&"idle", &"warning", &"active"] else &"idle"
	_progress = clampf(progress, 0.0, 1.0) if is_finite(progress) else 0.0
	_pulse = clampi(pulse_index, 0, 3)
	if _bases == null: return
	if _kind == &"root_spike_lane": _pose_spikes()
	else: _pose_spores()

func apply_visual_settings(settings: Dictionary) -> void:
	_mote_count = Kit.mote_count(settings)
	_motion = 0.0 if bool(settings.get("reduced_motion", false)) else 1.0
	update_pose(_state, _progress, _pulse)

func _pose_spikes() -> void:
	# The visible danger silhouette remains identical at every quality. Only
	# nonessential idle motion is reduced; no setting conceals an active thorn.
	var height := 1.08 if _state == &"active" else 0.015
	for index in range(9):
		var at := Vector3(-3.0 + index * 0.75, 0.0, 0.18 if index % 2 == 0 else -0.18)
		Kit.submit(_bases, index, Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.03), capture_geometry_for_validation)
		Kit.submit(_tips, index, Transform3D(Basis.from_scale(Vector3(1, height, 1)), at + Vector3.UP * (0.065 + height * 0.5)), capture_geometry_for_validation)
		Kit.submit(_accents, index, Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.065), capture_geometry_for_validation)

func _pose_spores() -> void:
	var phase := (_progress * TAU + _pulse * 0.7) * _motion
	for index in range(6):
		var angle := TAU * index / 6.0
		var at := Vector3(cos(angle), 0, sin(angle)) * (0.8 if index % 2 == 0 else 1.1)
		Kit.submit(_bases, index, Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.11), capture_geometry_for_validation)
		var swell := 1.0 + (0.07 * sin(phase + index) if _state == &"active" else 0.0)
		Kit.submit(_tips, index, Transform3D(Basis.from_scale(Vector3(swell, 1, swell)), at + Vector3.UP * 0.235), capture_geometry_for_validation)
	for index in range(4):
		var angle := TAU * index / 4.0 + phase * 0.2
		var at := Vector3(cos(angle) * 0.9, 0.43 + 0.08 * sin(phase + index), sin(angle) * 0.9)
		Kit.submit(_accents, index, Transform3D(Basis.IDENTITY, at), capture_geometry_for_validation)
	_accents.multimesh.visible_instance_count = _mote_count if _state in [&"warning", &"active"] else 0

func snapshot() -> Dictionary:
	var result := Kit.counters(self)
	result["kind"] = _kind
	result["state"] = _state
	result["optional_visible"] = _accents.multimesh.visible_instance_count if _kind == &"root_spore_patch" and _accents != null else 0
	result["prototype_art"] = true
	return result
