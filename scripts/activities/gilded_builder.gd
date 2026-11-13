extends RefCounted
## Original native rooms plus restrained Gilded-owned visual accents. The caller
## validates the issued plan and pins the returned native identities. This builder
## owns no source, actor, authority, reward, transition or gameplay timer.

const Architecture = preload("res://scripts/world/architecture.gd")
const Style = preload("res://scripts/visual/visual_style.gd")
const Batcher = preload("res://scripts/visual/static_visual_batcher.gd")
const Layout = preload("res://resources/activities/gilded_layout.tres")
const ROOM_MODULES := ["entrance_temple", "corridor_roots", "treasure_garden", "combat_temple", "treasure_vault", "secret_hollow"]
const ROOM_TITLES := ["ARRIVAL COURT", "THE RUNES' CLUE", "GARDEN OF THREE SIGNS", "THE STONE GUARDIAN", "SEALED TREASURY", "SECRET HOLLOW"]
const ROOM_HINTS := ["Return with taken treasure", "Read the original tablet", "Walk the named rune order", "Defeat the guardian", "Runes and guardian unlock the seal", "A warning protects the hidden cache"]
const WAY_NAMES := ["RETURN", "CLUE", "RUNES", "GUARDIAN", "TREASURY", "UNUSUAL MASONRY"]

static func build(world: Node3D, plan: Dictionary, seed_value: int) -> Dictionary:
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion() or world.has_node("Rooms"): return {}
	var layout: Variant = plan.get("layout")
	if not layout is Dictionary or layout.get("room_size") != 24 or not layout.get("rooms") is Array \
			or layout.rooms.size() != ROOM_MODULES.size(): return {}
	var holder := Node3D.new()
	holder.name = "Rooms"
	var rooms: Dictionary = {}
	var floors: Dictionary = {}
	# Configure all modules off tree. No partial room construction enters the
	# active world if a canonical scene, native floor or required API is missing.
	for index in range(ROOM_MODULES.size()):
		var value: Variant = layout.rooms[index]
		if not value is Dictionary:
			holder.free()
			return {}
		var row: Dictionary = value
		var expected_path := "res://scenes/rooms/%s.tscn" % ROOM_MODULES[index]
		var at := Layout.room_origin(plan, index)
		if row.get("id") != index or row.get("module_id") != ROOM_MODULES[index] or row.get("scene") != expected_path \
				or not at.is_finite() or not row.get("openings") is Array or not row.get("neighbors") is Array:
			holder.free()
			return {}
		var packed := load(expected_path) as PackedScene
		if packed == null:
			holder.free()
			return {}
		var room := packed.instantiate() as Node3D
		if room == null or not room.has_method("configure_openings") or not room.has_method("configure_visuals"):
			if is_instance_valid(room): room.free()
			holder.free()
			return {}
		var floor_body := room.get_node_or_null("Floor/Body") as StaticBody3D
		if floor_body == null or room.get_node_or_null("Floor/Body/Collision") == null:
			room.free()
			holder.free()
			return {}
		var openings: Array[StringName] = []
		for direction: Variant in row.openings:
			if not direction is String or direction not in ["north", "south", "east", "west"] or StringName(direction) in openings:
				room.free()
				holder.free()
				return {}
			openings.append(StringName(direction))
		room.name = "Room_%02d_%s" % [index, ROOM_MODULES[index].to_pascal_case()]
		room.position = at
		room.configure_openings(openings)
		room.configure_visuals(seed_value, index)
		holder.add_child(room)
		rooms[index] = room
		floors[index] = floor_body
	world.add_child(holder)
	if not is_instance_valid(world) or world.is_queued_for_deletion() or not is_instance_valid(holder) \
			or holder.get_parent() != world or holder.is_queued_for_deletion(): return {}
	var environment := Style.apply_environment(world, &"hall")
	if not is_instance_valid(world) or world.is_queued_for_deletion() or not is_instance_valid(environment): return {}
	environment.environment.background_color = Color("1d2936")
	environment.environment.ambient_light_color = Color("d6c6a3")
	environment.environment.ambient_light_energy = 0.78
	environment.environment.fog_light_color = Color("596369")
	environment.environment.fog_depth_begin = 28.0
	environment.environment.fog_depth_end = 76.0
	var materials := _accent_materials()
	var visual_report := {"native_rooms": 6, "native_placeholder_art": true, "source_art_reused": true,
		"extra_local_lights": 0, "directional_keys": 1, "extra_particle_systems": 0,
		"extra_processing_nodes": 0, "extra_gameplay_bodies": 0, "extra_camera_bodies": 0,
		"native_ambience_reused": true, "accent_source_meshes": 0, "accent_labels": 0,
		"accent_batch_reports": {}, "cosmetic_seed": seed_value}
	for index in range(ROOM_MODULES.size()):
		var room := rooms[index] as Node3D
		if not is_instance_valid(world) or world.is_queued_for_deletion() or not is_instance_valid(room) \
				or room.get_parent() != holder: return {}
		var accents := Node3D.new()
		accents.name = "GildedAccents"
		accents.set_meta("native_placeholder_art", true)
		room.add_child(accents)
		var kit := Architecture.new(accents)
		for key: String in materials: kit.palette[key] = materials[key]
		_room_sign(kit, index)
		_door_guides(kit, plan, index)
		if index in [0, 4]: _arch_key(kit, -7.8 if index == 0 else -8.0)
		if index == 0:
			var title := kit.label("THE GILDED VAULT", Vector3(0, 5.2, -7.05), 42, Color("ead8a2"))
			title.pixel_size = 0.0045
			title.visibility_range_end = 38.0
		visual_report.accent_source_meshes += accents.find_children("*", "MeshInstance3D", true, false).size()
		visual_report.accent_labels += accents.find_children("*", "Label3D", true, false).size()
		# Bake only these new accents. Native room sources and their collision
		# parents remain untouched; native scenes are not falsely claimed batched.
		visual_report.accent_batch_reports[index] = Batcher.bake(accents, 8.0)
	return {"rooms": rooms, "floors": floors, "holder": holder, "visual_report": visual_report}

static func _accent_materials() -> Dictionary:
	# A single world-local shared set. Never recolor the imported room palette or
	# call the closed Rootbound/Crystal/Ember presentation contract with fake data.
	var slate := StandardMaterial3D.new()
	slate.albedo_color = Color("334449")
	slate.roughness = 0.92
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("c2a263")
	gold.metallic = 0.32
	gold.roughness = 0.72
	var ivory := StandardMaterial3D.new()
	ivory.albedo_color = Color("d7d6bf")
	ivory.roughness = 0.88
	return {"gilded_slate": slate, "gilded_gold": gold, "gilded_ivory": ivory}

static func _room_sign(kit: Architecture, room_id: int) -> void:
	# Shallow presentation on an existing solid wall apron. It does not create
	# another obstacle, chest, interactable or authority-bearing source.
	var at := Vector3(5.5, 1.65, 11.30)
	kit.box(at, Vector3(3.10, 1.10, 0.08), "gilded_slate")
	for side: float in [-1.0, 1.0]:
		kit.box(at + Vector3(0, side * 0.57, -0.025), Vector3(3.22, 0.055, 0.06), "gilded_gold")
		kit.box(at + Vector3(side * 1.58, 0, -0.025), Vector3(0.055, 1.15, 0.06), "gilded_gold")
	var label := kit.label(ROOM_TITLES[room_id] + "\n" + ROOM_HINTS[room_id], at + Vector3(0, 0, -0.09), 23, Color("e7dbb3"))
	label.pixel_size = 0.0035
	label.visibility_range_end = 23.0

static func _door_guides(kit: Architecture, plan: Dictionary, room_id: int) -> void:
	var row: Dictionary = plan.layout.rooms[room_id]
	var origin := Layout.room_origin(plan, room_id)
	for neighbor: int in row.neighbors:
		var destination := Layout.room_origin(plan, neighbor)
		if not destination.is_finite(): continue
		var delta := destination - origin
		if not is_equal_approx(delta.length(), Layout.ROOM_SIZE): continue
		var outward := delta.normalized()
		var tangent := Vector3(outward.z, 0, -outward.x)
		var heading := atan2(outward.x, outward.z)
		var at := outward * 9.3 + Vector3.UP * 0.065
		# Flat bidirectional diamonds indicate a route without implying that the
		# sealed optional room is already open. Actual gates remain world-owned.
		for side: float in [-1.0, 1.0]:
			var stroke := kit.box(at + tangent * side * 0.13, Vector3(0.055, 0.008, 0.44), "gilded_gold")
			stroke.rotation.y = heading + side * 0.63
		var direction_label := kit.label(WAY_NAMES[neighbor], outward * 10.25 + Vector3.UP * 2.75, 21, Color("d2d2b6"))
		direction_label.pixel_size = 0.0033
		direction_label.visibility_range_end = 19.0

static func _arch_key(kit: Architecture, arch_z: float) -> void:
	# Small original key silhouette beneath the existing lintel, without another
	# portal, animation, light or collision volume across the arch opening.
	var at := Vector3(0, 3.55, arch_z + 0.72)
	kit.ring(at + Vector3.UP * 0.16, 0.14, 0.20, "gilded_gold").rotation.x = PI * 0.5
	kit.box(at + Vector3(0, -0.16, 0), Vector3(0.065, 0.46, 0.055), "gilded_gold")
	for height: float in [-0.29, -0.17]:
		kit.box(at + Vector3(0.09, height, 0), Vector3(0.22, 0.06, 0.055), "gilded_ivory")
