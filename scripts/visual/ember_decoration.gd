extends "res://scripts/visual/abyss_decoration.gd"
## Original bounded temple relief; no forest/crystal builders or gameplay authority.
const EMBER_MATERIALS := {
	"stone": preload("res://resources/materials/ember/stone_light.tres"),
	"rock": preload("res://resources/materials/ember/stone.tres"),
	"gold": preload("res://resources/materials/ember/metal_trim.tres"),
	"glow": preload("res://resources/materials/ember/emissive.tres"),
	"flower": preload("res://resources/materials/ember/flower.tres")
}

func _ready() -> void:
	name = "EmberDressing"
	add_to_group("visual_quality")
	if _resolved_materials.is_empty(): _resolved_materials = EMBER_MATERIALS.duplicate()
	_soot_panels()
	_ash_pockets()
	_native_floor_landmark()
	_processional_relief()
	_flush_batches()
	var settings := get_node_or_null("/root/VisualSettings")
	if settings != null and settings.has_method("apply_to"): settings.apply_to(self)

func _soot_panels() -> void:
	for side in range(4):
		var turn := Basis(Vector3.UP, side * PI * 0.5)
		for x: float in [-10.4, -8.6, -6.8, -5.0, 5.0, 6.8, 8.6, 10.4]:
			var height := _rng.randf_range(1.05, 1.8)
			_add("rock", "box", "rock", turn * Vector3(x, height * 0.5, -11.57), Vector3(1.42, height, 0.16), Vector3(0, side * PI * 0.5, 0))
			_add("stone", "box", "stone", turn * Vector3(x, 2.15, -11.49), Vector3(1.48, 0.16, 0.04), Vector3(0, side * PI * 0.5, 0))
			_add("gold", "box", "gold", turn * Vector3(x - 0.56, 1.08, -11.46), Vector3(0.055, 1.64, 0.025), Vector3(0, side * PI * 0.5, 0))

func _ash_pockets() -> void:
	# Low muted flakes are cosmetic; no unannounced flame, mine or fake pickup.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		for index in range(3):
			var point := Vector3(corner.x * _rng.randf_range(9.1, 10.5), 0.04, corner.y * _rng.randf_range(9.1, 10.5))
			_add("stone", "box", "stone", point, Vector3(0.30, 0.06, 0.18), Vector3(0, _rng.randf_range(-0.7, 0.7), 0))
			_add("flower", "box", "flower", point + Vector3(0.08, 0.09, 0.04), Vector3(0.12, 0.025, 0.26), Vector3(0.12, 0.3 * index, 0.1))

func _native_floor_landmark() -> void:
	# Exact retained walkable geometry; height is decorative, not traversal.
	match module_id:
		&"corridor_stream": _bridge(Vector3(-8.7, 0, 2.3))
		&"combat_falls":
			_bridge(Vector3(-8.0, 0, 2.2))
			_floor_seal(Vector3.ZERO, 5.6, 6, true)
		&"combat_crystal": _floor_seal(Vector3.ZERO, 5.6, 6, false)
		&"boss_heart": _floor_seal(Vector3.ZERO, 7.2, 12, false)
		&"extraction_spring": _floor_seal(Vector3(0, 0, -4), 2.0, 8, true)
		&"entrance_temple", &"combat_temple", &"treasure_vault": _floor_seal(Vector3.ZERO, 5.6, 8, false)

func _processional_relief() -> void:
	var ids: Array = preload("res://scripts/visual/dungeon_presentation_catalog.gd").EMBER_MODULES.keys()
	var index: int = ids.find(String(module_id))
	story_title = String(motif).replace("_", " ").capitalize()
	var before := instance_total
	for key: String in _batches: _story_starts[key] = _batches[key].transforms.size()
	for side: float in [-1.0, 1.0]:
		var count := 2 + index % 3
		for slot in range(count):
			var x := side * 7.6 + (float(slot) - float(count - 1) * 0.5) * 0.46
			var height := 0.42 + 0.09 * ((slot + index) % 3)
			_add("stone", "box", "stone", Vector3(x, 1.36, -11.43), Vector3(0.31, height, 0.05))
			_add("gold", "box", "gold", Vector3(x, 1.36 + height * 0.5, -11.425), Vector3(0.37, 0.07, 0.055))
			_add("glow", "box", "glow", Vector3(x, 1.35, -11.395), Vector3(0.055, height * 0.45, 0.012))
		_add("gold", "box", "gold", Vector3(side * 7.6, 0.91, -11.44), Vector3(2.0, 0.05, 0.04))
	story_instance_total = instance_total - before
