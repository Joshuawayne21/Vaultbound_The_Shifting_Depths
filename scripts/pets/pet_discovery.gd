class_name VaultPetDiscovery
extends Node3D
## A real, nonblocking dungeon find. Session owns every earned ingredient and
## receipt; this native placeholder only presents an admitted world source.
const Architecture = preload("res://scripts/world/architecture.gd")
var interaction_radius := 2.8
var kind := "egg"
var claimed := false
var _level: WeakRef
var _generation := -1
var _claiming := false
var _model: Node3D
var _ring: MeshInstance3D
var _elapsed := 0.0
var _redraw_elapsed := 0.0
var _settings: Node

func configure(level: Node3D, discovery_kind: String, generation: int) -> void:
	if is_inside_tree() or _level != null: return
	_level = weakref(level)
	kind = discovery_kind
	_generation = generation

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("pet_discoveries")
	_settings = get_node_or_null("/root/VisualSettings")
	_model = Node3D.new()
	_model.name = "OriginalNativePlaceholder"
	add_child(_model)
	var kit := Architecture.new(self)
	kit.cylinder(Vector3(0, 0.06, 0), 0.5, 0.12, "dark_stone", false, 12)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.46
	ring_mesh.outer_radius = 0.50
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 4
	_ring = kit.mesh_instance(ring_mesh, Vector3(0, 0.14, 0), kit.palette.gold)
	var body := SphereMesh.new()
	body.radius = 0.25 if kind == "egg" else 0.2
	body.height = 0.68 if kind == "egg" else 0.44
	body.radial_segments = 12
	body.rings = 6
	var tint := Color("91ceb6") if kind == "egg" else Color("9bd6ed")
	kit.mesh_instance(body, Vector3(0, 0.48 if kind == "egg" else 0.68, 0), kit.material(tint, 0.1, true), _model)
	for index in range(3):
		var rune := kit.box(Vector3(-0.24 + index * 0.24, 0.37, 0.22), Vector3(0.065, 0.12, 0.045), "gold", false, _model)
		rune.rotation.z = PI / 4.0
	var label := kit.label("MYSTERIOUS EGG" if kind == "egg" else "STRANDED ROOT SPIRIT", Vector3(0, 1.42, 0), 22, tint)
	label.pixel_size = 0.0035

func _process(delta: float) -> void:
	if claimed or not is_visible_in_tree(): return
	_elapsed += delta
	_redraw_elapsed += delta
	if _redraw_elapsed < 0.05: return
	_redraw_elapsed = 0.0
	var reduced_motion := is_instance_valid(_settings) and bool(_settings.get("reduced_motion"))
	_model.position.y = 0.0 if reduced_motion else sin(_elapsed * 1.8) * 0.045
	_ring.visible = not (is_instance_valid(_settings) and bool(_settings.get("reduced_effects")))

func get_prompt() -> String:
	return "Gather mysterious egg · extract to keep" if kind == "egg" else "Rescue root spirit · extract to keep"

func can_interact(actor: Node3D) -> bool:
	var level := _level.get_ref() as Node3D if _level != null else null
	return not claimed and not _claiming and is_instance_valid(level) and int(level.run_generation) == _generation \
		and not level.pet_discovery_record(self, actor).is_empty()

func interact(actor: Node3D) -> void:
	if not can_interact(actor): return
	var level := _level.get_ref() as Node3D
	var authority := get_node_or_null("/root/ExpeditionSession")
	if authority == null: return
	_claiming = true
	var result: Dictionary = authority.claim_pet_discovery(level, self, actor, _generation)
	_claiming = false
	if not bool(result.get("ok", false)) or not bool(result.get("still_current", false)) \
			or not is_instance_valid(level) or not level.run_source_context_valid():
		return
	claimed = true
	hide()
	remove_from_group("interactables")
	set_process(false)
