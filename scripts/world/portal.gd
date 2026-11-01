extends Node3D
## Reusable, manually activated portal. The session owns the actual level swap.

signal travel_requested(destination: StringName, entry_id: StringName)
signal portal_info_requested(source: Node3D)

# This is presentation data for existing routes, never a destination registry.
# Purple/red landmarks are added only when their playable worlds are implemented.
const VISUAL_PROFILES := {
	&"rootbound_abyss": preload("res://resources/portals/rootbound.tres"),
	&"collection_hall": preload("res://resources/portals/collection_hall.tres"),
	&"dungeon": preload("res://resources/portals/dungeon_practice.tres"),
	&"combat_arena": preload("res://resources/portals/combat_practice.tres"),
	&"sanctuary": preload("res://resources/portals/sanctuary_return.tres"),
}

@export var destination: StringName = &"dungeon"
@export var entry_id: StringName = &"from_sanctuary"
@export var title: String = "THE SHIFTING DEPTHS"
@export var interaction_radius: float = 3.0
@export var require_entry_card := false

var _runes: Node3D
var _surface: MeshInstance3D
var _surface_material: ShaderMaterial
var _time: float = 0.0
var _range_label: Label3D
var _range_material: StandardMaterial3D
var _range_elapsed := 0.0
var _near_player: Node3D
var _motion_scale := 1.0
var _high_contrast := false
var _visual_profile: Resource
var _route_label: Label3D


func _ready() -> void:
	add_to_group("interactables")
	var palette := preload("res://scripts/visual/visual_style.gd").palette()
	var stone: Material = palette.light_stone
	var dark_stone: Material = palette.dark_stone
	var gold: Material = palette.gold
	_visual_profile = VISUAL_PROFILES.get(destination, VISUAL_PROFILES[&"dungeon"])
	set_meta("portal_visual_profile_id", _visual_profile.id)
	# Tinting a cached palette resource would recolor every other world and gate.
	var glow := palette.glow.duplicate() as StandardMaterial3D
	glow.albedo_color = _visual_profile.accent_color
	glow.emission = _visual_profile.accent_color
	_surface_material = ShaderMaterial.new()
	_surface_material.shader = preload("res://resources/shaders/portal_veil.gdshader")
	_surface_material.set_shader_parameter("deep_color", _visual_profile.deep_color)
	_surface_material.set_shader_parameter("magic_color", _visual_profile.magic_color)
	_surface_material.set_shader_parameter("rim_color", _visual_profile.rim_color)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 1.95, 0.22, 0), Vector3(0.9, 0.44, 0.9), dark_stone)
		_box(Vector3(side * 1.95, 1.7, 0), Vector3(0.56, 2.8, 0.62), stone, true)
		_box(Vector3(side * 1.95, 1.7, 0.33), Vector3(0.08, 2.48, 0.05), gold)
		_box(Vector3(side * 1.95, 3.2, 0), Vector3(0.84, 0.24, 0.82), gold)
		_box(Vector3(side * 1.95, 3.39, 0), Vector3(0.7, 0.15, 0.69), dark_stone)
		var finial := _cylinder(Vector3(side * 1.95, 3.67, 0), 0.27, 0.0, 0.5, stone)
		finial.rotation_degrees.y = 45
		_box(Vector3(side * 1.95, 0.66, 0.35), Vector3(0.2, 0.35, 0.08), glow)

	_ring(Vector3(0, 2.2, 0), 1.76, 1.98, stone, Vector3(1, 1, 1.15))
	_ring(Vector3(0, 2.2, 0.12), 1.69, 1.76, gold, Vector3(1, 1, 1.15))
	_ring(Vector3(0, 2.2, 0.16), 1.62, 1.67, glow, Vector3(1, 1, 1.15))
	var surface_mesh := QuadMesh.new()
	surface_mesh.size = Vector2(3.22, 3.22)
	_surface = _mesh(surface_mesh, Vector3(0, 2.2, 0), _surface_material)
	_surface.scale = Vector3(1.0, 1.15, 1.0)
	# The opaque veil must retract a camera behind it without blocking the player.
	var occluder := StaticBody3D.new()
	occluder.name = "CameraOccluder"
	occluder.position = Vector3(0, 2.2, 0)
	occluder.collision_layer = 8
	occluder.collision_mask = 0
	var camera_shape := CollisionShape3D.new()
	var veil_bounds := BoxShape3D.new()
	veil_bounds.size = Vector3(3.6, 4.3, 0.12)
	camera_shape.shape = veil_bounds
	occluder.add_child(camera_shape)
	add_child(occluder)
	_ring(Vector3(0, 2.2, 0.11), 1.14, 1.16, glow, Vector3(1, 1, 1.15))
	_ring(Vector3(0, 2.2, 0.12), 0.66, 0.68, gold, Vector3(1, 1, 1.15))

	_runes = Node3D.new()
	_runes.name = "OrbitingRunes"
	_runes.position = Vector3(0, 2.2, 0.18)
	add_child(_runes)
	var rune_mesh := BoxMesh.new()
	rune_mesh.size = Vector3(0.09, 0.22, 0.045)
	var rune_instances := MultiMesh.new()
	rune_instances.transform_format = MultiMesh.TRANSFORM_3D
	rune_instances.mesh = rune_mesh
	rune_instances.instance_count = 12
	for index in range(12):
		var angle: float = TAU * float(index) / 12.0
		rune_instances.set_instance_transform(index, Transform3D(Basis(Vector3.BACK, -angle), Vector3(sin(angle) * 1.43, cos(angle) * 1.62, 0)))
	var rune_batch := MultiMeshInstance3D.new()
	rune_batch.multimesh = rune_instances
	rune_batch.material_override = glow
	rune_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_runes.add_child(rune_batch)

	var keystone := _box(Vector3(0, 4.39, 0), Vector3(0.45, 0.45, 0.5), gold)
	keystone.rotation.z = PI / 4.0
	var title_label := Label3D.new()
	title_label.text = title
	title_label.font_size = 42
	title_label.pixel_size = 0.0029
	title_label.outline_size = 7
	title_label.modulate = Color("e5d2a4")
	title_label.position = Vector3(0, 4.96, 0)
	title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title_label)
	_add_landmark(stone, gold, glow)
	_route_label = Label3D.new()
	_route_label.name = "RouteKind"
	_route_label.text = _visual_profile.route_label
	_route_label.font_size = 30
	_route_label.pixel_size = 0.0031
	_route_label.outline_size = 8
	_route_label.modulate = _visual_profile.rim_color
	_route_label.position = Vector3(0, 5.26, 0)
	_route_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_route_label.no_depth_test = false
	add_child(_route_label)
	if require_entry_card:
		_range_material = StandardMaterial3D.new()
		_range_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_range_material.albedo_color = Color("6a9791")
		var reach_ring := TorusMesh.new()
		reach_ring.inner_radius = maxf(0.1, interaction_radius - 0.045)
		reach_ring.outer_radius = interaction_radius
		reach_ring.rings = 48
		reach_ring.ring_segments = 4
		_mesh(reach_ring, Vector3(0, 0.06, 0), _range_material)
		_range_label = Label3D.new()
		_range_label.text = "ENTER · F / USE"
		_range_label.font_size = 42
		_range_label.pixel_size = 0.004
		_range_label.outline_size = 12
		_range_label.modulate = Color("f1f1e8")
		_range_label.position = Vector3(0, 1.15, 0.3)
		_range_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_range_label.no_depth_test = false
		_range_label.visible = false
		add_child(_range_label)
		_near_player = get_tree().get_first_node_in_group("player") as Node3D


func _process(delta: float) -> void:
	_time += delta * _motion_scale
	_runes.rotation.z = _time * 0.08
	if require_entry_card and is_instance_valid(_range_label):
		_range_elapsed += delta
		if _range_elapsed >= 0.15:
			_range_elapsed = 0.0
			var in_reach := can_interact(_near_player)
			_range_label.visible = in_reach
			_range_material.albedo_color = Color.WHITE if _high_contrast and in_reach else Color("a5fff0") if in_reach else Color("b4ccc6") if _high_contrast else Color("6a9791")


func apply_visual_settings(settings: Dictionary) -> void:
	_motion_scale = clampf(float(settings.get("decorative_motion_scale", 0.0 if bool(settings.get("reduced_motion", false)) else 1.0)), 0.0, 1.0)
	_high_contrast = bool(settings.get("high_contrast_prompts", false))
	if is_instance_valid(_route_label):
		_route_label.modulate = Color.WHITE if _high_contrast else _visual_profile.rim_color
		_route_label.outline_size = 12 if _high_contrast else 8
	if is_instance_valid(_range_label):
		_range_label.modulate = Color.WHITE if _high_contrast else Color("f1f1e8")
		_range_label.outline_size = 16 if _high_contrast else 12
		_range_label.font_size = 48 if _high_contrast else 42
		# Polling is intentionally independent from rune animation and remains active.
		_range_elapsed = 0.15


func get_prompt() -> String:
	if require_entry_card:
		return "Enter " + title.to_lower().capitalize() + " · details"
	match destination:
		&"sanctuary": return "Return to Sanctuary"
		&"combat_arena": return "Enter the Proving Grounds"
		&"rootbound_abyss": return "Begin a Rootbound Abyss expedition"
		&"collection_hall": return "Enter your Collection Hall"
		&"dungeon": return "Return to the Sunken Vault" if entry_id == &"from_arena" else "Enter the Sunken Vault"
	return "Use the passage"


func can_interact(actor: Node3D) -> bool:
	if not require_entry_card: return true
	return is_instance_valid(actor) and actor.is_inside_tree() and is_inside_tree() \
		and actor.global_position.distance_to(global_position) <= interaction_radius \
		and CombatRules.visible_from(actor, actor.global_position + Vector3.UP * 1.3, global_position + Vector3.UP * 1.6)


func interact(actor: Node3D) -> void:
	if require_entry_card:
		if can_interact(actor): portal_info_requested.emit(self)
	else:
		travel_requested.emit(destination, entry_id)


func _add_landmark(stone: Material, gold: Material, glow: Material) -> void:
	# Small original heraldry extends the upper frame, leaving the opening, existing
	# pillars and reach circle unchanged. Every added opaque box has exact camera
	# collision; none alters movement, interaction visibility or admission checks.
	var landmark := Node3D.new()
	landmark.name = "PortalLandmark"
	add_child(landmark)
	for side in [-1.0, 1.0]:
		var suffix := "West" if side < 0.0 else "East"
		_landmark_box(landmark, "Cornice" + suffix, Vector3(side * 1.68, 4.10, 0), Vector3(0.92, 0.20, 0.46), stone, side * -0.43)
		_landmark_box(landmark, "CorniceInlay" + suffix, Vector3(side * 1.68, 4.10, 0.25), Vector3(0.75, 0.055, 0.035), gold, side * -0.43)
	var center := Vector3(0, 4.39, 0.32)
	match _visual_profile.crest:
		"root":
			_landmark_box(landmark, "RootStem", center, Vector3(0.055, 0.35, 0.045), glow)
			for side in [-1.0, 1.0]:
				_landmark_box(landmark, "RootLeaf" + str(int(side)), center + Vector3(side * 0.09, 0.045, 0.015), Vector3(0.07, 0.23, 0.035), glow, side * -0.65)
		"relic":
			_landmark_box(landmark, "RelicDiamond", center, Vector3(0.22, 0.22, 0.045), glow, PI / 4.0)
			_landmark_box(landmark, "RelicCrown", center + Vector3(0, 0.21, 0), Vector3(0.26, 0.05, 0.045), glow)
			_landmark_box(landmark, "RelicFoot", center + Vector3(0, -0.21, 0), Vector3(0.26, 0.05, 0.045), glow)
		"practice":
			for side in [-1.0, 1.0]:
				_landmark_box(landmark, "PracticeBlade" + str(int(side)), center, Vector3(0.055, 0.40, 0.04), glow, side * 0.65)
		"home":
			for side in [-1.0, 1.0]:
				_landmark_box(landmark, "HomeRoof" + str(int(side)), center + Vector3(side * 0.075, 0.07, 0), Vector3(0.055, 0.25, 0.04), glow, side * 0.70)
			_landmark_box(landmark, "HomeDoor", center + Vector3(0, -0.10, 0), Vector3(0.08, 0.15, 0.045), glow)


func _landmark_box(parent: Node3D, node_name: String, at: Vector3, size: Vector3, material: Material, turn: float = 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var art := MeshInstance3D.new()
	art.name = node_name
	art.mesh = mesh
	art.position = at
	art.rotation.z = turn
	art.material_override = material
	art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(art)
	var body := StaticBody3D.new()
	body.name = "LandmarkCameraBlocker"
	body.collision_layer = 8
	body.collision_mask = 0
	art.add_child(body)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)


func _mesh(shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.position = at
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _box(at: Vector3, size: Vector3, material: Material, collision: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh(mesh, at, material)
	if collision:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		instance.add_child(body)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
	return instance


func _cylinder(at: Vector3, bottom: float, top: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 8
	return _mesh(mesh, at, material)


func _ring(at: Vector3, inner: float, outer: float, material: Material, proportions: Vector3) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 6
	var ring := _mesh(mesh, at, material)
	ring.rotation_degrees.x = 90
	ring.scale = proportions
	return ring
