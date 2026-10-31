extends Node3D
## Reusable, manually activated portal. The session owns the actual level swap.

signal travel_requested(destination: StringName, entry_id: StringName)
signal portal_info_requested(source: Node3D)

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


func _ready() -> void:
	add_to_group("interactables")
	var palette := preload("res://scripts/visual/visual_style.gd").palette()
	var stone: Material = palette.light_stone
	var dark_stone: Material = palette.dark_stone
	var gold: Material = palette.gold
	var glow: Material = palette.glow
	_surface_material = ShaderMaterial.new()
	_surface_material.shader = preload("res://resources/shaders/portal_veil.gdshader")
	if destination == &"collection_hall":
		_surface_material.set_shader_parameter("magic_color", Color("9f814c"))
		_surface_material.set_shader_parameter("rim_color", Color("e4cea3"))
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
	_time += delta
	_runes.rotation.z = _time * 0.08
	if require_entry_card and is_instance_valid(_range_label):
		_range_elapsed += delta
		if _range_elapsed >= 0.15:
			_range_elapsed = 0.0
			var in_reach := can_interact(_near_player)
			_range_label.visible = in_reach
			_range_material.albedo_color = Color("a5fff0") if in_reach else Color("6a9791")


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
