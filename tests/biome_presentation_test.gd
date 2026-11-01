extends "res://tests/test_harness.gd"
const RootboundTheme = preload("res://resources/biomes/rootbound_abyss.tres")
const Definition = preload("res://scripts/expedition/biome_definition.gd")
const Presentation = preload("res://scripts/visual/dungeon_presentation.gd")
const ArtDirections = preload("res://scripts/visual/biome_art_directions.gd")
var stage: Node3D

func _initialize() -> void:
	suite_name = "VAULTBOUND BIOME PRESENTATION"
	_run.call_deferred()

func _run() -> void:
	var definition: Resource = RootboundTheme
	var issued: Dictionary = definition.snapshot()
	check(not issued.is_empty() and Definition.valid_snapshot(issued), "Existing Rootbound resolves an executable detached presentation")
	if issued.is_empty():
		finish()
		return
	var shown: Dictionary = issued.presentation
	check(_plain(issued), "Theme contains no Resource, Node, RID, Callable or runtime object")
	check(shown.modules.size() == 14 and shown.material_roles.size() == 18, "Every existing module and native material role is covered")
	for reference: Resource in ArtDirections.DEFINITIONS:
		if String(reference.id) != "rootbound_abyss":
			check(reference.availability == "unavailable", "Presentation registration does not enable art-only theme: " + String(reference.id))
	var copy := issued.duplicate(true)
	copy.presentation.modules.entrance_grove.motif = "not_a_motif"
	check(not Definition.valid_snapshot(copy) and definition.snapshot() == issued, "Unknown motif rejects without changing the source or earlier issued plan")
	for key: String in Definition.SNAPSHOT_KEYS:
		copy = issued.duplicate(true)
		copy.erase(key)
		check(not Definition.valid_snapshot(copy), "Theme cannot omit " + key)
	for key: String in Presentation.SNAPSHOT_KEYS:
		copy = shown.duplicate(true)
		copy.erase(key)
		check(not Presentation.valid_snapshot(copy), "Presentation cannot omit " + key)
	for path: String in ["res://scenes/world/sanctuary.tscn", "user://injected.tres", "res://resources/materials/abyss_gold.tres"]:
		copy = shown.duplicate(true)
		copy.material_roles.soil.path = path
		check(not Presentation.valid_snapshot(copy), "Unapproved material-role substitution rejects: " + path)
	copy = shown.duplicate(true)
	copy.material_roles.water.shader = "res://scripts/systems/game.gd"
	check(not Presentation.valid_snapshot(copy), "Issued values cannot select arbitrary shaders or scripts")
	copy = shown.duplicate(true)
	copy.material_roles.soil.values.unknown_option = 1
	check(not Presentation.valid_snapshot(copy), "Unknown material tuning rejects")
	for invalid: float in [NAN, INF, -1.0, 5.0]:
		copy = shown.duplicate(true)
		copy.material_roles.soil.values.roughness = invalid
		check(not Presentation.valid_snapshot(copy), "Nonfinite or excessive material tuning rejects")
	copy = shown.duplicate(true)
	copy.material_roles.foliage.parameters.sway = 0.1
	check(not Presentation.valid_snapshot(copy), "Issued foliage cannot exceed the measured sway envelope")
	copy = shown.duplicate(true)
	copy.material_roles.soil.texture.width = 4096
	check(not Presentation.valid_snapshot(copy), "Texture reconstruction cannot exceed the native128px budget")
	copy = shown.duplicate(true)
	copy.budgets.dressing_instances = 513
	check(not Presentation.valid_snapshot(copy), "A presentation cannot bypass native instance limits")
	copy = shown.duplicate(true)
	copy.modules.erase("trap_thorns")
	check(not Presentation.valid_snapshot(copy), "Missing trap role rejects instead of silently using unthemed content")
	var materials: Dictionary = Presentation.build_materials(shown)
	var environment: Environment = Presentation.build_environment(shown)
	check(materials.size() == 18 and environment != null, "One native material/environment set reconstructs from the issued data")
	check(Presentation._properties(environment, Presentation.ENV_FIELDS) == shown.environment, "Reconstructed environment retains all supported numeric/color settings")
	for role: String in Presentation.ROLE_PATHS:
		var source := load(Presentation.ROLE_PATHS[role]) as Material
		var actual: Material = materials[role]
		check(actual != source, "Level owns a detached material: " + role)
		check(_material_values(actual, role) == _material_values(source, role), "Native appearance is unchanged for material role: " + role)
	check(materials.soil.albedo_texture == materials.paving.albedo_texture and materials.root_shell.albedo_texture == materials.root_detail.albedo_texture, "Only two reconstructed native texture families are shared across all materials")
	_mutation_checks(definition, issued)
	stage = Node3D.new()
	root.add_child(stage)
	for id: String in Presentation.MODULES:
		var spec: Dictionary = Presentation.MODULES[id]
		var scene := load(spec.scene) as PackedScene
		var native := scene.instantiate() as AbyssRoom
		var content := scene.instantiate() as AbyssRoom
		native.configure_visuals(8341, 3, true)
		content.configure_visuals(8341, 3, true)
		var before := _geometry(content)
		check(content.configure_presentation(shown, materials), "Pre-tree frozen presentation applies to module: " + id)
		check(_geometry(content) == before, "Presentation leaves authored mesh/collision/transforms intact: " + id)
		var slots_match := true
		for slot: String in spec.native_slots:
			var prop := content.get_node_or_null(slot)
			slots_match = slots_match and prop != null and prop.scene_file_path == "res://scenes/props/abyss_%s.tscn" % spec.native_slots[slot]
		check(slots_match and String(content.visual_motif) == spec.motif, "Actual scene retains every registered native prop slot and motif: " + id)
		seed(98102)
		var random_expected := randi()
		seed(98102)
		stage.add_child(native)
		stage.add_child(content)
		check(randi() == random_expected, "Native presentation does not advance gameplay RNG: " + id)
		check(_geometry(content) == _geometry(native) and content.dressing.fingerprint() == native.dressing.fingerprint(), "Content and legacy rooms have identical actual geometry and deterministic dressing: " + id)
		check(_all_materials_resolved(content, materials), "Native and generated material batches use the frozen shared set: " + id)
		check(not content.configure_presentation(shown, materials), "Room presentation cannot be changed after activation: " + id)
		native.free()
		content.free()
	stage.queue_free()
	await frames(3)
	check(definition.snapshot() == issued, "All source tuning is restored after mutation and runtime tests")
	finish()

func _mutation_checks(definition: Resource, issued: Dictionary) -> void:
	var soil := load(Presentation.ROLE_PATHS.soil) as StandardMaterial3D
	var foliage := load(Presentation.ROLE_PATHS.foliage) as ShaderMaterial
	var environment := load(Presentation.ENVIRONMENT_PATH) as Environment
	var original_color := soil.albedo_color
	var original_sway: Variant = foliage.get_shader_parameter("sway")
	var original_fog := environment.fog_depth_end
	var original_available: bool = definition.available
	soil.albedo_color = Color(0.9, 0.1, 0.1, 1)
	foliage.set_shader_parameter("sway", 0.02)
	environment.fog_depth_end = 48.0
	definition.available = false
	check(definition.snapshot().is_empty(), "Disabling current catalog blocks new resolution")
	check(Definition.valid_snapshot(issued), "Issued presentation remains valid after mutable source edits or availability changes")
	var material_set: Dictionary = Presentation.build_materials(issued.presentation)
	var rebuilt: Environment = Presentation.build_environment(issued.presentation)
	check(material_set.soil.albedo_color == original_color and material_set.foliage.get_shader_parameter("sway") == original_sway and rebuilt.fog_depth_end == original_fog, "Issued material and environment tuning survive Resource edits")
	soil.albedo_color = original_color
	foliage.set_shader_parameter("sway", original_sway)
	environment.fog_depth_end = original_fog
	definition.available = original_available

func _plain(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _plain(value[key]): return false
		return true
	if value is Array:
		for item: Variant in value:
			if not _plain(item): return false
		return true
	return value is String or value is bool or value is int or (value is float and is_finite(value))

func _material_values(material: Material, role: String) -> Dictionary:
	if material is StandardMaterial3D:
		return {"values": Presentation._properties(material, Presentation.STANDARD_FIELDS), "texture": _texture_values(material.albedo_texture)}
	var shader_material := material as ShaderMaterial
	var defaults: Dictionary = Presentation.FOLIAGE_DEFAULTS if role == "foliage" else {} if role == "foam" else Presentation.WATER_DEFAULTS
	var values: Dictionary = {}
	for key: String in defaults:
		var value: Variant = shader_material.get_shader_parameter(key)
		if value == null:
			value = defaults[key]
			if value is Array:
				# Shader source_color defaults are native Color values too. Compare
				# their exact representation rather than double fallback literals.
				value = Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
		values[key] = Presentation._plain(value)
	return {"shader": shader_material.shader.resource_path, "parameters": values}

func _texture_values(texture: Texture2D) -> Dictionary:
	if texture == null: return {}
	var grain := texture as NoiseTexture2D
	return {"noise": Presentation._properties(grain.noise, Presentation.NOISE_FIELDS), "colors": grain.color_ramp.colors,
		"offsets": grain.color_ramp.offsets, "width": grain.width, "height": grain.height, "seamless": grain.seamless,
		"normalize": grain.normalize, "invert": grain.invert, "seamless_blend_skirt": grain.seamless_blend_skirt}

func _geometry(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D:
		result.append([node.name, node.transform, node.mesh.get_faces()])
	elif node is MultiMeshInstance3D:
		result.append([node.name, node.transform, node.multimesh.mesh.get_faces(), node.multimesh.buffer])
	elif node is CollisionShape3D:
		result.append([node.name, node.transform, node.shape.get_debug_mesh().get_faces()])
	elif node is CollisionObject3D:
		result.append([node.name, node.transform, node.collision_layer, node.collision_mask])
	for child: Node in node.get_children(): result.append_array(_geometry(child))
	return result

func _all_materials_resolved(node: Node, materials: Dictionary) -> bool:
	if node is GeometryInstance3D and node.material_override != null:
		var material: Material = node.material_override
		if material.resource_path in Presentation.ROLE_PATHS.values(): return false
		# Fauna/motes use their independent shared visual families.
		if node.get_parent() != null and node.get_parent().name == "EnchantedDressing" and material not in materials.values(): return false
	for child: Node in node.get_children():
		if not _all_materials_resolved(child, materials): return false
	return true
