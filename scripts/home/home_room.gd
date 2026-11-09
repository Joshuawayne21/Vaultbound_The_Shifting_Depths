extends Node3D
## Bounded presentation for six home rooms. Existing profile/party authorities
## retain ownership, recruitment, equipment, journals and home appearance.
const Architecture = preload("res://scripts/world/architecture.gd")
const Workrooms = preload("res://scripts/home/home_workroom_builder.gd")
const PrivateRooms = preload("res://scripts/home/home_private_builder.gd")
const Home = preload("res://scripts/progression/home_progression.gd")
const HomeStyle = preload("res://scripts/home/home_visual_style.gd")
const Style = preload("res://scripts/visual/visual_style.gd")
const Batcher = preload("res://scripts/visual/static_visual_batcher.gd")
const Station = preload("res://scripts/home/home_management_station.gd")
const Service = preload("res://scripts/home/home_room_service.gd")
const Portal = preload("res://scenes/world/portal.tscn")
const Avatar = preload("res://scripts/player/player_avatar.gd")
const ItemPresentation = preload("res://scripts/visual/item_presentation.gd")
const PetCatalog = preload("res://scripts/pets/pet_catalog.gd")
const PetVisual = preload("res://scripts/pets/pet_visual.gd")
const GUARDIAN = preload("res://resources/companions/guardian.tres")
const MYSTIC = preload("res://resources/companions/mystic.tres")
const MATERIALS := {"light_stone": preload("res://resources/materials/home_ivory.tres"),
	"stone": preload("res://resources/materials/home_floor.tres"),
	"cloth": preload("res://resources/materials/home_royal_blue.tres"),
	"window": preload("res://resources/materials/home_window.tres")}
const ROOM_IDS := ["armory", "companion_hall", "relic_library", "personal_chamber", "wardrobe", "rooftop_garden"]
const WORKROOM_IDS := ["armory", "companion_hall", "relic_library"]
const ENTRY_IDS := [&"default", &"from_home"]
const ACTOR_RADIUS := 0.34
const ACTOR_HEIGHT := 1.7
const MAX_GEAR := 6
const MAX_AVATARS := 2
const MAX_PETS := 1

@export_enum("armory", "companion_hall", "relic_library", "personal_chamber", "wardrobe", "rooftop_garden") var room_id := "armory"
var display_name := "PERSONAL SANCTUARY"
var objective := "Your home · Existing collections and services"
var _configured := false
var _home_id := ""
var _floor_body: StaticBody3D
var _management_station: Node3D
var _services: Dictionary = {}
var _anchors: Dictionary = {}
var _layout: Dictionary = {}
var _palette: Dictionary = {}
var _dynamic: Node3D
var _session: Node
var _last_revision := -1
var _last_profile_id := ""
var _last_theme := ""
var _settings: Dictionary = {}
var _avatars: Array[Node3D] = []
var _pet_visual: Node3D
var _pose_clock := 0.0
var _pose_time := 0.0
var _pose_interval := 0.05
var _motion_scale := 1.0
var _presentation := {"equipment": [], "companions": [], "active_pet": {}}

func configure_home_visit(home_id: String) -> bool:
	if _configured or is_inside_tree() or is_queued_for_deletion() or room_id not in ROOM_IDS \
		or not Home.valid_id(home_id, false): return false
	_configured = true
	_home_id = home_id
	return true

func is_home_origin_visit() -> bool:
	return _configured and room_id in ROOM_IDS and Home.valid_id(_home_id, false)

func home_identity() -> String:
	return _home_id

func _ready() -> void:
	if room_id not in ROOM_IDS: return
	display_name = room_id.replace("_", " ").to_upper()
	objective = {"armory": "Owned equipment and favorite showcases · Inspect your adventurer",
		"companion_hall": "Your adventurer roster · Guardian and Mystic",
		"relic_library": "Your secured discoveries · Items, monsters and expedition records",
		"personal_chamber": "Your private chamber · Home themes and equipment inspection",
		"wardrobe": "Your equipped appearance · Rotate and inspect in the mirror",
		"rooftop_garden": "Your scenic garden · An active pet's peaceful display"}[room_id]
	add_to_group("visual_quality")
	var kit := Architecture.new(self)
	for key: String in kit.palette:
		if kit.palette[key] is Material: kit.palette[key] = kit.palette[key].duplicate()
	for key: String in MATERIALS: kit.palette[key] = MATERIALS[key].duplicate()
	kit.palette["path"] = kit.palette.cloth
	_palette = kit.palette
	_layout = Workrooms.layout(room_id) if room_id in WORKROOM_IDS else PrivateRooms.layout(room_id)
	var built: Dictionary = Workrooms.build(self, kit, room_id) if room_id in WORKROOM_IDS else PrivateRooms.build(self, kit, room_id)
	_floor_body = built.get("floor") as StaticBody3D
	_anchors = built.get("anchors", {}).duplicate(true)
	_build_environment()
	_build_management(kit)
	_build_services(kit)
	_build_return()
	_keep_static_collision(self)
	_dynamic = Node3D.new()
	_dynamic.name = "OwnedRoomPresentation"
	_dynamic.set_meta("dynamic_visual", true)
	add_child(_dynamic)
	var motes := Style.add_ambience(self, &"sanctuary" if room_id == "rooftop_garden" else &"hall", Vector3(20, 6, 22), 821 + ROOM_IDS.find(room_id)) as VaultAmbientMotes
	motes.configure_budget(12)
	Batcher.bake(self, 12.0)
	_session = get_node_or_null("/root/ExpeditionSession")
	if is_instance_valid(_session): _session.changed.connect(_on_profile_changed)
	var settings := get_node_or_null("/root/VisualSettings")
	if is_instance_valid(settings): apply_visual_settings(settings.snapshot())
	refresh_presentation(true)

func _build_environment() -> void:
	var environment := Style.apply_environment(self, &"sanctuary" if room_id == "rooftop_garden" else &"hall")
	environment.environment.ambient_light_color = Color("b8c9d5")
	environment.environment.ambient_light_energy = 0.84
	environment.environment.fog_depth_begin = 30.0
	environment.environment.fog_depth_end = 180.0 if room_id == "rooftop_garden" else 62.0
	var key := get_node("WarmKey") as DirectionalLight3D
	key.light_color = Color("ffe1ae")
	key.light_energy = 1.0
	key.rotation_degrees = Vector3(-55, -28, 0)

func _build_management(kit: Architecture) -> void:
	var station := Station.new()
	station.name = "HomeManagementStation"
	station.position = _layout.management
	if not station.configure(self):
		station.free()
		return
	_management_station = station
	add_child(station)
	_lectern(kit, station)
	_label(kit, "HOME MANAGEMENT\nThemes, room milestones and pet displays", station.position + Vector3(0, 2.1, 0))

func home_management_station() -> Node3D:
	return _management_station if is_instance_valid(_management_station) else null

func registered_room_services() -> Dictionary:
	return _services.duplicate()

func _build_services(kit: Architecture) -> void:
	match room_id:
		"armory", "personal_chamber", "wardrobe":
			_service(kit, &"equipment", "Inspect your equipped appearance", _layout.inspection)
		"companion_hall":
			_service(kit, &"companions", "Inspect and manage your adventurers", _layout.inspection)
		"relic_library":
			_service(kit, &"library_items", "Read your item collection", _anchors.get("journal_items", Vector3(-4.6, 0, 4.8)))
			_service(kit, &"library_monsters", "Read your monster discoveries", _anchors.get("journal_monsters", Vector3(4.6, 0, 4.8)))

func _service(kit: Architecture, kind: StringName, label: String, point: Vector3) -> void:
	var station := Service.new()
	station.name = "RoomService_" + String(kind)
	station.position = point
	if not station.configure(self, kind, label):
		station.free()
		return
	_services[kind] = station
	add_child(station)
	_lectern(kit, station)
	_label(kit, label.to_upper(), point + Vector3(0, 2.1, 0))

func _lectern(kit: Architecture, station: Node3D) -> void:
	kit.cylinder(Vector3(0, 0.1, 0), 0.54, 0.2, "dark_stone", true, 10, station)
	kit.cylinder(Vector3(0, 0.6, 0), 0.22, 1.0, "light_stone", true, 10, station)
	kit.box(Vector3(0, 1.15, 0), Vector3(0.95, 0.12, 0.66), "gold", true, station)
	kit.box(Vector3(0, 1.23, 0), Vector3(0.81, 0.04, 0.53), "window", false, station)

func _label(kit: Architecture, text: String, at: Vector3) -> Label3D:
	var label := kit.label(text, at, 24, Color("ebdcba"))
	label.pixel_size = 0.0045
	return label

func _build_return() -> void:
	var portal := Portal.instantiate()
	portal.name = "PersonalSanctuaryReturn"
	portal.position = _layout["return"]
	portal.rotation.y = PI
	portal.destination = &"personal_sanctuary"
	portal.entry_id = StringName("from_" + room_id)
	portal.title = "RETURN TO YOUR GRAND FOYER"
	add_child(portal)

func _keep_static_collision(node: Node) -> void:
	if node is StaticBody3D: node.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	for child: Node in node.get_children(): _keep_static_collision(child)

func _on_profile_changed(_snapshot: Dictionary) -> void:
	refresh_presentation(false)

func _profile_matches_home() -> bool:
	return is_home_origin_visit() and is_instance_valid(_session) \
		and _session.profile.get("home", {}).get("id", "") == _home_id

func refresh_presentation(force: bool = true) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(_dynamic) or not is_instance_valid(_session): return
	var revision := int(_session.profile.get("revision", -1))
	var profile_id := String(_session.profile.get("home", {}).get("id", ""))
	if not force and revision == _last_revision and profile_id == _last_profile_id: return
	_last_revision = revision
	_last_profile_id = profile_id
	var profile: Dictionary = VaultProfileStore.normalize(_session.profile) if _profile_matches_home() else {}
	for child: Node in _dynamic.get_children():
		_dynamic.remove_child(child)
		child.queue_free()
	_avatars.clear()
	_pet_visual = null
	_presentation = {"equipment": [], "companions": [], "active_pet": {}}
	_apply_theme(String(profile.get("home", {}).get("theme_id", "royal_azure")))
	if profile.is_empty(): return
	var kit := Architecture.new(_dynamic)
	kit.palette = _palette
	if room_id in ["armory", "wardrobe"]: _show_equipment(profile, kit)
	if room_id == "companion_hall": _show_companions(profile, kit)
	elif _anchors.get("avatars", []).size() > 0: _show_player_appearance(profile, kit)
	if room_id == "rooftop_garden": _show_pet(profile, kit)
	_show_records(profile, kit)

func _apply_theme(theme: String) -> void:
	if theme == _last_theme: return
	var colors := HomeStyle.theme_colors(theme)
	var links := {"light_stone": "ivory", "stone": "floor", "cloth": "cloth", "window": "window", "gold": "gold"}
	for key: String in links:
		var material := _palette.get(key) as StandardMaterial3D
		if material == null: continue
		material.albedo_color = colors[links[key]]
		if material.emission_enabled: material.emission = colors[links[key]]
	_last_theme = theme

func _show_equipment(profile: Dictionary, kit: Architecture) -> void:
	var points: Array = _anchors.get("gear", [])
	var uids: Array[String] = []
	var slots: Array = VaultInventory.LOADOUT_SLOTS if room_id == "wardrobe" else VaultInventory.SLOTS
	for slot: String in slots:
		var uid := String(profile.equipment.get(slot, ""))
		# Wardrobe plinth positions label primary/secondary, so an empty primary
		# must never shift the secondary model onto the primary plinth.
		if room_id == "wardrobe": uids.append(uid)
		elif not uid.is_empty() and not uids.has(uid): uids.append(uid)
	if room_id == "armory":
		for entry: Dictionary in profile.inventory:
			var definition := VaultLootTable.item_for(String(entry.item_id))
			if bool(entry.get("favorite", false)) and definition != null and definition.category == "equipment" \
				and not uids.has(String(entry.uid)): uids.append(String(entry.uid))
	for index in range(mini(MAX_GEAR, points.size())):
		var point: Vector3 = points[index]
		var entry: Dictionary = VaultInventory.find(profile, uids[index]) if index < uids.size() else {}
		var definition := VaultLootTable.item_for(String(entry.get("item_id", "")))
		if entry.is_empty() or definition == null or not bool(entry.get("identified", false)):
			_label(kit, "EMPTY SHOWCASE\nEquip or favorite owned gear", point + Vector3(0, 0.65, 0.9))
			continue
		var holder := Node3D.new()
		holder.name = "OwnedGear_" + str(index)
		holder.position = point
		holder.set_meta("dynamic_visual", true)
		holder.set_meta("owned_item_uid", String(entry.uid))
		holder.set_meta("item_id", String(entry.item_id))
		_dynamic.add_child(holder)
		var model := definition.visual_scene.instantiate() as Node3D if definition.visual_scene != null else null
		if model == null:
			_label(kit, definition.label + "\nDisplay model unavailable", point + Vector3.UP * 0.65)
			continue
		_disable_display_collision(model)
		holder.add_child(model)
		var presentation := ItemPresentation.new()
		presentation.position = point
		_dynamic.add_child(presentation)
		presentation.configure(definition, entry, holder, &"display")
		presentation.apply_visual_settings(_settings)
		_label(kit, "%s +%d\n%s · Owned showcase" % [definition.label, int(entry.enhancement), String(definition.rarity).replace("_", " ").capitalize()], point + Vector3(0, 0.75, 0.9))
		_presentation.equipment.append({"uid": String(entry.uid), "item_id": String(entry.item_id), "enhancement": int(entry.enhancement), "visual_scene": definition.visual_scene.resource_path})

func _disable_display_collision(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child: Node in node.get_children(): _disable_display_collision(child)

func _show_player_appearance(profile: Dictionary, kit: Architecture) -> void:
	var points: Array = _anchors.get("avatars", [])
	if points.is_empty(): return
	var active_entry := VaultInventory.active_weapon_entry(profile)
	var definition := VaultLootTable.item_for(String(active_entry.get("item_id", "")))
	var style: StringName = definition.weapon_style if definition != null and definition.weapon_style in [&"sword", &"staff"] else &"sword"
	var avatar := Avatar.new() as Node3D
	avatar.set("static_item_presentation", true)
	avatar.position = points[0]
	# Authored mannequins face the room center whether their alcove is north
	# (Wardrobe) or in a southern perimeter bay (Armory).
	var anchor: Vector3 = points[0]
	avatar.rotation.y = atan2(anchor.x, anchor.z)
	_dynamic.add_child(avatar)
	var stats := CharacterProgression.resolve_stats(profile, style)
	avatar.set_equipment_appearance(stats.appearance)
	avatar.set_weapon(style)
	avatar.apply_visual_settings(_settings)
	_avatars.append(avatar)
	_label(kit, "YOUR EQUIPPED APPEARANCE\nUse the mirror to rotate and inspect", Vector3(points[0]) + Vector3(0, 2.4, 0))
	_presentation["player_appearance"] = stats.appearance.duplicate(true)

func _show_companions(profile: Dictionary, kit: Architecture) -> void:
	var points: Array = _anchors.get("avatars", [])
	for index in range(mini(MAX_AVATARS, points.size())):
		var id := "guardian" if index == 0 else "mystic"
		var definition: Resource = GUARDIAN if index == 0 else MYSTIC
		var entry: Dictionary = profile.companions[id]
		var label := "%s · %s\nLevel %d · %s\n%s" % [String(entry.name), String(definition.role), int(entry.level), String(entry.trait), "Recruited adventurer portrait" if bool(entry.recruited) else "Not recruited · Manage adventurers at the lectern"]
		_label(kit, label, Vector3(points[index]) + Vector3(0, 2.4, 0))
		_presentation.companions.append({"id": id, "name": entry.name, "level": entry.level, "experience": entry.experience, "recruited": entry.recruited})
		if not bool(entry.recruited): continue
		var avatar := Avatar.new() as Node3D
		avatar.set("static_item_presentation", true)
		avatar.set("_armor_color", definition.tint)
		avatar.position = points[index]
		avatar.rotation.y = PI
		_dynamic.add_child(avatar)
		avatar.set_weapon(definition.weapon_style)
		avatar.apply_visual_settings(_settings)
		_avatars.append(avatar)

func _show_pet(profile: Dictionary, kit: Architecture) -> void:
	if not _anchors.has("pet"): return
	var point: Vector3 = _anchors.pet
	var id := String(profile.pets.active_id)
	var definition := PetCatalog.definition_for(StringName(id))
	if definition == null or not profile.pets.owned.has(id):
		_label(kit, "PET RESTING PLACE\nSelect an owned active pet in Spiritweaving", point + Vector3(0, 1.3, 0))
		return
	var entry: Dictionary = profile.pets.owned[id]
	var alias := String(entry.get("alias", ""))
	var appearance := {"id": id, "display_name": alias if not alias.is_empty() else definition.label, "variant": entry.get("variant", "natural")}
	var pet := PetVisual.new()
	if not pet.configure(definition, appearance):
		pet.free()
		return
	pet.position = point
	pet.rotation.y = PI
	_dynamic.add_child(pet)
	pet.apply_visual_settings(_settings)
	_pet_visual = pet
	_label(kit, "%s\n%s · Cosmetic resting display" % [appearance.display_name, String(definition.rarity).capitalize()], point + Vector3(0, 1.3, 0))
	_presentation.active_pet = appearance.duplicate(true)

func _show_records(profile: Dictionary, kit: Architecture) -> void:
	if not _anchors.has("records"): return
	var text := "YOUR PERSONAL SANCTUARY\n%s · Cosmetic home theme" % _last_theme.replace("_", " ").capitalize()
	match room_id:
		"armory": text = "YOUR ARMORY\n%d owned showcases · Equipment remains in your inventory" % _presentation.equipment.size()
		"companion_hall": text = "ADVENTURER ROSTER\nGuardian · Sword and Shield / Mystic · Magic Staff\nPortraits read your existing saved companions"
		"relic_library":
			var records: Dictionary = profile.encounter_records.entries
			text = "SECURED EXPEDITION CHRONICLE\n%d completed expeditions · Deepest clear %d\n%d item discoveries · %d monster discoveries\n%d recorded encounters · %d discovered themes" % [int(profile.statistics.completed), int(profile.depth_progression.highest_cleared_depth), profile.discoveries.size(), profile.monster_discoveries.size(), records.size(), profile.encounter_records.themes.size()]
			_presentation["records"] = {"completed": int(profile.statistics.completed), "deepest_clear": int(profile.depth_progression.highest_cleared_depth), "item_discoveries": profile.discoveries.size(), "monster_discoveries": profile.monster_discoveries.size(), "encounters": records.duplicate(true), "themes": profile.encounter_records.themes.duplicate()}
		"wardrobe": text = "WARDROBE MIRROR\nYour equipped appearance · Drag the inspection preview to rotate\nSkins and hairstyles are not available in this build"
		"rooftop_garden": return # The active-pet plaque occupies this garden anchor.
	_label(kit, text, _anchors.records)

func apply_visual_settings(settings: Dictionary) -> void:
	_settings = settings.duplicate(true)
	_motion_scale = clampf(float(settings.get("decorative_motion_scale", 0.0 if settings.get("reduced_motion", false) else 1.0)), 0.0, 1.0)
	_pose_interval = 0.1 if int(settings.get("quality", 1)) == 0 else 0.05
	for avatar: Node3D in _avatars:
		if is_instance_valid(avatar): avatar.apply_visual_settings(settings)
	if is_instance_valid(_pet_visual): _pet_visual.apply_visual_settings(settings)

func _process(delta: float) -> void:
	if _motion_scale <= 0.0 or not is_visible_in_tree(): return
	_pose_clock += minf(maxf(delta, 0.0), 0.1)
	_pose_time += minf(maxf(delta, 0.0), 0.1)
	if _pose_clock < _pose_interval: return
	var step := _pose_clock * _motion_scale
	_pose_clock = 0.0
	for avatar: Node3D in _avatars:
		if is_instance_valid(avatar): avatar.animate(step, 0.0, 0.0, 0.0)
	if is_instance_valid(_pet_visual): _pet_visual.pose(&"idle", _pose_time * _motion_scale)

func presentation_snapshot() -> Dictionary:
	var result := _presentation.duplicate(true)
	result.merge({"room_id": room_id, "home_id": _home_id, "home_visit": is_home_origin_visit(),
		"theme_id": _last_theme, "revision": _last_revision, "max_gear": MAX_GEAR, "max_avatars": MAX_AVATARS, "max_pets": MAX_PETS,
		"avatar_count": _avatars.size(), "pet_count": 1 if is_instance_valid(_pet_visual) else 0,
		"pose_interval": _pose_interval, "motion_scale": _motion_scale, "prototype_art": true})
	return result

func room_layout() -> Dictionary:
	var result := _layout.duplicate(true)
	if result.is_empty(): return result
	var approaches := {"home": Vector3(_layout.management) + Vector3.RIGHT * 2.0 + Vector3.UP * 0.15,
		"return": Vector3(_layout["return"]) + Vector3.FORWARD * 1.7 + Vector3.UP * 0.15}
	for kind: StringName in _services:
		var service := _services[kind] as Node3D
		var toward_center := Vector3(-signf(service.position.x), 0, 0)
		approaches[String(kind)] = service.position + toward_center * 2.0 + Vector3.UP * 0.15
	result["service_approaches"] = approaches
	result["camera_points"] = result.get("routes", []).duplicate()
	for point: Vector3 in approaches.values(): result.camera_points.append(point)
	return result

func get_spawn_transform(_entry_id: StringName) -> Transform3D:
	var layout: Dictionary = _layout if not _layout.is_empty() else Workrooms.layout(room_id) if room_id in WORKROOM_IDS else PrivateRooms.layout(room_id)
	return global_transform * Transform3D(Basis.IDENTITY, layout.get("spawn", Vector3(0, 0.15, 7)))

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
