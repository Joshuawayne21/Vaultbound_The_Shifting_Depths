extends Node3D
## A separate, bounded safe hub. Existing Game/Session authorities own travel,
## eligibility, activity completion and saving; this scene supplies no rewards.
const Architecture = preload("res://scripts/world/architecture.gd")
const Hall = preload("res://scripts/nexus/realm_nexus_architecture.gd")
const GatewayArt = preload("res://scripts/nexus/realm_gateway_art.gd")
const Catalog = preload("res://scripts/realms/realm_catalog.gd")
const Portal = preload("res://scenes/world/portal.tscn")
const Terminal = preload("res://scripts/sanctuary/city_terminal.gd")
const Batcher = preload("res://scripts/visual/static_visual_batcher.gd")
const Style = preload("res://scripts/visual/visual_style.gd")
const LAYOUT = preload("res://resources/nexus/layout.tres")
const ENTRY_IDS: Array[StringName] = [&"default", &"from_sanctuary", &"from_bloodspire"]
const ACTOR_RADIUS := 0.34
const ACTOR_HEIGHT := 1.7
const FORMATION_TRAIL := 2.2
const FORMATION_SIDE := 1.6

var display_name := "NEXUS OF REALMS"
var objective := "Adventure · Conflict · Ascension — inspect gateways for current availability"
var _floor_body: StaticBody3D
var _activity_sources: Dictionary = {}
var _activity_transforms: Dictionary = {}
var _portal_sources: Dictionary = {}
var _portal_contracts: Dictionary = {}
var _built := false

func _ready() -> void:
	if _built: return
	assert(LAYOUT.valid(), "The authored Nexus layout or activity catalog is invalid.")
	_built = true
	set_meta("native_placeholder_art", true)
	_floor_body = Hall.build(self, LAYOUT)
	_build_activity_gates()
	_build_existing_passages()
	_build_orientation()
	Batcher.bake(self, 8.0)

func _build_activity_gates() -> void:
	var palette := Style.palette()
	for row: Dictionary in LAYOUT.portals():
		var id: StringName = row.activity_id
		var data: Resource = Catalog.definition(id)
		var gate := Portal.instantiate() as Node3D
		gate.name = String(id).to_pascal_case() + "Gateway"
		gate.position = row.position
		gate.rotation.y = float(row.rotation)
		gate.activity_id = id
		gate.destination = data.destination
		gate.entry_id = data.entry_id
		gate.title = String(data.label).to_upper()
		gate.visual_profile_override = data.visual_profile
		gate.require_entry_card = true
		gate.set_meta("sanctuary_poi", row.id)
		gate.set_meta("approach_position", row.approach)
		gate.add_to_group("nexus_activity_portals")
		add_child(gate)
		var ornaments := GatewayArt.build(gate, String(data.architecture_family), palette, data.visual_profile.accent_color)
		# Portal nodes are intentionally excluded by the world batcher because
		# their surfaces animate. Their separate immutable ornaments can be baked.
		Batcher.bake(ornaments, 8.0)
		_activity_sources[id] = weakref(gate)
		_activity_transforms[id] = gate.transform
		_register_portal_source(id, gate)

func _build_existing_passages() -> void:
	for id: StringName in [&"nexus_return", &"nexus_practice"]:
		var row: Dictionary = LAYOUT.get_poi(id)
		var gate := Portal.instantiate() as Node3D
		gate.name = "SanctuaryReturn" if id == &"nexus_return" else "SunkenVaultPracticeGate"
		gate.position = row.position
		gate.rotation.y = float(row.rotation)
		gate.destination = &"sanctuary" if id == &"nexus_return" else &"dungeon"
		gate.entry_id = &"from_nexus" if id == &"nexus_return" else &"from_sanctuary"
		gate.title = String(row.label).to_upper()
		gate.require_entry_card = true
		gate.set_meta("sanctuary_poi", id)
		gate.set_meta("approach_position", row.approach)
		add_child(gate)
		_register_portal_source(id, gate)

func _register_portal_source(id: StringName, gate: Node3D) -> void:
	assert(not _portal_sources.has(id), "A Nexus portal source cannot be enrolled twice.")
	_portal_sources[id] = weakref(gate)
	_portal_contracts[id] = {"activity_id": gate.activity_id, "destination": gate.destination,
		"entry_id": gate.entry_id, "profile": gate.visual_profile_override, "transform": gate.transform}

func _build_orientation() -> void:
	var row: Dictionary = LAYOUT.get_poi(&"map")
	var guide := Terminal.new()
	guide.name = "NexusOrientationGuide"
	guide.terminal_id = &"map"
	guide.kind = &"guide"
	guide.title = "Nexus orientation"
	guide.description = "A: Adventure · C: Conflict · S: Ascension. Inspect gateways; south returns to Sanctuary."
	guide.position = row.position
	guide.set_meta("sanctuary_poi", &"map")
	guide.set_meta("approach_position", row.approach)
	add_child(guide)
	var kit := Architecture.new(guide)
	kit.cylinder(Vector3(0, 0.10, 0), 0.55, 0.2, "dark_stone", true, 8)
	kit.cylinder(Vector3(0, 0.45, 0), 0.25, 0.5, "light_stone", true, 8)
	kit.cylinder(Vector3(0, 0.76, 0), 0.55, 0.12, "gold", true, 8)
	var tablet := kit.box(Vector3(0, 0.9, 0), Vector3(0.85, 0.12, 0.60), "crystal", true)
	tablet.rotation.x = -0.20
	var label := kit.label("GALLERY GUIDE", Vector3(0, 1.8, 0), 25, Color("c2e3e9"))
	label.pixel_size = 0.004

func registered_activity_sources() -> Dictionary:
	# Detached map of originally authored identities; a caller cannot register a
	# new source by adding a similarly named node or mutating this snapshot.
	var result: Dictionary = {}
	for id: StringName in _activity_sources:
		var source := _activity_sources[id].get_ref() as Node3D
		result[id] = source if owns_activity_portal(source, id) else null
	return result

func registered_portal_sources() -> Dictionary:
	var result: Dictionary = {}
	for id: StringName in _portal_sources:
		var source := _portal_sources[id].get_ref() as Node3D
		result[id] = source if owns_portal_source(source) else null
	return result

func owns_portal_source(source: Node3D) -> bool:
	# Required before both major-activity and auxiliary legacy-route dispatch.
	# Removing an activity ID does not turn that authored gate into a legacy gate.
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(source): return false
	if not source.is_inside_tree() or source.is_queued_for_deletion() or source.get_parent() != self: return false
	if source.get_script() == null or source.get_script().resource_path != "res://scripts/world/portal.gd": return false
	for id: StringName in _portal_sources:
		if _portal_sources[id].get_ref() != source: continue
		var contract: Dictionary = _portal_contracts[id]
		return source.activity_id == contract.activity_id and source.destination == contract.destination \
			and source.entry_id == contract.entry_id and source.visual_profile_override == contract.profile \
			and source.require_entry_card and source.transform.is_equal_approx(contract.transform)
	return false

func owns_activity_portal(source: Node3D, id: StringName) -> bool:
	if not _activity_sources.has(id) or not owns_portal_source(source): return false
	if _activity_sources[id].get_ref() != source: return false
	var data: Resource = Catalog.definition(id)
	return data != null and source.activity_id == id and source.destination == data.destination \
		and source.entry_id == data.entry_id and source.visual_profile_override == data.visual_profile \
		and source.transform.is_equal_approx(_activity_transforms[id])

func get_city_layout() -> Dictionary:
	return LAYOUT.describe()

func get_poi_approach_position(id: StringName) -> Vector3:
	var row: Dictionary = LAYOUT.get_poi(id)
	return to_global(row.get("approach", Vector3.ZERO))

func get_companion_navigation_profile() -> Dictionary:
	return {"mode": &"terraced_city", "floor_min": 0.0, "floor_max": 0.0}

func get_companion_navigation_graph() -> Dictionary:
	var graph: Dictionary = LAYOUT.navigation_graph()
	var points: PackedVector3Array = graph.points
	for index in range(points.size()): points[index] = to_global(points[index])
	graph.points = points
	return graph

func get_spawn_transform(_entry_id: StringName) -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 23))

func validate_nexus_arrival(entry_id: StringName) -> bool:
	# Called after physics registration, before publishing a transition. Verify
	# exact authored floor and clearance for player plus both existing AI slots.
	if entry_id not in ENTRY_IDS or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(_floor_body): return false
	if not _floor_body.is_inside_tree() or not is_ancestor_of(_floor_body): return false
	var spawn := get_spawn_transform(entry_id)
	if not spawn.is_finite() or not spawn.basis.is_conformal() or not is_equal_approx(spawn.basis.determinant(), 1.0): return false
	var excluded: Array[RID] = []
	for sibling: Node in get_parent().get_children():
		if sibling == self or not sibling is Node3D or not sibling.has_method("get_spawn_transform"): continue
		for body: Node in sibling.find_children("*", "CollisionObject3D", true, false):
			excluded.append((body as CollisionObject3D).get_rid())
	var facing := -spawn.basis.z.normalized()
	var side := Vector3(-facing.z, 0, facing.x)
	var positions: Array[Vector3] = [spawn.origin,
		spawn.origin - facing * FORMATION_TRAIL - side * FORMATION_SIDE,
		spawn.origin - facing * FORMATION_TRAIL + side * FORMATION_SIDE]
	var capsule := CapsuleShape3D.new()
	capsule.radius = ACTOR_RADIUS
	capsule.height = ACTOR_HEIGHT
	var space := get_world_3d().direct_space_state
	for point: Vector3 in positions:
		for offset: Vector3 in [Vector3.ZERO, Vector3(ACTOR_RADIUS, 0, 0), Vector3(-ACTOR_RADIUS, 0, 0), Vector3(0, 0, ACTOR_RADIUS), Vector3(0, 0, -ACTOR_RADIUS)]:
			var ray := PhysicsRayQueryParameters3D.create(point + offset + Vector3.UP * 0.5, point + offset - Vector3.UP * 0.5, 1)
			ray.exclude = excluded
			ray.collide_with_areas = false
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.collider != _floor_body or Vector3(hit.normal).dot(Vector3.UP) < 0.98: return false
			if absf(Vector3(hit.position).y - (spawn.origin.y - 0.15)) > 0.025: return false
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(spawn.basis, point + Vector3.UP * ACTOR_HEIGHT * 0.5)
		query.collision_mask = 1 | 16
		query.exclude = excluded
		query.margin = 0.005
		query.collide_with_areas = false
		if not space.intersect_shape(query, 1).is_empty(): return false
	return true

func presentation_snapshot() -> Dictionary:
	return {"radius": float(LAYOUT.radius), "activity_gate_count": _activity_sources.size(),
		"gallery_count": 3, "navigation_points": LAYOUT.navigation_graph().points.size(),
		"extra_local_lights": 0, "native_placeholder_art": true,
		"activity_gameplay_added": false, "batch_report": get_meta("static_architecture_batch_report", {}).duplicate(true)}
