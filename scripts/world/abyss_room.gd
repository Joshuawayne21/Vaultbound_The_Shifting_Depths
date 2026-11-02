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
	if is_inside_tree() or not _presentation.is_empty(): return false
	return _apply_presentation(issued, shared_materials)

func _apply_presentation(issued: Dictionary, shared_materials: Dictionary) -> bool:
	var schema := preload("res://scripts/visual/dungeon_presentation.gd")
	if not schema.valid_snapshot(issued): return false
	if not issued.modules.has(String(module_id)) or not schema._keys(shared_materials, schema.ROLE_PATHS.keys()):
		return false
	for role: String in schema.ROLE_PATHS:
		if not shared_materials[role] is Material: return false
	if not schema.module_instance_valid(issued, self):
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
	# A directly opened native Crystal/Ember scene gets its closed cosmetic profile.
	# This does not enable a theme or issue a run; unknown/mixed scenes cannot
	# select the default. Existing standalone Rootbound behavior stays exact.
	if _presentation.is_empty():
		var catalog := preload("res://scripts/visual/dungeon_presentation_catalog.gd")
		var crystal: Dictionary = catalog.CRYSTAL_MODULES.get(String(module_id), {})
		var ember: Dictionary = catalog.EMBER_MODULES.get(String(module_id), {})
		var default_path := ""
		if not crystal.is_empty() and scene_file_path == crystal.scene:
			default_path = "res://resources/visual/crystal_presentation.tres"
		elif not ember.is_empty() and scene_file_path == ember.scene:
			default_path = "res://resources/visual/ember_presentation.tres"
		if not default_path.is_empty():
			var profile := load(default_path) as VaultDungeonPresentation
			var issued: Dictionary = profile.snapshot()
			var schema := preload("res://scripts/visual/dungeon_presentation.gd")
			if not schema.module_instance_valid(issued, self) or not _apply_presentation(issued, schema.build_materials(issued)): return
	_apply_openings()
	if _presentation.get("id", "") == "ember_native_v1":
		dressing = preload("res://scripts/visual/ember_decoration.gd").new()
	elif _presentation.get("id", "") == "crystal_native_v1":
		dressing = preload("res://scripts/visual/crystal_decoration.gd").new()
	else:
		dressing = preload("res://scripts/visual/abyss_decoration.gd").new()
	dressing.configure(module_id, visual_motif, cosmetic_seed, cosmetic_room_id, _capture_geometry_for_validation)
	if not _presentation.is_empty():
		dressing.configure_materials(_presentation.dressing, _presentation_materials)
	add_child(dressing)
	var ambience := preload("res://scripts/visual/visual_style.gd").add_ambience(self, &"ember" if _presentation.get("id", "") == "ember_native_v1" else &"crystal" if _presentation.get("id", "") == "crystal_native_v1" else &"abyss", Vector3(18, 2.6, 18), dressing.cosmetic_seed)
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
