extends Node3D
## Small Sanctuary service counter. Transactions belong to ExpeditionSession;
## this scene only identifies a reachable service and presents its NPC.

const Architecture = preload("res://scripts/world/architecture.gd")
const Avatar = preload("res://scripts/player/player_avatar.gd")

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
