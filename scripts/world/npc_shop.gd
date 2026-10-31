extends Node3D
## Small Sanctuary service counter. Transactions belong to ExpeditionSession;
## this scene only identifies a reachable service and presents its NPC.

const Architecture = preload("res://scripts/world/architecture.gd")
const Avatar = preload("res://scripts/player/player_avatar.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")

@export var service_kind: StringName = &"merchant"
@export var vendor := "general"
@export var display_name := "Mara · General Merchant"
@export var interaction_radius := 2.8
@export var accent := Color("688971")

var _avatar: Node3D

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("commerce_services")
	add_to_group("sanctuary_merchants")
	var kit := Architecture.new(self)
	kit.palette["stall_cloth"] = kit.material(accent)
	kit.palette["stall_dark"] = kit.material(accent.darkened(0.62))
	kit.box(Vector3(0, 0.03, -1.1), Vector3(3.35, 0.04, 2.65), "dark_stone")
	kit.box(Vector3(0, 1.0, -2.2), Vector3(3.15, 2.0, 0.18), "wood", true)
	kit.box(Vector3(0, 0.6, -0.65), Vector3(2.7, 1.2, 0.55), "stall_dark", true)
	kit.box(Vector3(0, 1.23, -0.65), Vector3(2.95, 0.14, 0.73), "gold")
	for x in [-1.37, 1.37]:
		kit.box(Vector3(x, 1.35, -1.4), Vector3(0.13, 2.7, 0.13), "wood", true)
		kit.box(Vector3(x, 2.7, -1.1), Vector3(0.18, 0.12, 2.4), "gold")
	kit.box(Vector3(0, 2.82, -1.1), Vector3(3.35, 0.14, 2.55), "stall_cloth")
	kit.box(Vector3(0, 2.6, 0.12), Vector3(3.35, 0.3, 0.12), "stall_cloth")
	kit.box(Vector3(0, 2.43, 0.14), Vector3(3.38, 0.045, 0.13), "gold")
	for x in [-1.0, 1.0]:
		kit.box(Vector3(x, 0.6, -0.35), Vector3(0.05, 0.9, 0.04), "gold")
	var title := kit.label(display_name, Vector3(0, 3.28, -0.8), 26, Color("edd4a3"))
	title.pixel_size = 0.005
	var subtitle := kit.label(_service_label(), Vector3(0, 0.16, 0.65), 20, Color("d0c4ac"))
	subtitle.pixel_size = 0.005
	_avatar = Node3D.new()
	_avatar.set_script(Avatar)
	_avatar.set("_armor_color", accent)
	_avatar.position = Vector3(0, 0.0, -1.55)
	_avatar.rotation.y = PI
	_avatar.scale = Vector3.ONE * 0.86
	add_child(_avatar)
	# Shops have no combat controller and cannot attack, join parties or take loot.
	_avatar.set_weapon(&"staff" if vendor == "appraiser" else &"sword")
	_avatar.get("_sword").visible = false
	_avatar.get("_shield").visible = false
	if vendor != "appraiser":
		_avatar.get("_staff").visible = false
	_build_stock_decoration(kit)
	_build_craft_detail(kit)
	_keep_static_collision(self)

func _service_label() -> String:
	if service_kind == &"blacksmith":
		return "UPGRADE  ·  REPAIR  ·  CRAFT"
	match vendor:
		"equipment": return "WEAPONS  ·  ARMOR"
		"appraiser": return "ARTIFACT IDENTIFICATION"
	return "SUPPLIES  ·  MATERIALS"

func _build_stock_decoration(kit: Architecture) -> void:
	if service_kind == &"blacksmith":
		kit.box(Vector3(-0.8, 1.45, -0.6), Vector3(0.5, 0.28, 0.32), "stone")
		kit.box(Vector3(-0.8, 1.64, -0.6), Vector3(0.8, 0.12, 0.4), "light_stone")
		var hammer := kit.box(Vector3(0.7, 1.4, -0.6), Vector3(0.08, 0.08, 0.55), "wood")
		hammer.rotation.y = -0.45
		kit.box(Vector3(0.83, 1.42, -0.8), Vector3(0.3, 0.18, 0.15), "light_stone")
		kit.cylinder(Vector3(1.8, 0.55, -1.5), 0.32, 1.1, "dark_stone", true, 8)
		kit.cone(Vector3(1.8, 1.2, -1.5), 0.23, 0.55, "flame")
	elif vendor == "equipment":
		for x in [-0.75, 0.7]:
			kit.box(Vector3(x, 1.35, -0.65), Vector3(0.08, 0.07, 0.7), "light_stone")
			kit.box(Vector3(x, 1.36, -0.35), Vector3(0.35, 0.09, 0.07), "gold")
	elif vendor == "appraiser":
		var gem := kit.cone(Vector3(0.85, 1.62, -0.65), 0.22, 0.62, "glow")
		gem.rotation.z = 0.15
		kit.box(Vector3(-0.7, 1.37, -0.65), Vector3(0.65, 0.14, 0.4), "stall_cloth")
		kit.box(Vector3(-0.7, 1.46, -0.65), Vector3(0.57, 0.035, 0.34), "light_stone")
	else:
		for x in [-0.9, -0.55, 0.75]:
			kit.cylinder(Vector3(x, 1.5, -0.65), 0.12, 0.4, "glow" if x > 0 else "crystal", false, 8)
			kit.cylinder(Vector3(x, 1.73, -0.65), 0.065, 0.09, "gold", false, 8)
		kit.box(Vector3(0, 1.38, -0.65), Vector3(0.45, 0.18, 0.35), "wood")

func _build_craft_detail(kit: Architecture) -> void:
	var art := Dressing.new(self, kit.palette)
	for side in [-1.0, 1.0]:
		art.beam(Vector3(side * 1.35, 2.15, -0.05), Vector3(side * 0.92, 2.6, -0.05), 0.09, 0.08, "bronze")
		art.box(Vector3(side * 1.35, 2.11, 0.1), Vector3(0.22, 0.34, 0.18), "flame")
		art.box(Vector3(side * 1.35, 2.32, 0.1), Vector3(0.3, 0.06, 0.24), "bronze")
		art.box(Vector3(side * 1.35, 1.9, 0.1), Vector3(0.3, 0.06, 0.24), "bronze")
		art.inset(Vector3(side * 0.75, 0.22, -0.36), Vector2(0.82, 0.74), "bronze")
	for index in range(7):
		var x := -1.42 + index * 0.47
		art.box(Vector3(x, 2.91, -1.1), Vector3(0.07, 0.025, 2.4), "bronze")
		art.box(Vector3(x, 2.54, 0.19), Vector3(0.14, 0.16, 0.025), "gold")
	if service_kind == &"blacksmith":
		# Forge masonry wraps the existing hearth footprint, avoiding a new obstacle.
		for index in range(3):
			art.box(Vector3(1.8, 0.32 + index * 0.31, -1.5), Vector3(0.58, 0.22, 0.58), "stone")
		art.box(Vector3(1.8, 0.9, -1.19), Vector3(0.28, 0.2, 0.03), "flame")
		art.box(Vector3(0.75, 2.05, -2.05), Vector3(0.72, 0.065, 0.15), "bronze")
		for x in [0.48, 0.75, 1.02]:
			art.box(Vector3(x, 1.83, -1.97), Vector3(0.05, 0.45, 0.05), "wood")
			art.box(Vector3(x, 1.63, -1.97), Vector3(0.19, 0.12, 0.09), "light_stone")
		for index in range(3):
			art.box(Vector3(-0.78 + index * 0.28, 0.2, -1.94), Vector3(0.22, 0.22, 0.28), "light_stone")
	elif vendor == "appraiser":
		# An astrolabe motif and specimen shelves distinguish the appraiser from shops.
		art.inset(Vector3(0.0, 1.5, -2.06), Vector2(1.2, 0.55), "bronze")
		for side in [-1.0, 1.0]:
			art.facet(Vector3(side * 0.88, 1.9, -1.94), Vector3(0.23, 0.42, 0.23), "crystal", side)
			art.box(Vector3(side * 0.88, 1.57, -1.94), Vector3(0.42, 0.1, 0.33), "bronze")
		art.facet(Vector3(0, 1.8, -2.0), Vector3(0.34, 0.5, 0.08), "glow")
	elif vendor == "equipment":
		for side in [-1.0, 1.0]:
			art.facet(Vector3(side * 0.86, 1.52, -1.99), Vector3(0.55, 0.65, 0.13), "bronze")
			art.facet(Vector3(side * 0.86, 1.52, -1.89), Vector3(0.33, 0.4, 0.04), "stall_cloth")
			art.box(Vector3(side * 1.15, 1.5, -1.96), Vector3(0.06, 1.4, 0.07), "light_stone")
			art.box(Vector3(side * 1.15, 1.15, -1.9), Vector3(0.3, 0.06, 0.08), "gold")
	else:
		for side in [-1.0, 1.0]:
			art.box(Vector3(side * 0.86, 1.55, -1.99), Vector3(0.8, 0.08, 0.32), "wood")
			for index in range(3):
				art.orb(Vector3(side * 0.86 + (index - 1) * 0.22, 1.72, -1.96), Vector3(0.19, 0.28, 0.19), "crystal")
				art.box(Vector3(side * 0.86 + (index - 1) * 0.22, 1.89, -1.96), Vector3(0.08, 0.07, 0.08), "gold")
		art.fern(Vector3(-1.22, 0.06, -2.0), 0.45, 1.0)
	art.flush("ServiceCraftwork")
	var occluder := StaticBody3D.new()
	occluder.name = "StallCanopyCameraOccluder"
	occluder.collision_layer = 8
	occluder.collision_mask = 0
	occluder.position = Vector3(0, 2.82, -1.1)
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(3.35, 0.14, 2.55)
	shape.shape = bounds
	occluder.add_child(shape)
	add_child(occluder)

func _keep_static_collision(node: Node) -> void:
	if node is StaticBody3D:
		node.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	for child: Node in node.get_children():
		_keep_static_collision(child)

func get_prompt() -> String:
	return display_name + " · " + ("Open forge" if service_kind == &"blacksmith" else "Trade")

func interact(actor: Node3D) -> void:
	if not is_instance_valid(actor) or not actor.is_in_group("player"):
		return
	var session := get_node_or_null("/root/ExpeditionSession")
	if session != null and session.has_method("open_service"):
		session.open_service(service_kind, {"vendor": vendor, "station_id": get_instance_id()})
