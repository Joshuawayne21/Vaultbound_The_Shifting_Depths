extends Node3D
## Original nonblocking native prototype. A shallow seal and transparent return
## glyph, distinct from the final extraction prism. The owner supplies state;
## this presenter cannot judge safety, heal, save, interact or travel.
const Kit = preload("res://scripts/visual/encounter_visual_kit.gd")
const MATERIALS := {
	"stone": preload("res://resources/materials/abyss_stone.tres"),
	"water": preload("res://resources/materials/abyss_water.tres"),
	"metal_trim": preload("res://resources/materials/abyss_gold.tres"),
	"emissive": preload("res://resources/materials/abyss_glow.tres"),
}
var _materials: Dictionary = {}
var _ordinal := 0
var _state: StringName = &"sealed"
var _glyph: MeshInstance3D
var _glyph_material: StandardMaterial3D
var _motes: Array[MeshInstance3D] = []
var _clock := 0.0
var _motion := 1.0
var _mote_count := 1

func configure(shared_materials: Dictionary = {}, ordinal: int = 0) -> bool:
	if is_inside_tree() or not _materials.is_empty() or ordinal not in [0, 1]: return false
	var selected := {}
	for role: String in MATERIALS:
		var material: Variant = MATERIALS[role] if shared_materials.is_empty() else shared_materials.get(role)
		if not material is Material: return false
		selected[role] = material
	if not selected.emissive is StandardMaterial3D: return false
	_materials = selected
	_ordinal = ordinal
	return true

func _ready() -> void:
	if _materials.is_empty(): return
	add_to_group("visual_quality")
	Kit.piece(self, "ShallowStoneLip", Kit.cylinder(0.68, 0.64, 0.06, 12), _materials.stone, Vector3(0, 0.03, 0))
	Kit.piece(self, "WaterSeal", Kit.cylinder(0.53, 0.53, 0.006), _materials.water, Vector3(0, 0.065, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.58
	rim.outer_radius = 0.64
	rim.rings = 16
	rim.ring_segments = 4
	Kit.piece(self, "BronzeRim", rim, _materials.metal_trim, Vector3(0, 0.06, 0))
	_glyph_material = _materials.emissive.duplicate() as StandardMaterial3D
	_glyph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glyph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glyph_material.no_depth_test = false
	_glyph = Kit.piece(self, "OpenReturnGlyph", _chevrons(), _glyph_material, Vector3(0, 0.25, 0))
	for index in range(2):
		_motes.append(Kit.piece(self, "ReturnMote%d" % index, Kit.sphere(0.022), _glyph_material, Vector3.ZERO))
	_pose()
	var settings := get_node_or_null("/root/VisualSettings")
	if settings != null: settings.apply_to(self)

func _chevrons() -> ArrayMesh:
	var bar := BoxMesh.new()
	bar.size = Vector3(0.065, 0.42, 0.035)
	var points := PackedVector3Array()
	for height: float in [0.35, 0.75]:
		for side: float in [-1.0, 1.0]:
			var transform := Transform3D(Basis(Vector3.BACK, side * 0.70), Vector3(side * 0.135, height, 0))
			for point: Vector3 in bar.get_faces(): points.append(transform * point)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func set_state(state: StringName) -> void:
	if state not in [&"sealed", &"ready", &"departed"] or (_state == &"departed" and state != &"departed"): return
	_state = state
	_pose()

func tick_visual(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or _state != &"ready" or _motion == 0.0: return
	_clock = fmod(_clock + minf(delta, 0.1) * _motion, TAU * 10.0)
	_pose()

func apply_visual_settings(settings: Dictionary) -> void:
	_motion = 0.0 if bool(settings.get("reduced_motion", false)) else 1.0
	if _motion == 0.0: _clock = 0.0
	var quality := clampi(int(settings.get("quality", 1)), 0, 2)
	_mote_count = floori(float(quality) * clampf(float(settings.get("ambient_density_percent", 100)) / 100.0, 0.0, 1.0))
	if bool(settings.get("reduced_effects", false)): _mote_count = mini(_mote_count, 1)
	_pose()

func _pose() -> void:
	if _glyph == null: return
	var ready := _state == &"ready"
	_glyph.scale.y = 1.0 if ready else 0.30
	_glyph.position.y = 0.25 + (sin(_clock * 1.4) * 0.025 if ready else 0.0)
	_glyph_material.albedo_color = Color(0.48, 0.92, 0.9, 0.64) if ready else Color(0.32, 0.44, 0.5, 0.38)
	for index in range(_motes.size()):
		var angle := _clock * 0.6 + PI * index + _ordinal * 0.4
		_motes[index].position = Vector3(cos(angle) * 0.38, 0.48 + index * 0.34 + sin(angle) * 0.04, sin(angle) * 0.38)
		_motes[index].visible = ready and index < _mote_count

func snapshot() -> Dictionary:
	var result := Kit.counters(self)
	result["state"] = _state
	result["ordinal"] = _ordinal
	result["optional_visible"] = _mote_count if _state == &"ready" else 0
	result["prototype_art"] = true
	return result
