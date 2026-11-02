extends "res://scripts/visual/abyss_decoration.gd"
## Original mineral dressing. Reuses bounded batching only, never forest builders.
const CRYSTAL_MATERIALS := {
	"stone": preload("res://resources/materials/crystal/stone_light.tres"),
	"rock": preload("res://resources/materials/crystal/stone.tres"),
	"gold": preload("res://resources/materials/crystal/metal_trim.tres"),
	"glow": preload("res://resources/materials/crystal/emissive.tres"),
	"flower": preload("res://resources/materials/crystal/flower.tres")
}

func _ready() -> void:
	name = "CrystalDressing"
	add_to_group("visual_quality")
	if _resolved_materials.is_empty(): _resolved_materials = CRYSTAL_MATERIALS.duplicate()
	_wall_facets()
	_mineral_pockets()
	_native_floor_landmark()
	_survey_relief()
	_flush_batches()
	var settings := get_node_or_null("/root/VisualSettings")
	if settings != null and settings.has_method("apply_to"): settings.apply_to(self)

func _wall_facets() -> void:
	for side in range(4):
		var turn := Basis(Vector3.UP, side * PI * 0.5)
		for x: float in [-10.5, -8.8, -7.1, -5.4, 5.4, 7.1, 8.8, 10.5]:
			var height := _rng.randf_range(0.8, 1.7)
			_add("rock", "box", "rock", turn * Vector3(x, height * 0.5, -11.57), Vector3(1.5, height, 0.18), Vector3(0, side * PI * 0.5, 0))
			_add("stone", "box", "stone", turn * Vector3(x, 2.18, -11.48), Vector3(1.48, 0.09, 0.04), Vector3(0, side * PI * 0.5, 0))
			_add("gold", "box", "gold", turn * Vector3(x + 0.25, 1.08, -11.455), Vector3(0.035, 1.6, 0.025), Vector3(0, side * PI * 0.5, 0))

func _mineral_pockets() -> void:
	# These low cosmetic pockets do not occupy the ±5m actor sockets or doors.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		for index in range(4):
			var at := Vector3(corner.x * _rng.randf_range(9.0, 10.4), 0, corner.y * _rng.randf_range(9.0, 10.4))
			var height := _rng.randf_range(0.17, 0.34)
			_add("flower", "cone", "flower", at + Vector3.UP * height * 0.5, Vector3(0.18, height, 0.18))
			_add("rock", "box", "rock", at + Vector3(0.10, 0.035, 0.10), Vector3(0.29, 0.07, 0.24))

func _native_floor_landmark() -> void:
	# Retain the exact low bridge and floor-seal footprints of their Rootbound
	# logical modules. Other new marks stay in the perimeter, below warnings.
	match module_id:
		&"corridor_stream": _bridge(Vector3(-8.7, 0, 2.3))
		&"combat_falls":
			_bridge(Vector3(-8.0, 0, 2.2))
			_floor_seal(Vector3.ZERO, 5.6, 6, true)
		&"combat_crystal": _floor_seal(Vector3.ZERO, 5.6, 6, false)
		&"boss_heart": _floor_seal(Vector3.ZERO, 7.2, 12, false)
		&"extraction_spring": _floor_seal(Vector3(0, 0, -4), 2.0, 8, true)
		&"entrance_temple", &"combat_temple", &"treasure_vault": _floor_seal(Vector3.ZERO, 5.6, 8, false)

func _survey_relief() -> void:
	# A distinct count/arrangement for every module, permanently on the north
	# wall apron. It cannot resemble a pickup or compete with active danger.
	var ids: Array = preload("res://scripts/visual/dungeon_presentation_catalog.gd").CRYSTAL_MODULES.keys()
	var index: int = ids.find(String(module_id))
	story_title = String(motif).replace("_", " ").capitalize()
	var before := instance_total
	for key: String in _batches: _story_starts[key] = _batches[key].transforms.size()
	var count := 3 + index % 5
	for side: float in [-1.0, 1.0]:
		for slot in range(count):
			var x := side * 7.5 + (float(slot) - float(count - 1) * 0.5) * 0.25
			var height := 0.35 + 0.08 * ((slot + index) % 4)
			_add("glow", "cone", "glow", Vector3(x, 1.38, -11.43), Vector3(0.13, height, 0.045), Vector3(0, 0, side * 0.12))
		_add("gold", "box", "gold", Vector3(side * 7.5, 0.88, -11.44), Vector3(1.7, 0.05, 0.04))
	story_instance_total = instance_total - before
