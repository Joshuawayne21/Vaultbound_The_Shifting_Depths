class_name AbyssDecoration
extends Node3D
## Cosmetic dressing only. Primitive meshes are shared and instanced in material
## batches; no mesh generation, navigation, collision or gameplay RNG lives here.
const MATERIALS := {
	"stone": preload("res://resources/materials/abyss_stone_light.tres"),
	"rock": preload("res://resources/materials/abyss_stone.tres"),
	"moss": preload("res://resources/materials/abyss_moss.tres"),
	"leaf": preload("res://resources/materials/abyss_leaf.tres"),
	"bark": preload("res://resources/materials/abyss_bark_light.tres"),
	"gold": preload("res://resources/materials/abyss_gold.tres"),
	"glow": preload("res://resources/materials/abyss_glow.tres"),
	"flower": preload("res://resources/materials/abyss_flower.tres"),
	"mushroom": preload("res://resources/materials/abyss_mushroom.tres"),
}
const MAX_BATCHES := 8
const MESHES := {
	"box": preload("res://resources/meshes/abyss_detail_box.tres"),
	"cylinder": preload("res://resources/meshes/abyss_detail_cylinder.tres"),
	"cone": preload("res://resources/meshes/abyss_detail_cone.tres"),
	"leaf": preload("res://resources/meshes/abyss_detail_leaf.tres"),
	"rock": preload("res://resources/meshes/abyss_detail_leaf.tres"),
}
var module_id: StringName
var motif: StringName
var cosmetic_seed := 0
var instance_total := 0
var _batches: Dictionary = {}
var _foliage: Array[MultiMeshInstance3D] = []
var _rng := RandomNumberGenerator.new()

func configure(id: StringName, authored_motif: StringName, expedition_seed: int, room_id: int) -> void:
	module_id = id
	motif = authored_motif
	cosmetic_seed = expedition_seed * 104729 + room_id * 8191 + String(module_id).hash()
	_rng.seed = cosmetic_seed

func _ready() -> void:
	name = "EnchantedDressing"
	add_to_group("visual_quality")
	_wall_dressing()
	_corner_gardens()
	_landmark()
	_flush_batches()
	var settings := get_node_or_null("/root/VisualSettings")
	if settings != null and settings.has_method("apply_to"):
		settings.apply_to(self)

func apply_visual_settings(settings: Dictionary) -> void:
	var density := clampf(float(settings.get("decoration_density", 0.75)), 0.25, 1.0)
	var distance := clampf(float(settings.get("decoration_distance", 34.0)), 20.0, 60.0)
	for visual: MultiMeshInstance3D in _foliage:
		visual.multimesh.visible_instance_count = maxi(1, floori(visual.multimesh.instance_count * density))
		# Whole room visibility is still controlled by AbyssLevel. This only
		# limits tiny cosmetic plants, never wall silhouettes or floor guidance.
		visual.visibility_range_end = distance
		visual.visibility_range_end_margin = 3.0

func fingerprint() -> int:
	var signature: Array = [module_id, motif, cosmetic_seed]
	for child: Node in get_children():
		if child is MultiMeshInstance3D:
			signature.append(child.multimesh.buffer)
	return hash(signature)

func _wall_dressing() -> void:
	# All tall surfaces remain inside the original wall footprint. Doorways
	# keep their full six-metre opening; corner rocks never extend above 2.4m.
	for side in range(4):
		var turn := Basis(Vector3.UP, side * PI * 0.5)
		for x: float in [-10.6, -8.8, -7.0, -5.2, 5.2, 7.0, 8.8, 10.6]:
			var height := _rng.randf_range(0.65, 1.3)
			_add("rock", "rock", "rock", turn * Vector3(x, height * 0.55, -11.7), Vector3(1.72, height, 0.54), Vector3(0, side * PI * 0.5, 0))
			_add("moss", "leaf", "moss", turn * Vector3(x, 0.12, -11.39), Vector3(1.3, 0.19, 0.45), Vector3(0, side * PI * 0.5, 0))
			# Narrow architrave seams break up the otherwise flat slate wall.
			_add("stone", "box", "stone", turn * Vector3(x, 2.15, -11.48), Vector3(1.68, 0.075, 0.055), Vector3(0, side * PI * 0.5, 0))
		for x: float in [-9.6, -5.9, 5.9, 9.6]:
			for section in range(4):
				var y := 0.4 + section * 0.44
				var offset := sin(y * 2.3 + x) * 0.18
				_add("bark", "cylinder", "bark", turn * Vector3(x + offset, y, -11.43), Vector3(0.045, 0.55, 0.045), Vector3(0, side * PI * 0.5, sin(y * 2.3 + x) * 0.3))

func _corner_gardens() -> void:
	var lush := motif in [&"pilgrim_grove", &"fern_court", &"moon_garden", &"secret_orchid", &"spring_seal"]
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		for tuft in range(5 if lush else 3):
			var center := Vector3(corner.x * _rng.randf_range(8.2, 10.5), 0.06, corner.y * _rng.randf_range(8.2, 10.5))
			var angle := _rng.randf() * TAU
			for frond in range(5):
				var yaw := angle + frond * TAU / 5.0
				var length := _rng.randf_range(0.45, 0.9)
				var direction := Vector3(sin(yaw), 0, cos(yaw))
				_add("leaf", "leaf", "leaf", center + direction * length * 0.24 + Vector3.UP * length * 0.22, Vector3(0.12, length, 0.035), Vector3(0.9, yaw, 0), Color(0.8 + _rng.randf() * 0.2, 0.88 + _rng.randf() * 0.12, 0.85, 1))
			if lush or tuft == 0:
				_flower(center + Vector3(0.16, 0, 0.12), angle)
		# Quiet lichen rather than a noisy combat-floor carpet.
		_add("moss", "leaf", "moss", Vector3(corner.x * 9.2, 0.022, corner.y * 9.2), Vector3(2.9, 0.035, 2.7))

func _flower(at: Vector3, angle: float) -> void:
	_add("bark", "cylinder", "bark", at + Vector3.UP * 0.17, Vector3(0.024, 0.34, 0.024))
	for petal in range(4):
		var yaw := angle + petal * PI * 0.5
		var direction := Vector3(sin(yaw), 0, cos(yaw))
		_add("flower", "leaf", "flower", at + Vector3.UP * 0.35 + direction * 0.09, Vector3(0.1, 0.035, 0.22), Vector3(0, yaw, 0))
	_add("glow", "cone", "glow", at + Vector3.UP * 0.37, Vector3(0.065, 0.09, 0.065))

func _landmark() -> void:
	match motif:
		&"pilgrim_grove", &"fern_court", &"root_walk":
			_wall_leaf(-7.5, -11.43, 0.0)
			_wall_leaf(7.5, -11.43, 0.0)
			_floor_leaf(Vector3(-7.3, 0.035, 7.3), 1.4)
		&"pilgrim_gate", &"fallen_court", &"gilded_vault":
			_guardian_relief(-7.5, -11.43)
			_guardian_relief(7.5, -11.43)
			_floor_seal(Vector3.ZERO, 5.6, 8, false)
		&"lost_aqueduct":
			_bridge(Vector3(-8.7, 0.0, 2.3))
			_wall_leaf(7.5, -11.43, 0.0)
		&"cascade_court":
			_bridge(Vector3(-8.0, 0.0, 2.2))
			_floor_seal(Vector3.ZERO, 5.6, 6, true)
		&"prism_grotto":
			for x: float in [-7.5, 7.5]:
				_prism_relief(x, -11.43)
			_floor_seal(Vector3.ZERO, 5.6, 6, false)
		&"moon_garden":
			_floor_leaf(Vector3(-7.3, 0.035, -7.3), 1.6)
			_floor_leaf(Vector3(7.3, 0.035, -7.3), 1.6)
			_wall_leaf(-7.5, -11.43, 0.0)
		&"thorn_seal":
			# Restrained green wall crests leave amber/red for actual hazards.
			_wall_leaf(-7.5, -11.43, PI)
			_wall_leaf(7.5, -11.43, PI)
		&"secret_orchid":
			_guardian_relief(-7.5, -11.43)
			for i in range(5):
				_flower(Vector3(-8.5 + i * 0.28, 0.0, -7.1), i * 0.6)
		&"warden_oath":
			_guardian_relief(-7.5, -11.43)
			_guardian_relief(7.5, -11.43)
			_floor_seal(Vector3.ZERO, 7.2, 12, false)
		&"spring_seal":
			_floor_seal(Vector3(0, 0, -4), 2.0, 8, true)
			_wall_leaf(-7.5, -11.43, 0.0)

func _guardian_relief(x: float, z: float) -> void:
	# Broken guardian masks embedded flush in the original perimeter wall:
	# architectural landmarks without a new obstacle or camera clipping volume.
	_add("stone", "box", "stone", Vector3(x, 1.25, z), Vector3(0.92, 1.25, 0.09), Vector3(0, 0, 0.06))
	_add("rock", "rock", "rock", Vector3(x, 1.36, z + 0.065), Vector3(0.56, 0.76, 0.12))
	for sign_value: float in [-1.0, 1.0]:
		_add("gold", "box", "gold", Vector3(x + sign_value * 0.22, 1.73, z + 0.11), Vector3(0.45, 0.055, 0.05), Vector3(0, 0, sign_value * 0.32))
		_add("glow", "cone", "glow", Vector3(x + sign_value * 0.13, 1.43, z + 0.13), Vector3(0.08, 0.035, 0.04), Vector3(PI * 0.5, 0, 0))
		_add("bark", "cylinder", "bark", Vector3(x + sign_value * 0.42, 1.98, z + 0.04), Vector3(0.11, 0.53, 0.08), Vector3(0, 0, sign_value * -0.45))
	_add("gold", "box", "gold", Vector3(x, 0.48, z + 0.07), Vector3(1.38, 0.08, 0.07))

func _wall_leaf(x: float, z: float, angle: float) -> void:
	for sign_value: float in [-1.0, 1.0]:
		for i in range(3):
			var y := 0.8 + i * 0.34
			_add("gold", "box", "gold", Vector3(x + sign_value * 0.18, y, z), Vector3(0.42, 0.045, 0.045), Vector3(0, 0, sign_value * 0.65 + angle))
	_add("glow", "cone", "glow", Vector3(x, 1.8, z + 0.01), Vector3(0.12, 0.35, 0.045))

func _prism_relief(x: float, z: float) -> void:
	for i in range(3):
		_add("glow", "cone", "glow", Vector3(x + (i - 1) * 0.42, 1.15, z), Vector3(0.26, 0.8 + (1.0 if i == 1 else 0.0), 0.065), Vector3(0, 0, (i - 1) * -0.23))
	_add("gold", "box", "gold", Vector3(x, 0.55, z + 0.015), Vector3(1.6, 0.07, 0.07))

func _floor_seal(center: Vector3, radius: float, pieces: int, silver: bool) -> void:
	for i in range(pieces):
		var yaw := i * TAU / pieces + PI / pieces
		var point := center + Vector3(sin(yaw), 0, cos(yaw)) * radius
		point.y = 0.035
		_add("stone" if silver else "gold", "box", "stone" if silver else "gold", point, Vector3(0.08, 0.018, 0.7), Vector3(0, yaw + 0.25, 0))

func _floor_leaf(center: Vector3, size: float) -> void:
	for sign_value: float in [-1.0, 1.0]:
		for i in range(4):
			_add("gold", "box", "gold", center + Vector3(sign_value * (0.12 + i * 0.08), 0, (i - 1.5) * 0.25) * size, Vector3(0.4, 0.02, 0.035) * Vector3(size, 1, size), Vector3(0, sign_value * -0.65, 0))

func _bridge(center: Vector3) -> void:
	# Thin salvaged slabs sit on the existing navigable floor, across the
	# shallow creek; no raised deck, new collision, holes or navigation links.
	for i in range(6):
		_add("stone", "box", "stone", center + Vector3(0, 0.085, (i - 2.5) * 0.31), Vector3(2.35, 0.055, 0.28), Vector3(0, 0.015 * sin(i), 0))
	for side: float in [-1.0, 1.0]:
		_add("gold", "box", "gold", center + Vector3(side * 1.05, 0.12, 0), Vector3(0.045, 0.018, 1.78))

func _add(key: String, mesh_kind: String, material_key: String, at: Vector3, dimensions: Vector3, angles := Vector3.ZERO, tint := Color.WHITE) -> void:
	if not _batches.has(key):
		_batches[key] = {"shape": mesh_kind, "material": material_key, "transforms": [], "colors": []}
	_batches[key].transforms.append(Transform3D(Basis.from_euler(angles).scaled(dimensions), at))
	_batches[key].colors.append(tint)
	instance_total += 1

func _flush_batches() -> void:
	for key: String in _batches:
		var data: Dictionary = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = MESHES[data.shape]
		mm.instance_count = data.transforms.size()
		for i in range(mm.instance_count):
			mm.set_instance_transform(i, data.transforms[i])
			mm.set_instance_color(i, data.colors[i])
		var visual := MultiMeshInstance3D.new()
		visual.name = key.capitalize() + "Batch"
		visual.multimesh = mm
		visual.material_override = MATERIALS[data.material]
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(visual)
		if key in ["leaf", "flower"]:
			_foliage.append(visual)
	_batches.clear()

