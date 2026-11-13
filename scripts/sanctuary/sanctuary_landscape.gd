class_name SanctuaryLandscape
extends Node3D
## Presentation-only gardens and a bounded native panorama. This node never
## creates physics/navigation objects or consumes the expedition's random stream.

const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
const VisualStyle = preload("res://scripts/visual/visual_style.gd")
const INTERIOR_LIMIT := 768
const INTERIOR_BATCH_LIMIT := 24
const PANORAMA_BATCH_LIMIT := 16
const PANORAMA_TRIANGLE_LIMIT := 24000
const PANORAMA_FORM_LIMIT := 24
const PANORAMA_CLEAR_RADIUS := 56.0
const PANORAMA_DISTANCE := 180.0
const TREE_COUNTS := [6, 9, 12] # Per octant: 48 / 72 / 96 trees in the whole city.
const INTERIOR_DENSITIES := [0.5, 0.75, 1.0]
const INTERIOR_DISTANCES := [24.0, 34.0, 44.0]
const INTERIOR_MOTION_MARGIN := 0.05
const BED_RADIUS := 31.0
const OCTANT_RADIUS := 81.0
const BLOSSOM_COLORS := [Color("ed82ae"), Color("71d8d2"), Color("edc56b"), Color("b99bea")]
const BLOSSOMS_PER_BED := 10
## Validation opt-in only. Bounds always use the upload inputs, but normal
## runtime discards static matrices after construction instead of retaining them.
var capture_geometry_for_validation := false

var _interior: Array[MultiMeshInstance3D] = []
var _trees: Array[MultiMeshInstance3D] = []
var _panorama: Array[GeometryInstance3D] = []
var _panorama_bounds: Array[AABB] = []
var _interior_capacity := 0
var _interior_triangle_capacity := 0
var _authored_transform_count := 0
var _retained_transform_count := 0
var _backdrop_triangles := 0
var _tree_triangles := 0
var _backdrop_instances := 0
var _panorama_form_count := 0
var _water_reaches := 0
var _quality := 1
var _minimum_panorama_radius := INF

func build(root: Node3D, _layout: Resource, capture_inputs: bool = false) -> Node3D:
	capture_geometry_for_validation = capture_inputs
	name = "SanctuaryLandscape"
	root.add_child(self)
	_construct()
	var settings := root.get_node_or_null("/root/VisualSettings")
	if settings != null and settings.has_method("snapshot"):
		apply_visual_settings(settings.snapshot())
	else:
		apply_visual_settings({"quality": 1})
	return self

func _construct() -> void:
	add_to_group("visual_quality")
	var palette := VisualStyle.palette()
	_build_gardens(palette)
	_build_panorama(palette)
	assert(_interior_capacity <= INTERIOR_LIMIT, "City garden instance budget exceeded")
	assert(_authored_transform_count <= INTERIOR_LIMIT + 96, "City retained transform budget exceeded")
	assert(_interior.size() <= INTERIOR_BATCH_LIMIT, "City garden batch budget exceeded")
	assert(_panorama.size() <= PANORAMA_BATCH_LIMIT, "City panorama batch budget exceeded")
	assert(_panorama_form_count <= PANORAMA_FORM_LIMIT, "City panorama form budget exceeded")
	assert(_tree_triangles * 96 + _backdrop_triangles <= PANORAMA_TRIANGLE_LIMIT, "City panorama triangle budget exceeded")
	assert(_minimum_panorama_radius >= PANORAMA_CLEAR_RADIUS, "Panorama bounds intrude into the protected city")

func _build_gardens(palette: Dictionary) -> void:
	# These materials belong to this city. Increasing garden colour never mutates
	# the shared foliage resources used by dungeons or the personal home.
	var garden_palette := palette.duplicate()
	for key: String in ["leaf", "leaf_light"]:
		var foliage := (palette[key] as ShaderMaterial).duplicate() as ShaderMaterial
		foliage.set_shader_parameter("leaf_color", Color("347d58") if key == "leaf" else Color("73b86b"))
		garden_palette[key] = foliage
	var flower_material := StandardMaterial3D.new()
	flower_material.albedo_color = Color.WHITE
	flower_material.vertex_color_use_as_albedo = true
	flower_material.roughness = 0.85
	garden_palette["flower"] = flower_material
	var bloom_meshes: Array[ArrayMesh] = []
	for tint: Color in BLOSSOM_COLORS:
		bloom_meshes.append(_bloom_mesh(tint))
	# Staggered rows give the larger petals separate surfaces rather than laying
	# overlapping, coplanar flower faces over one another.
	var bloom_positions: Array[Vector2] = [
		Vector2(-1.02, -0.60), Vector2(-0.34, -0.60), Vector2(0.34, -0.60), Vector2(1.02, -0.60),
		Vector2(-0.68, 0), Vector2(0, 0), Vector2(0.68, 0),
		Vector2(-0.68, 0.60), Vector2(0, 0.60), Vector2(0.68, 0.60)]
	for index in range(8):
		var angle := (float(index) + 0.5) * TAU / 8.0
		var bed := Node3D.new()
		bed.name = "WedgeGarden_%d" % index
		bed.position = Vector3(sin(angle), 0.035, -cos(angle)) * Vector3(BED_RADIUS, 1.0, BED_RADIUS)
		bed.rotation.y = -angle
		add_child(bed)
		var art := Dressing.new(bed, garden_palette)
		art._meshes["bloom"] = bloom_meshes[index % bloom_meshes.size()]
		# Five ferns and ten complete blossoms: 50 instances in the same three
		# batches. All geometry remains in the existing between-road R31 pockets.
		for point: Vector2 in [Vector2(-0.6, 0), Vector2(0.6, 0), Vector2.ZERO, Vector2(-0.3, -0.18), Vector2(0.3, 0.18)]:
			art.fern(Vector3(point.x, 0.035, point.y), 0.44, float(index) + point.x)
		for bloom_index in range(bloom_positions.size()):
			var point: Vector2 = bloom_positions[bloom_index]
			var scale_factor := 0.88 + float((bloom_index + index) % 4) * 0.06
			var basis := Basis(Vector3.UP, float(bloom_index) * 0.73 + float(index)) * Basis.from_scale(Vector3.ONE * scale_factor)
			art._add("bloom", "flower", Transform3D(basis, Vector3(point.x, 0.01, point.y)), true)
		var label := "WedgeGarden_%d" % index
		var authored_batches: Dictionary = {}
		# Retain the arrays themselves: flush shuffles their contents before passing
		# the transforms to MultiMesh. A copy here would preserve the wrong prefix.
		for key: String in art._batches:
			authored_batches[label + "_" + key.replace(":", "_")] = art._batches[key].transforms
		art.flush(label)
		for child: Node in bed.get_children():
			if not child is MultiMeshInstance3D:
				continue
			var batch := child as MultiMeshInstance3D
			var authored_transforms: Array = authored_batches[String(batch.name)]
			assert(authored_transforms.size() == batch.multimesh.instance_count, "Garden authored transform count mismatch")
			if capture_geometry_for_validation:
				batch.set_meta("authored_instance_transforms", authored_transforms)
				_retained_transform_count += authored_transforms.size()
			# This holder and the shared Dressing receiver use the same quality policy.
			batch.set("density_scaled", true)
			batch.add_to_group("city_scenery_interior")
			batch.set_meta("scenery_sector", index)
			batch.set_meta("scenery_sector_angle", angle)
			batch.set_meta("scenery_motion_margin", INTERIOR_MOTION_MARGIN)
			if String(batch.name).ends_with("_bloom_flower"):
				batch.add_to_group("city_garden_blossoms")
				batch.set_meta("blossom_color_family", index % BLOSSOM_COLORS.size())
			batch.multimesh.custom_aabb = _instance_bounds(batch.multimesh.mesh, authored_transforms).grow(INTERIOR_MOTION_MARGIN)
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_interior.append(batch)
			_interior_capacity += authored_transforms.size()
			_interior_triangle_capacity += int(batch.multimesh.mesh.get_faces().size() / 3) * authored_transforms.size()
			_authored_transform_count += authored_transforms.size()

func _build_panorama(palette: Dictionary) -> void:
	# Both silhouettes retain the exact sixty-triangle per-tree allocation.
	var tree_meshes: Array[ArrayMesh] = [_tree_mesh(false), _tree_mesh(true)]
	_tree_triangles = tree_meshes[0].surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3
	assert(tree_meshes[1].get_faces().size() == tree_meshes[0].get_faces().size(), "Panorama variations must retain the same triangle budget")
	var colored_stone := (palette.moss as StandardMaterial3D).duplicate() as StandardMaterial3D
	colored_stone.albedo_color = Color.WHITE
	colored_stone.albedo_texture = null
	colored_stone.vertex_color_use_as_albedo = true
	colored_stone.roughness = 0.96
	for index in range(8):
		var tree_mesh: ArrayMesh = tree_meshes[index % tree_meshes.size()]
		var angle := float(index) * TAU / 8.0
		var chunk := Node3D.new()
		chunk.name = "PanoramaOctant_%d" % index
		chunk.position = Vector3(sin(angle), 0, -cos(angle)) * OCTANT_RADIUS
		chunk.rotation.y = -angle
		add_child(chunk)
		var forest := MultiMeshInstance3D.new()
		forest.name = "LayeredForest"
		forest.material_override = colored_stone
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = tree_mesh
		multi.instance_count = 12
		var authored_transforms: Array[Transform3D] = []
		# Prefixes alternate near/far and left/right, retaining depth on Low.
		var offsets := [-5.5, 5.5, -3.3, 3.3, -1.1, 1.1]
		for tree_index in range(12):
			var offset: float = deg_to_rad(float(offsets[tree_index % 6]))
			var radius := 77.0 + float(tree_index % 3) * 4.0 + float(tree_index / 6)
			var scale_factor := 0.86 + float((tree_index * 5 + index * 3) % 7) * 0.045
			var at := Vector3(sin(offset) * radius, -1.7 - float(tree_index % 3) * 0.35, OCTANT_RADIUS - cos(offset) * radius)
			var basis := Basis(Vector3.UP, float(tree_index) * 1.7 + float(index)) * Basis.from_scale(Vector3.ONE * scale_factor)
			var transform := Transform3D(basis, at)
			authored_transforms.append(transform)
			multi.set_instance_transform(tree_index, transform)
		forest.multimesh = multi
		if capture_geometry_for_validation:
			forest.set_meta("authored_instance_transforms", authored_transforms)
			_retained_transform_count += authored_transforms.size()
		_authored_transform_count += authored_transforms.size()
		multi.custom_aabb = _instance_bounds(tree_mesh, authored_transforms)
		chunk.add_child(forest)
		_register_panorama(forest, multi.custom_aabb, index, &"forest", 12)
		_trees.append(forest)
		var backdrop := MeshInstance3D.new()
		if index % 2 == 0:
			backdrop.name = "AncientCliffsAndWatchtower"
			backdrop.mesh = _cliff_mesh(index)
			backdrop.material_override = colored_stone
		else:
			backdrop.name = "DistantWaterReach"
			backdrop.mesh = _water_mesh()
			backdrop.material_override = palette.water
		chunk.add_child(backdrop)
		_backdrop_triangles += backdrop.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3
		_register_panorama(backdrop, backdrop.mesh.get_aabb(), index, &"cliff_ruin" if index % 2 == 0 else &"water", 3 if index % 2 == 0 else 1)

func _register_panorama(node: GeometryInstance3D, bounds: AABB, octant: int, kind: StringName, count: int) -> void:
	if kind != &"forest":
		_backdrop_instances += count
	if kind == &"cliff_ruin":
		_panorama_form_count += count
	elif kind == &"water":
		_water_reaches += count
	node.add_to_group("city_scenery_panorama")
	node.set_meta("scenery_octant", octant)
	node.set_meta("scenery_kind", kind)
	node.set_meta("scenery_instances", count)
	node.set_meta("scenery_authored_aabb", bounds)
	node.set_meta("scenery_motion_margin", 0.0) # These meshes have no vertex motion.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = PANORAMA_DISTANCE
	node.visibility_range_end_margin = 12.0
	_panorama.append(node)
	var world_bounds: AABB = node.global_transform * bounds
	_panorama_bounds.append(world_bounds)
	_minimum_panorama_radius = minf(_minimum_panorama_radius, _aabb_radius(world_bounds))

func apply_visual_settings(settings: Dictionary) -> void:
	_quality = clampi(int(settings.get("quality", 1)), 0, 2)
	for batch: MultiMeshInstance3D in _interior:
		batch.multimesh.visible_instance_count = ceili(float(batch.multimesh.instance_count) * float(INTERIOR_DENSITIES[_quality]))
		batch.visibility_range_end = INTERIOR_DISTANCES[_quality]
		batch.visibility_range_end_margin = 3.0
	for forest: MultiMeshInstance3D in _trees:
		forest.multimesh.visible_instance_count = TREE_COUNTS[_quality]
	# Panorama is an enclosing horizon, not a nearby flower detail. Its visibility
	# range must never inherit the 24/34/44 metre garden cutoff.
	for backdrop: GeometryInstance3D in _panorama:
		backdrop.visibility_range_end = PANORAMA_DISTANCE

func get_scenery_snapshot() -> Dictionary:
	var interior_instances := 0
	for batch: MultiMeshInstance3D in _interior:
		interior_instances += batch.multimesh.visible_instance_count if batch.multimesh.visible_instance_count >= 0 else batch.multimesh.instance_count
	var tree_instances := _trees.size() * int(TREE_COUNTS[_quality])
	return {"quality": _quality, "interior_instances": interior_instances, "interior_capacity": _interior_capacity,
		"interior_triangle_capacity": _interior_triangle_capacity, "garden_blossoms": BLOSSOMS_PER_BED * 8, "blossom_color_families": BLOSSOM_COLORS.size(), "panorama_tree_variants": 2,
		"authored_transform_count": _authored_transform_count,
		"retained_transform_count": _retained_transform_count,
		"interior_batches": _interior.size(), "interior_batch_limit": INTERIOR_BATCH_LIMIT, "interior_distance": INTERIOR_DISTANCES[_quality],
		"panorama_instances": tree_instances + _backdrop_instances, "panorama_tree_instances": tree_instances, "panorama_tree_capacity": 96,
		"panorama_forms": _panorama_form_count, "panorama_form_limit": PANORAMA_FORM_LIMIT, "water_reaches": _water_reaches,
		"panorama_batches": _panorama.size(), "panorama_triangles": tree_instances * _tree_triangles + _backdrop_triangles,
		"panorama_triangle_capacity": 96 * _tree_triangles + _backdrop_triangles,
		"panorama_minimum_radius": _minimum_panorama_radius, "panorama_distance": PANORAMA_DISTANCE,
		"panorama_bounds": _panorama_bounds.duplicate(), "collision_nodes": 0, "navigation_nodes": 0}

func _instance_bounds(mesh: Mesh, authored_transforms: Array) -> AABB:
	# Headless Dummy rendering does not retain MultiMesh getter data. Bounds and
	# acceptance checks therefore use exactly the same inputs as each setter.
	var result := AABB()
	for index in range(authored_transforms.size()):
		var bounds: AABB = authored_transforms[index] * mesh.get_aabb()
		result = bounds if index == 0 else result.merge(bounds)
	return result

func _aabb_radius(bounds: AABB) -> float:
	var x := clampf(0.0, bounds.position.x, bounds.end.x)
	var z := clampf(0.0, bounds.position.z, bounds.end.z)
	return Vector2(x, z).length()

func _bloom_mesh(tint: Color) -> ArrayMesh:
	# One original six-petal bloom replaces five separate tiny leaf instances.
	# A faceted gold centre and green stem share the same vertex-colour surface.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_prism(surface, Vector3.ZERO, 0.015, 0.011, 0.19, Color("3d885a"), 3)
	for index in range(6):
		var angle := float(index) * TAU / 6.0
		var radial := Vector3(sin(angle), 0, cos(angle))
		var tangent := Vector3(cos(angle), 0, -sin(angle))
		var inner := radial * 0.035 + Vector3.UP * 0.17
		var left := radial * 0.14 - tangent * 0.075 + Vector3.UP * 0.225
		var tip := radial * 0.30 + Vector3.UP * 0.205
		var right := radial * 0.14 + tangent * 0.075 + Vector3.UP * 0.225
		_triangle(surface, inner, left, tip, tint.lightened(0.045 * float(index % 3)))
		_triangle(surface, inner, tip, right, tint)
		var next := float(index + 1) * TAU / 6.0
		var a := radial * 0.065 + Vector3.UP * 0.19
		var b := Vector3(sin(next) * 0.065, 0.19, cos(next) * 0.065)
		_triangle(surface, Vector3(0, 0.235, 0), a, b, Color("e7bc59"))
	return surface.commit()

func _tree_mesh(broad_canopy: bool = false) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_prism(surface, Vector3.ZERO, 0.25, 0.13, 9.2, Color("67513f"), 6)
	if broad_canopy:
		# Flatten the crowns inside the established tree footprint. Variation may
		# change the silhouette, never extend the panorama toward playable space.
		_prism(surface, Vector3(0, 3.0, 0), 2.7, 0.0, 2.7, Color("286a50"), 6, 0.0)
		_prism(surface, Vector3(0.12, 5.4, 0.08), 2.15, 0.0, 2.5, Color("468b62"), 6, PI / 6.0)
		_prism(surface, Vector3(-0.08, 7.6, -0.05), 1.5, 0.0, 2.5, Color("79ab72"), 6, PI / 12.0)
	else:
		_prism(surface, Vector3(0, 3.0, 0), 2.7, 0.0, 5.5, Color("255b49"), 6, 0.0)
		_prism(surface, Vector3(0.12, 5.6, 0.08), 2.15, 0.0, 5.3, Color("3c7e5d"), 6, PI / 6.0)
		_prism(surface, Vector3(-0.08, 8.1, -0.05), 1.5, 0.0, 5.1, Color("6aa278"), 6, PI / 12.0)
	return surface.commit()

func _cliff_mesh(index: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_prism(surface, Vector3(-4.2, -4.0, -1.5), 5.1, 3.1, 12.2 + float(index % 3), Color("536463"), 5, 0.3)
	_prism(surface, Vector3(4.9, -4.0, 0.8), 4.7, 2.2, 8.7, Color("6a7770"), 5, -0.4)
	# One broken watchtower per cliff group; its masonry is baked into one surface.
	_box(surface, Vector3(0.2, 8.5, -2.7), Vector3(3.1, 1.0, 3.1), Color("89938a"))
	for side in [-1.0, 1.0]:
		_box(surface, Vector3(0.2 + side * 1.0, 11.0, -3.5), Vector3(0.65, 4.3 - side * 0.8, 0.65), Color("a1a99b"))
		_box(surface, Vector3(0.2 + side * 1.0, 10.2, -1.8), Vector3(0.65, 2.8, 0.65), Color("89938a"))
	_box(surface, Vector3(0.2, 12.3, -3.5), Vector3(2.6, 0.45, 0.85), Color("a1a99b"))
	return surface.commit()

func _water_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector3(-14, -2.8, -7), Vector3(14, -2.8, -7), Vector3(14, -2.8, 7), Vector3(-14, -2.8, 7)]
	var uv := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_normal(Vector3.UP)
		surface.set_color(Color.WHITE)
		surface.set_uv(uv[index])
		surface.add_vertex(corners[index])
	return surface.commit()

func _prism(surface: SurfaceTool, at: Vector3, bottom: float, top: float, height: float, color: Color, sides: int, yaw: float = 0.0) -> void:
	for index in range(sides):
		var angle := yaw + float(index) * TAU / float(sides)
		var next := yaw + float(index + 1) * TAU / float(sides)
		var a := at + Vector3(sin(angle) * bottom, 0, cos(angle) * bottom)
		var b := at + Vector3(sin(next) * bottom, 0, cos(next) * bottom)
		var c := at + Vector3(sin(next) * top, height, cos(next) * top)
		var d := at + Vector3(sin(angle) * top, height, cos(angle) * top)
		var shade := color.lightened(0.04 * float(index % 3))
		_triangle(surface, a, b, c, shade)
		if top > 0.0:
			_triangle(surface, a, c, d, shade)
			_triangle(surface, at + Vector3.UP * height, d, c, color.lightened(0.12))
		_triangle(surface, at, b, a, color.darkened(0.14))

func _box(surface: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		surface.set_normal(normals[index])
		surface.set_color(color)
		surface.set_uv(Vector2.ZERO)
		surface.add_vertex(vertices[index] + center)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for vertex: Vector3 in [a, c, b]:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.set_uv(Vector2.ZERO)
		surface.add_vertex(vertex)
