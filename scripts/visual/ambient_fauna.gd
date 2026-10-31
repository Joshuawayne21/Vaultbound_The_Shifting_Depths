class_name VaultAmbientFauna
extends MultiMeshInstance3D
## Original native butterflies, with shader-only bounded wings and flight.
## Buffers belong to a room/garden; the world allocator governs active density.

const Budget = preload("res://scripts/visual/ambient_fauna_budget.gd")
const WING_MATERIAL = preload("res://resources/materials/ambient_wings.tres")
const SWEPT_MARGIN := Vector3(0.55, 0.35, 0.50)
const MAXIMUM_PER_REGION := 4
const WING_COLORS := [Color("88d5df"), Color("b29bdf"), Color("ecd599"), Color("9dcc9a"), Color("e5a8c2")]
var local_anchors := PackedVector3Array()
var cosmetic_seed := 1
var maximum_per_region := 4
var authored_instances: Array[Dictionary] = []
var _world_reference: WeakRef
var _manager: WeakRef
var _requested := 3
var _fingerprint := 0
var _displayed_indices := PackedInt32Array()

func configure(anchors: PackedVector3Array, visual_seed: int, maximum: int = 4, world_root: Node3D = null) -> void:
	local_anchors = anchors.duplicate()
	cosmetic_seed = visual_seed
	maximum_per_region = clampi(maximum, 0, MAXIMUM_PER_REGION)
	if world_root != null:
		_world_reference = weakref(world_root)

func _ready() -> void:
	name = "AmbientButterflies"
	add_to_group("ambient_fauna_regions")
	add_to_group("visual_quality")
	set_meta("dynamic_visual", true)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = SWEPT_MARGIN.length()
	_build_batch()
	var world: Node3D = _world_reference.get_ref() if _world_reference != null else null
	if not is_instance_valid(world):
		# Tests may instantiate a room directly. Never choose another live world.
		world = get_parent() as Node3D
		var ancestor := get_parent()
		while ancestor != null and ancestor.get_viewport() == get_viewport():
			if ancestor is Node3D:
				world = ancestor
				if ancestor.has_method("get_spawn_transform") or ancestor.has_method("get_companion_navigation_profile"):
					break
			ancestor = ancestor.get_parent()
	if is_instance_valid(world):
		var manager := Budget.ensure_for_world(world)
		_manager = weakref(manager)
		manager.register_region(self)
		material_override = manager.get_world_material()
	var preferences := get_node_or_null("/root/VisualSettings")
	if preferences != null:
		apply_visual_settings(preferences.snapshot())

func _exit_tree() -> void:
	if _manager != null and is_instance_valid(_manager.get_ref()):
		_manager.get_ref().unregister_region(self)

func _build_batch() -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var points := [Vector3(0, 0, -0.05), Vector3(side * 0.16, 0, -0.12), Vector3(side * 0.13, 0, 0.10), Vector3(0, 0, 0.045)]
		for corner in [0, 2, 1, 0, 3, 2]:
			mesh.set_normal(Vector3.UP)
			mesh.set_color(Color.WHITE)
			mesh.set_uv(Vector2((points[corner].x + 0.16) / 0.32, (points[corner].z + 0.12) / 0.24))
			mesh.add_vertex(points[corner])
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.use_custom_data = true
	instances.mesh = mesh.commit()
	instances.instance_count = maximum_per_region if not local_anchors.is_empty() else 0
	var random := RandomNumberGenerator.new()
	random.seed = cosmetic_seed
	authored_instances.clear()
	for index in range(instances.instance_count):
		var transform := Transform3D(Basis.IDENTITY, local_anchors[index % local_anchors.size()])
		var color: Color = WING_COLORS[posmod(cosmetic_seed + index, WING_COLORS.size())]
		var luminous := 1.0 if index == 0 and posmod(cosmetic_seed, 3) == 0 else 0.0
		var custom := Color(random.randf(), random.randf(), luminous, 1)
		authored_instances.append({"transform": transform, "color": color, "custom": custom})
		instances.set_instance_transform(index, transform)
		instances.set_instance_color(index, color)
		instances.set_instance_custom_data(index, custom)
	instances.visible_instance_count = 0
	multimesh = instances
	material_override = WING_MATERIAL
	# Dummy headless rendering exposes no MultiMesh buffer/readback. Fingerprint
	# the exact uploaded data, not a renderer-dependent read of that buffer.
	_fingerprint = hash(authored_instances)
	custom_aabb = get_swept_local_bounds()

func apply_visual_settings(settings: Dictionary) -> void:
	_requested = mini(maximum_per_region, 2 + clampi(int(settings.get("quality", 1)), 0, 2))
	if int(settings.get("ambient_particle_budget", settings.get("ambient_budget", 16))) <= 0:
		_requested = 0
	if _manager != null and is_instance_valid(_manager.get_ref()):
		_manager.get_ref().apply_visual_settings(settings)

func requested_count() -> int:
	return mini(_requested, multimesh.instance_count if multimesh != null else 0)

func set_world_activity(active: bool, count: int, eligible_indices: PackedInt32Array = PackedInt32Array()) -> void:
	_displayed_indices.clear()
	if multimesh == null:
		return
	var visible_count := clampi(count, 0, requested_count()) if active else 0
	if not eligible_indices.is_empty():
		visible_count = mini(visible_count, eligible_indices.size())
	for slot in range(visible_count):
		var index: int = eligible_indices[slot] if not eligible_indices.is_empty() else slot
		if index < 0 or index >= authored_instances.size():
			continue
		var data: Dictionary = authored_instances[index]
		# Only the allocator's 2 Hz activity refresh reorders this bounded prefix.
		# A nearby last anchor must not activate an unrelated far-away first slot.
		multimesh.set_instance_transform(slot, data.transform)
		multimesh.set_instance_color(slot, data.color)
		multimesh.set_instance_custom_data(slot, data.custom)
		_displayed_indices.append(index)
	multimesh.visible_instance_count = _displayed_indices.size()

func fingerprint() -> int:
	return _fingerprint

func get_swept_local_bounds() -> AABB:
	if local_anchors.is_empty():
		return AABB()
	var bounds := AABB(local_anchors[0] - SWEPT_MARGIN, SWEPT_MARGIN * 2.0)
	for point: Vector3 in local_anchors:
		bounds = bounds.merge(AABB(point - SWEPT_MARGIN, SWEPT_MARGIN * 2.0))
	return bounds

func snapshot() -> Dictionary:
	return {"allocated": multimesh.instance_count if multimesh != null else 0, "active": multimesh.visible_instance_count if multimesh != null else 0, "requested": requested_count(), "seed": cosmetic_seed, "swept_bounds": get_swept_local_bounds(), "displayed_indices": _displayed_indices.duplicate()}
