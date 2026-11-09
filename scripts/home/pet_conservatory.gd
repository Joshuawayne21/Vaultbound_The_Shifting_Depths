extends Node3D
## Saved owned-pet references presented in six bounded, noncombat garden habitats.
## Session alone changes ownership, milestones and display assignments.
const Architecture = preload("res://scripts/world/architecture.gd")
const Builder = preload("res://scripts/home/pet_conservatory_builder.gd")
const Style = preload("res://scripts/visual/visual_style.gd")
const Batcher = preload("res://scripts/visual/static_visual_batcher.gd")
const Station = preload("res://scripts/home/home_management_station.gd")
const Home = preload("res://scripts/progression/home_progression.gd")
const PetCatalog = preload("res://scripts/pets/pet_catalog.gd")
const PetVisual = preload("res://scripts/pets/pet_visual.gd")
const Portal = preload("res://scenes/world/portal.tscn")
const IVORY = preload("res://resources/materials/home_ivory.tres")
const FLOOR = preload("res://resources/materials/home_floor.tres")
const ROYAL_BLUE = preload("res://resources/materials/home_royal_blue.tres")
const WINDOW = preload("res://resources/materials/home_window.tres")
const ENTRY_IDS := [&"default", &"from_home"]
const ACTOR_RADIUS := 0.34
const ACTOR_HEIGHT := 1.7
const MAX_DISPLAY_PETS := 6

var display_name := "PET CONSERVATORY"
var objective := "Your collected companions · Manage six cosmetic garden displays"
var habitats: Dictionary = {}
var _home_id := ""
var _configured := false
var _floor_body: StaticBody3D
var _management_station: Node3D
var _session: Node
var _settings: Dictionary = {}
var _last_revision := -1
var _pose_time := 0.0
var _pose_clock := 0.0
var _pose_interval := 0.05
var _motion_scale := 1.0
var _summary: Label3D

func configure_home_visit(home_id: String) -> bool:
	if _configured or is_inside_tree() or is_queued_for_deletion() or not Home.valid_id(home_id, false): return false
	_configured = true
	_home_id = home_id
	return true

func is_home_origin_visit() -> bool:
	return _configured and Home.valid_id(_home_id, false)

func home_identity() -> String:
	return _home_id

func _ready() -> void:
	add_to_group("visual_quality")
	var kit := Architecture.new(self)
	kit.palette["light_stone"] = IVORY
	kit.palette["stone"] = FLOOR
	kit.palette["cloth"] = ROYAL_BLUE
	kit.palette["window"] = WINDOW
	_floor_body = Builder.build(self, kit)
	_build_environment()
	_build_habitats(kit)
	_build_management(kit)
	_build_return()
	_summary = kit.label("YOUR PET COLLECTION\nManage owned pet displays at the garden lectern", Vector3(0, 5.5, -14.7), 25, Color("deecd1"))
	_summary.name = "CollectionSummary"
	_summary.pixel_size = 0.0055
	var motes := Style.add_ambience(self, &"hall", Vector3(24, 7, 28), 734) as VaultAmbientMotes
	motes.configure_budget(12)
	Batcher.bake(self, 12.0)
	_session = get_node_or_null("/root/ExpeditionSession")
	if is_instance_valid(_session): _session.changed.connect(_on_profile_changed)
	var settings := get_node_or_null("/root/VisualSettings")
	if settings != null: apply_visual_settings(settings.snapshot())
	refresh_displays(true)

func _build_environment() -> void:
	var environment := Style.apply_environment(self, &"hall")
	environment.environment.ambient_light_color = Color("b8d3c7")
	environment.environment.ambient_light_energy = 0.84
	environment.environment.fog_light_color = Color("7b9baf")
	environment.environment.fog_depth_begin = 28.0
	environment.environment.fog_depth_end = 65.0
	var key := get_node("WarmKey") as DirectionalLight3D
	key.light_color = Color("ffe3ae")
	key.light_energy = 1.0
	key.rotation_degrees = Vector3(-54, -32, 0)

func _build_habitats(kit: Architecture) -> void:
	for row: Dictionary in Builder.slot_layout():
		var holder := Node3D.new()
		holder.name = "DisplayedPet_" + String(row.id)
		holder.position = row.at + Vector3.UP * Builder.PET_HEIGHT
		holder.rotation.y = PI / 6.0 if Vector3(row.at).x > 0 else -PI / 6.0
		holder.set_meta("dynamic_visual", true)
		add_child(holder)
		var label := kit.label(String(row.label).to_upper() + "\nEmpty habitat", row.at + Vector3(0, 1.30, 1.75), 24, Color("e8d7aa"))
		label.name = "HabitatPlaque_" + String(row.id)
		label.pixel_size = 0.006
		habitats[row.id] = {"holder": holder, "label": label, "pet_id": "", "visual": null, "title": row.label}

func _build_management(kit: Architecture) -> void:
	var station := Station.new()
	station.name = "HomeManagementStation"
	station.position = Vector3(-3.5, 0, 11.2)
	station.rotation.y = PI / 3.0
	if not station.configure(self):
		station.free()
		return
	_management_station = station
	add_child(station)
	kit.cylinder(Vector3(0, 0.1, 0), 0.58, 0.2, "dark_stone", true, 10, station)
	kit.cylinder(Vector3(0, 0.6, 0), 0.28, 1.0, "light_stone", true, 10, station)
	kit.box(Vector3(0, 1.13, 0), Vector3(1.0, 0.12, 0.7), "gold", true, station)
	kit.box(Vector3(0, 1.21, 0), Vector3(0.86, 0.05, 0.57), "window", false, station)
	var sign := kit.label("GARDEN MANAGEMENT\nChoose your owned pet displays", station.position + Vector3(0, 2.1, 0), 24, Color("d5e4b5"))
	sign.name = "GardenManagementPlaque"
	sign.pixel_size = 0.005

func home_management_station() -> Node3D:
	return _management_station if is_instance_valid(_management_station) else null

func _build_return() -> void:
	var portal := Portal.instantiate()
	portal.name = "PersonalSanctuaryReturn"
	portal.position = Vector3(0, 0, 13)
	portal.rotation.y = PI
	portal.destination = &"personal_sanctuary"
	portal.entry_id = &"from_conservatory"
	portal.title = "RETURN TO YOUR GRAND FOYER"
	add_child(portal)

func _on_profile_changed(_snapshot: Dictionary) -> void:
	refresh_displays(false)

func _profile_matches_home() -> bool:
	return is_home_origin_visit() and is_instance_valid(_session) and _session.profile.get("home", {}).get("id", "") == _home_id

func refresh_displays(force: bool = true) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(_session): return
	var revision := int(_session.profile.get("revision", 0))
	if not force and revision == _last_revision: return
	_last_revision = revision
	var snapshot: Dictionary = _session.home_management_snapshot() if _profile_matches_home() else {}
	var rows: Dictionary = {}
	for row: Dictionary in snapshot.get("pet_displays", []):
		if habitats.has(String(row.get("id", ""))): rows[String(row.id)] = row
	var accepted := {}
	var owned: Dictionary = _session.profile.get("pets", {}).get("owned", {}) if _profile_matches_home() else {}
	for id: String in habitats:
		var slot: Dictionary = habitats[id]
		var row: Dictionary = rows.get(id, {})
		var pet_id := String(row.get("pet_id", ""))
		var definition := PetCatalog.definition_for(StringName(pet_id))
		# A stale/corrupt reference never invents an owned model. The original pet
		# collection supplies appearance; the scene has no authority to grant it.
		if definition == null or not owned.has(pet_id) or accepted.has(pet_id) or not snapshot.get("pet_displays_unlocked", false): pet_id = ""
		if String(slot.pet_id) != pet_id:
			if is_instance_valid(slot.visual):
				slot.holder.remove_child(slot.visual)
				slot.visual.queue_free()
			slot.visual = null
			slot.pet_id = pet_id
		if pet_id.is_empty():
			slot.label.text = String(slot.title).to_upper() + "\nEmpty habitat · assign at the lectern"
			continue
		accepted[pet_id] = true
		var entry: Dictionary = owned[pet_id]
		var alias := String(entry.get("alias", ""))
		var appearance := {"id": pet_id, "display_name": alias if not alias.is_empty() else definition.label, "variant": entry.get("variant", "natural")}
		if not is_instance_valid(slot.visual):
			var visual := PetVisual.new()
			visual.name = "OwnedPetVisual"
			if not visual.configure(definition, appearance):
				visual.free()
				slot.pet_id = ""
				continue
			slot.holder.add_child(visual)
			slot.visual = visual
		else:
			slot.visual.set_appearance(appearance)
		slot.visual.apply_visual_settings(_settings)
		slot.label.text = "%s\n%s · %s" % [String(slot.title).to_upper(), appearance.display_name, String(definition.rarity).capitalize()]
	_summary.text = "YOUR PET COLLECTION · %d OWNED\n%d / %d garden displays · Cosmetic only" % [owned.size(), accepted.size(), MAX_DISPLAY_PETS]

func apply_visual_settings(settings: Dictionary) -> void:
	_settings = settings.duplicate(true)
	_motion_scale = clampf(float(settings.get("decorative_motion_scale", 0.0 if settings.get("reduced_motion", false) else 1.0)), 0.0, 1.0)
	_pose_interval = 0.1 if int(settings.get("quality", 1)) == 0 else 0.05
	for slot: Dictionary in habitats.values():
		if is_instance_valid(slot.visual): slot.visual.apply_visual_settings(settings)

func _process(delta: float) -> void:
	if _motion_scale <= 0.0 or not is_visible_in_tree(): return
	_pose_clock += minf(maxf(delta, 0.0), 0.1)
	_pose_time += minf(maxf(delta, 0.0), 0.1)
	if _pose_clock < _pose_interval: return
	_pose_clock = 0.0
	var index := 0
	for slot: Dictionary in habitats.values():
		if is_instance_valid(slot.visual): slot.visual.pose(&"idle", _pose_time + index * 0.37)
		index += 1

func presentation_snapshot() -> Dictionary:
	var result := {"display_count": 0, "max_display_count": MAX_DISPLAY_PETS, "pets": {}, "native_placeholder": true,
		"pose_interval": _pose_interval, "motion_scale": _motion_scale}
	for id: String in habitats:
		var slot: Dictionary = habitats[id]
		if is_instance_valid(slot.visual):
			result.display_count += 1
			result.pets[id] = slot.visual.presentation_snapshot()
			result.pets[id].pet_id = slot.pet_id
	return result

func get_spawn_transform(_entry_id: StringName) -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 9))

func validate_home_arrival(entry_id: StringName) -> bool:
	if entry_id not in ENTRY_IDS or not is_home_origin_visit() or not is_inside_tree() or is_queued_for_deletion() \
		or not is_instance_valid(_floor_body) or not _floor_body.is_inside_tree(): return false
	var spawn := get_spawn_transform(entry_id)
	if not spawn.is_finite() or not spawn.basis.is_conformal() or not is_equal_approx(spawn.basis.determinant(), 1.0): return false
	var excluded: Array[RID] = []
	for sibling: Node in get_parent().get_children():
		if sibling == self or not sibling is Node3D or not sibling.has_method("get_spawn_transform"): continue
		for body: Node in sibling.find_children("*", "CollisionObject3D", true, false): excluded.append((body as CollisionObject3D).get_rid())
	var facing := -spawn.basis.z.normalized()
	var side := Vector3(-facing.z, 0, facing.x)
	var positions: Array[Vector3] = [spawn.origin, spawn.origin - facing * 2.2 - side * 1.6, spawn.origin - facing * 2.2 + side * 1.6]
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
			if hit.is_empty() or hit.collider != _floor_body or Vector3(hit.normal).dot(Vector3.UP) < 0.98 \
				or absf(Vector3(hit.position).y - (spawn.origin.y - 0.15)) > 0.025: return false
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(spawn.basis, point + Vector3.UP * ACTOR_HEIGHT * 0.5)
		query.collision_mask = 1 | 16
		query.exclude = excluded
		query.margin = 0.005
		query.collide_with_areas = false
		if not space.intersect_shape(query, 1).is_empty(): return false
	return true
