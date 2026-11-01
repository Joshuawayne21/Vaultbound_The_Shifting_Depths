class_name AbyssRoom
extends Node3D
## Handcrafted PackedScene module. Runtime only selects existing door fillers;
## floor, architecture, props and collision are authored resources, not generated meshes.

@export var module_id: StringName = &"entrance_grove"
@export var room_kind: StringName = &"entrance"
@export var chest_anchor := Vector3(6.0, 0.0, 6.0)
@export var spawn_points: Array[Vector3] = [
	Vector3(-5, 0.15, -5), Vector3(5, 0.15, -5),
	Vector3(-5, 0.15, 5), Vector3(5, 0.15, 5),
]
@export var visual_motif: StringName = &"pilgrim_grove"
var openings: Array[StringName] = []
var cosmetic_seed := 1
var cosmetic_room_id := 0
var _capture_geometry_for_validation := false
var dressing: AbyssDecoration
var ambient_fauna: VaultAmbientFauna
var _presentation: Dictionary = {}
var _presentation_materials: Dictionary = {}

func configure_presentation(issued: Dictionary, shared_materials: Dictionary) -> bool:
	# Content worlds provide one reconstructed material set before attachment.
	# Existing standalone/depth fixtures retain their authored native resources.
	var schema := preload("res://scripts/visual/dungeon_presentation.gd")
	if is_inside_tree() or not _presentation.is_empty() or not schema.valid_snapshot(issued):
		return false
	if not issued.modules.has(String(module_id)) or not schema._keys(shared_materials, schema.ROLE_PATHS.keys()):
		return false
	for role: String in schema.ROLE_PATHS:
		if not shared_materials[role] is Material: return false
	var module: Dictionary = issued.modules[String(module_id)]
	if scene_file_path != module.scene or String(visual_motif) != module.motif:
		return false
	_presentation = issued.duplicate(true)
	_presentation_materials = shared_materials.duplicate()
	schema.apply_materials(self, _presentation_materials)
	return true

func configure_visuals(expedition_seed: int, room_id: int, capture_inputs: bool = false) -> void:
	# Separate from topology/encounter/loot seeds and stable across room culling.
	cosmetic_seed = expedition_seed
	cosmetic_room_id = room_id
	_capture_geometry_for_validation = capture_inputs

func _ready() -> void:
	_apply_openings()
	dressing = preload("res://scripts/visual/abyss_decoration.gd").new()
	dressing.configure(module_id, visual_motif, cosmetic_seed, cosmetic_room_id, _capture_geometry_for_validation)
	if not _presentation.is_empty():
		dressing.configure_materials(_presentation.dressing, _presentation_materials)
	add_child(dressing)
	var ambience := preload("res://scripts/visual/visual_style.gd").add_ambience(self, &"abyss", Vector3(18, 2.6, 18), dressing.cosmetic_seed)
	ambience.configure_budget(12)
	ambient_fauna = preload("res://scripts/visual/ambient_fauna.gd").new()
	# Hovering corner pockets stay outside combat, doorway and spawn envelopes.
	# Pass the actual world explicitly: rooms sit under an intermediate holder.
	ambient_fauna.configure(PackedVector3Array([
		Vector3(-9.1, 1.15, -9.1), Vector3(9.1, 1.15, -9.1),
		Vector3(-9.1, 1.15, 9.1), Vector3(9.1, 1.15, 9.1),
	]), dressing.cosmetic_seed ^ 0xB771, 4, _ambient_world_root())
	add_child(ambient_fauna)

func _ambient_world_root() -> Node3D:
	var candidate := get_parent()
	var fallback: Node3D = self
	# A nested preview viewport is a separate presentation world even when its
	# container lives below the main Game/level hierarchy.
	while candidate != null and candidate.get_viewport() == get_viewport():
		if candidate is Node3D:
			fallback = candidate
			if candidate.has_method("get_spawn_transform"):
				return candidate as Node3D
		candidate = candidate.get_parent()
	# A room instantiated alone for a preview/test belongs to that stage.
	return fallback

func configure_openings(directions: Array[StringName]) -> void:
	openings.assign(directions)
	if is_node_ready():
		_apply_openings()

func _apply_openings() -> void:
	for direction: StringName in [&"north", &"south", &"east", &"west"]:
		var door := get_node_or_null("DoorFillers/" + String(direction).capitalize()) as Node3D
		if door == null:
			continue
		var closed := not openings.has(direction)
		door.visible = closed
		var body := door.get_node("Body") as StaticBody3D
		body.collision_layer = 1 if closed else 0

func get_spawn_points() -> Array[Vector3]:
	return spawn_points.duplicate()

func get_chest_anchor() -> Vector3:
	return chest_anchor

func get_player_spawn() -> Transform3D:
	return $PlayerSpawn.transform
