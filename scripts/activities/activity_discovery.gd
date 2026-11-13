extends Node3D
## A nonblocking interaction presenter for a planned source. It never chooses
## loot, writes the profile, owns a pet, or changes an objective on its own.
const Architecture = preload("res://scripts/world/architecture.gd")
const PetVisual = preload("res://scripts/pets/pet_visual.gd")
const PetCatalog = preload("res://scripts/pets/pet_catalog.gd")
var interaction_radius := 2.8
var claimed := false
var _world: WeakRef
var _slot_id := ""
var _kind := ""
var _generation := -1
var _claiming := false
var _model: Node3D
var _label: Label3D

func configure(world: Node3D, slot_id: String, kind: String, generation: int) -> bool:
	if is_inside_tree() or _world != null or not is_instance_valid(world) or generation < 0: return false
	var kinds := {"trail_marker": "track", "glade_egg": "egg", "pool_rescue": "rescue", "forage_cache": "treasure"}
	if not kinds.has(slot_id) or kinds[slot_id] != kind: return false
	_world = weakref(world)
	_slot_id = slot_id
	_kind = kind
	_generation = generation
	return true

func identity_snapshot() -> Dictionary:
	return {"slot_id": _slot_id, "kind": _kind, "generation": _generation}

func _ready() -> void:
	if _world == null: return
	add_to_group("interactables")
	add_to_group("activity_discoveries")
	set_meta("native_placeholder_art", true)
	var kit := Architecture.new(self)
	kit.cylinder(Vector3(0, 0.06, 0), 0.56, 0.12, "dark_stone", false, 12)
	kit.ring(Vector3(0, 0.14, 0), 0.52, 0.56, "gold")
	_model = Node3D.new()
	_model.name = "DiscoveryPresentation"
	_model.set_meta("dynamic_visual", true)
	add_child(_model)
	var model_kit := Architecture.new(_model)
	match _kind:
		"track":
			for index in range(4):
				var print_mesh := model_kit.box(Vector3(-0.21 if index % 2 == 0 else 0.21, 0.16, -0.36 + float(index) * 0.24), Vector3(0.15, 0.025, 0.22), "glow")
				print_mesh.rotation.y = 0.18 if index % 2 == 0 else -0.18
		"egg":
			var egg := SphereMesh.new()
			egg.radius = 0.27
			egg.height = 0.72
			egg.radial_segments = 12
			egg.rings = 5
			model_kit.mesh_instance(egg, Vector3(0, 0.54, 0), model_kit.palette.crystal)
			for side: float in [-1.0, 1.0]: model_kit.box(Vector3(side * 0.22, 0.30, 0), Vector3(0.25, 0.12, 0.55), "wood")
		"rescue":
			var spirit := PetVisual.new()
			spirit.position.y = 0.16
			_model.add_child(spirit)
			if spirit.configure(PetCatalog.definition_for(&"starbound_wisp"), {"variant": "luminous"}):
				spirit.add_to_group("visual_quality")
			else:
				spirit.queue_free()
			for side: float in [-1.0, 1.0]:
				var root := model_kit.box(Vector3(side * 0.43, 0.48, 0), Vector3(0.12, 0.7, 0.24), "wood")
				root.rotation.z = side * -0.22
		"treasure":
			model_kit.box(Vector3(0, 0.38, 0), Vector3(0.78, 0.48, 0.58), "wood")
			model_kit.box(Vector3(0, 0.67, 0), Vector3(0.86, 0.10, 0.66), "bronze")
			model_kit.box(Vector3(0, 0.45, 0.31), Vector3(0.14, 0.22, 0.035), "gold")
	_label = kit.label(_title(), Vector3(0, 1.5, 0), 24, Color("cbebd5"))
	_label.pixel_size = 0.0036

func _title() -> String:
	return {"track": "CREATURE TRAIL", "egg": "MYSTERIOUS EGG", "rescue": "STRANDED SPIRIT", "treasure": "OLD FORAGE CACHE"}.get(_kind, "DISCOVERY")

func get_prompt() -> String:
	if claimed: return "Discovery recorded"
	return {"track": "Read creature trail", "egg": "Recover egg · return to keep ingredients", "rescue": "Free spirit · return to keep memory", "treasure": "Search forage cache · unsecured"}.get(_kind, "Inspect discovery")

func can_interact(actor: Node3D) -> bool:
	var world := _world.get_ref() as Node3D if _world != null else null
	return not claimed and not _claiming and is_instance_valid(world) and int(world.run_generation) == _generation \
		and world.owns_source(self, _slot_id) and not world.activity_claim_record(self, actor).is_empty()

func interact(actor: Node3D) -> void:
	if not can_interact(actor): return
	var authority := get_node_or_null("/root/ExpeditionSession")
	var world := _world.get_ref() as Node3D
	if authority == null or not authority.has_method("claim_activity_source"): return
	_claiming = true
	var result: Dictionary = authority.claim_activity_source(world, self, actor, _generation)
	if not is_instance_valid(self) or is_queued_for_deletion(): return
	_claiming = false
	if not bool(result.get("ok", false)):
		if authority.has_signal("notice") and not String(result.get("error", "")).is_empty(): authority.notice.emit(String(result.error))
		return
	if not bool(result.get("still_current", false)) or not is_instance_valid(world) or not world.run_source_context_valid(): return
	claimed = true
	_model.visible = false
	_label.text = "TRAIL RECORDED" if _kind == "track" else "SPIRIT FREED · MEMORY RECOVERED" if _kind == "rescue" else "DISCOVERY RECOVERED"
	remove_from_group("interactables")
