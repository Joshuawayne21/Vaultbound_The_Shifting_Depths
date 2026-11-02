class_name VaultDungeonPresentation
extends Resource
## Closed native presentation profile. Issued DTOs contain detached numeric data;
## reconstruction never rereads mutable material/environment tuning resources.
const Catalog = preload("res://scripts/visual/dungeon_presentation_catalog.gd")
const PROFILE_ID := "rootbound_native_v1"
const ROLE_PATHS := Catalog.ROLE_PATHS
const MODULES := Catalog.MODULES
const DRESSING_ROLES := Catalog.DRESSING_ROLES
const BUDGETS := Catalog.BUDGETS
const ENVIRONMENT_PATH := "res://resources/environments/abyss.tres"
const TEXTURE_PATHS := ["res://resources/textures/stone_grain.tres", "res://resources/textures/bark_grain.tres"]
const SHADER_PATHS := {"foliage": "res://resources/shaders/living_foliage.gdshader", "water": "res://resources/shaders/living_water.gdshader", "falling_water": "res://resources/shaders/living_water.gdshader", "foam": "res://resources/shaders/soft_foam.gdshader"}
const STANDARD_FIELDS := ["albedo_color", "roughness", "metallic", "emission_enabled", "emission", "emission_energy_multiplier", "uv1_scale"]
const ENV_FIELDS := ["background_mode", "background_color", "ambient_light_source", "ambient_light_color", "ambient_light_energy", "reflected_light_source", "tonemap_mode", "fog_enabled", "fog_mode", "fog_light_color", "fog_light_energy", "fog_depth_begin", "fog_depth_end", "fog_depth_curve", "fog_sky_affect"]
const NOISE_FIELDS := ["noise_type", "seed", "frequency", "fractal_type", "fractal_octaves", "fractal_lacunarity", "fractal_gain", "fractal_weighted_strength", "fractal_ping_pong_strength", "cellular_distance_function", "cellular_return_type", "cellular_jitter", "offset"]
const FOLIAGE_DEFAULTS := {"leaf_color": [0.12, 0.37, 0.25, 1.0], "sway": 0.035}
const WATER_DEFAULTS := {"deep_color": [0.025, 0.17, 0.19, 1.0], "shallow_color": [0.08, 0.42, 0.40, 1.0], "foam_color": [0.54, 0.82, 0.72, 1.0], "flow_speed": 0.28, "ripple_scale": 18.0, "bank_width": 0.18, "falling": 0.0}
const SNAPSHOT_KEYS := ["id", "version", "material_roles", "environment", "modules", "dressing", "budgets"]

@export var id := PROFILE_ID
@export var version := 1
@export var material_roles: Dictionary = {}
@export var environment: Environment
@export var modules: Dictionary = {}

func snapshot() -> Dictionary:
	var metadata: Dictionary = Catalog.profile(id)
	if metadata.is_empty() or version != 1 or not _keys(material_roles, metadata.roles.keys()) or modules != metadata.modules or environment == null or environment.resource_path != metadata.environment:
		return {}
	var frozen: Dictionary = {}
	for role: String in ROLE_PATHS:
		var material: Variant = material_roles[role]
		if not material is Material or material.resource_path != metadata.roles[role]:
			return {}
		var entry := _snapshot_material(material, role, metadata.roles)
		if entry.is_empty():
			return {}
		frozen[role] = entry
	var result := {"id": id, "version": version, "material_roles": frozen,
		"environment": _properties(environment, ENV_FIELDS), "modules": modules.duplicate(true),
		"dressing": DRESSING_ROLES.duplicate(true), "budgets": BUDGETS.duplicate(true)}
	return result if valid_snapshot(result) else {}

static func valid_snapshot(value: Variant) -> bool:
	if not _keys(value, SNAPSHOT_KEYS) or not value.id is String or not _integer(value.version, 1, 1):
		return false
	var metadata: Dictionary = Catalog.profile(value.id)
	if metadata.is_empty(): return false
	if value.modules != metadata.modules or value.dressing != DRESSING_ROLES or value.budgets != BUDGETS or not _keys(value.material_roles, ROLE_PATHS.keys()):
		return false
	if not _valid_environment(value.environment):
		return false
	for role: String in ROLE_PATHS:
		if not _valid_material(value.material_roles[role], role, metadata.roles):
			return false
	return true

static func _snapshot_material(material: Material, role: String, paths: Dictionary = ROLE_PATHS) -> Dictionary:
	if SHADER_PATHS.has(role):
		if not material is ShaderMaterial or material.shader == null or material.shader.resource_path != SHADER_PATHS[role]:
			return {}
		var shader_material := material as ShaderMaterial
		var defaults: Dictionary = FOLIAGE_DEFAULTS if role == "foliage" else {} if role == "foam" else WATER_DEFAULTS
		var parameters: Dictionary = {}
		for key: String in defaults:
			var current: Variant = shader_material.get_shader_parameter(key)
			var resolved: Variant = current if current != null else defaults[key]
			# Omitted source_color uniforms have the same native Color channel
			# representation as explicit material colors, not double Array values.
			if resolved is Array: resolved = _as_color(resolved)
			parameters[key] = _plain(resolved)
		return {"path": paths[role], "kind": "shader", "shader": SHADER_PATHS[role], "parameters": parameters}
	if not material is StandardMaterial3D:
		return {}
	var standard := material as StandardMaterial3D
	var texture := _snapshot_texture(standard.albedo_texture)
	if standard.albedo_texture != null and texture.is_empty():
		return {}
	return {"path": paths[role], "kind": "standard", "values": _properties(standard, STANDARD_FIELDS), "texture": texture}

static func _snapshot_texture(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}
	if not texture is NoiseTexture2D or texture.resource_path not in TEXTURE_PATHS:
		return {}
	var grain := texture as NoiseTexture2D
	var noise := grain.noise as FastNoiseLite
	if noise == null or grain.color_ramp == null or grain.color_ramp.get_point_count() != 2 or noise.domain_warp_enabled:
		return {}
	var colors: Array = []
	var offsets: Array = []
	for index in range(2):
		colors.append(_plain(grain.color_ramp.get_color(index)))
		offsets.append(grain.color_ramp.get_offset(index))
	return {"path": texture.resource_path, "width": grain.width, "height": grain.height, "seamless": grain.seamless,
		"normalize": grain.normalize, "invert": grain.invert, "seamless_blend_skirt": grain.seamless_blend_skirt,
		"noise": _properties(grain.noise, NOISE_FIELDS), "colors": colors, "offsets": offsets,
		"interpolation_mode": grain.color_ramp.interpolation_mode, "interpolation_color_space": grain.color_ramp.interpolation_color_space}

static func _valid_material(value: Variant, role: String, paths: Dictionary = ROLE_PATHS) -> bool:
	if SHADER_PATHS.has(role):
		if not _keys(value, ["path", "kind", "shader", "parameters"]) or value.path != paths[role] or value.kind != "shader" or value.shader != SHADER_PATHS[role]:
			return false
		var defaults: Dictionary = FOLIAGE_DEFAULTS if role == "foliage" else {} if role == "foam" else WATER_DEFAULTS
		if not _keys(value.parameters, defaults.keys()):
			return false
		for key: String in defaults:
			var parameter: Variant = value.parameters[key]
			if defaults[key] is Array:
				if not _color(parameter): return false
			elif key == "sway":
				if not _number(parameter, 0.0, 0.035): return false
			elif key == "ripple_scale":
				if not _number(parameter, 1.0, 40.0): return false
			elif key == "bank_width":
				if not _number(parameter, 0.0, 0.5): return false
			elif key == "falling":
				if not _number(parameter, 0.0, 1.0): return false
			elif not _number(parameter, 0.0, 2.0):
				return false
		return true
	if not _keys(value, ["path", "kind", "values", "texture"]) or value.path != paths[role] or value.kind != "standard" or not _keys(value.values, STANDARD_FIELDS):
		return false
	var tuning: Dictionary = value.values
	if not _color(tuning.albedo_color) or not _color(tuning.emission) or not tuning.emission_enabled is bool or not _vector(tuning.uv1_scale, 0.01, 8.0):
		return false
	if not _number(tuning.roughness, 0, 1) or not _number(tuning.metallic, 0, 1) or not _number(tuning.emission_energy_multiplier, 0, 1):
		return false
	return _valid_texture(value.texture)

static func _valid_texture(value: Variant) -> bool:
	if value is Dictionary and value.is_empty(): return true
	if not _keys(value, ["path", "width", "height", "seamless", "normalize", "invert", "seamless_blend_skirt", "noise", "colors", "offsets", "interpolation_mode", "interpolation_color_space"]): return false
	if value.path not in TEXTURE_PATHS or not _integer(value.width, 128, 128) or not _integer(value.height, 128, 128): return false
	if not value.seamless is bool or not value.normalize is bool or not value.invert is bool or not _number(value.seamless_blend_skirt, 0, 1): return false
	if not _keys(value.noise, NOISE_FIELDS) or not value.colors is Array or value.colors.size() != 2 or not _color(value.colors[0]) or not _color(value.colors[1]): return false
	if value.offsets != [0.0, 1.0] or not _integer(value.interpolation_mode, 0, 2) or not _integer(value.interpolation_color_space, 0, 2): return false
	var noise: Dictionary = value.noise
	if not _integer(noise.noise_type, 0, 5) or not _integer(noise.seed, -2147483648, 2147483647) or not _number(noise.frequency, 0.001, 1): return false
	if not _integer(noise.fractal_type, 0, 3) or not _integer(noise.fractal_octaves, 1, 4) or not _integer(noise.cellular_distance_function, 0, 3) or not _integer(noise.cellular_return_type, 0, 6): return false
	if not _vector(noise.offset, -1000, 1000): return false
	for key: String in ["fractal_lacunarity", "fractal_gain", "fractal_weighted_strength", "fractal_ping_pong_strength", "cellular_jitter"]:
		if not _number(noise[key], 0, 4): return false
	return true

static func _valid_environment(value: Variant) -> bool:
	if not _keys(value, ENV_FIELDS): return false
	if not _integer(value.background_mode, 1, 1) or not _integer(value.ambient_light_source, 2, 2) or not _integer(value.reflected_light_source, 1, 1) or not _integer(value.tonemap_mode, 0, 0) or not _integer(value.fog_mode, 1, 1) or not value.fog_enabled is bool: return false
	for key: String in ["background_color", "ambient_light_color", "fog_light_color"]:
		if not _color(value[key]): return false
	for key: String in ["ambient_light_energy", "fog_light_energy"]:
		if not _number(value[key], 0, 2): return false
	return _number(value.fog_depth_begin, 8, 20) and _number(value.fog_depth_end, 30, 60) and _number(value.fog_depth_curve, 0.5, 3) and _number(value.fog_sky_affect, 0, 1)

static func build_materials(issued: Dictionary) -> Dictionary:
	if not valid_snapshot(issued): return {}
	var result: Dictionary = {}
	var textures: Dictionary = {}
	for role: String in ROLE_PATHS:
		var entry: Dictionary = issued.material_roles[role]
		if entry.kind == "shader":
			var shader_material := ShaderMaterial.new()
			shader_material.shader = load(entry.shader) as Shader
			for key: String in entry.parameters:
				var parameter: Variant = entry.parameters[key]
				shader_material.set_shader_parameter(key, _as_color(parameter) if parameter is Array else parameter)
			result[role] = shader_material
		else:
			var standard := StandardMaterial3D.new()
			_apply_properties(standard, entry.values)
			if not entry.texture.is_empty():
				var texture_key := JSON.stringify(entry.texture)
				if not textures.has(texture_key): textures[texture_key] = _build_texture(entry.texture)
				standard.albedo_texture = textures[texture_key]
			result[role] = standard
	return result

static func build_environment(issued: Dictionary) -> Environment:
	if not valid_snapshot(issued): return null
	var result := Environment.new()
	_apply_properties(result, issued.environment)
	return result

static func _build_texture(value: Dictionary) -> NoiseTexture2D:
	var result := NoiseTexture2D.new()
	for key: String in ["width", "height", "seamless", "normalize", "invert", "seamless_blend_skirt"]:
		result.set(key, value[key])
	var noise := FastNoiseLite.new()
	_apply_properties(noise, value.noise)
	result.noise = noise
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([_as_color(value.colors[0]), _as_color(value.colors[1])])
	gradient.offsets = PackedFloat32Array(value.offsets)
	gradient.interpolation_mode = int(value.interpolation_mode)
	gradient.interpolation_color_space = int(value.interpolation_color_space)
	result.color_ramp = gradient
	return result

static func apply_materials(node: Node, resolved: Dictionary) -> void:
	# Native templates remain responsible for geometry/collision. Replace only
	# explicitly approved authored overrides; keep each level's material set shared.
	if node is GeometryInstance3D:
		var old: Material = node.material_override
		if old != null:
			for role: String in ROLE_PATHS:
				if old.resource_path == ROLE_PATHS[role] or old.resource_path == Catalog.CRYSTAL_ROLE_PATHS[role]:
					node.material_override = resolved[role]
					break
	for child: Node in node.get_children(): apply_materials(child, resolved)

static func _properties(resource: Resource, names: Array) -> Dictionary:
	var result: Dictionary = {}
	for key: String in names: result[key] = _plain(resource.get(key))
	return result

static func _plain(value: Variant) -> Variant:
	if value is Color: return [value.r, value.g, value.b, value.a]
	if value is Vector3: return [value.x, value.y, value.z]
	if value is Array: return value.duplicate(true)
	return value

static func _apply_properties(resource: Resource, values: Dictionary) -> void:
	for key: String in values:
		var value: Variant = values[key]
		if value is Array:
			value = _as_color(value) if value.size() == 4 else Vector3(value[0], value[1], value[2])
		resource.set(key, value)

static func _as_color(value: Array) -> Color:
	return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))

static func _keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size(): return false
	for key: Variant in keys:
		if not value.has(key): return false
	return true

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and float(value) == floor(float(value))

static func _vector(value: Variant, minimum: float, maximum: float) -> bool:
	return value is Array and value.size() == 3 and _number(value[0], minimum, maximum) and _number(value[1], minimum, maximum) and _number(value[2], minimum, maximum)

static func _color(value: Variant) -> bool:
	return value is Array and value.size() == 4 and _number(value[0], 0, 1) and _number(value[1], 0, 1) and _number(value[2], 0, 1) and _number(value[3], 0, 1)

static func module_path(issued: Dictionary, module_id: StringName) -> String:
	if not valid_snapshot(issued) or not issued.modules.has(String(module_id)): return ""
	return String(issued.modules[String(module_id)].scene)

static func module_instance_valid(issued: Dictionary, room: Node3D) -> bool:
	if not is_instance_valid(room) or room.is_queued_for_deletion() or not valid_snapshot(issued): return false
	var script: Script = room.get_script() as Script
	if script == null or script.resource_path != "res://scripts/world/abyss_room.gd": return false
	var logical_id: String = String(room.get("module_id"))
	if not issued.modules.has(logical_id): return false
	var entry: Dictionary = issued.modules[logical_id]
	if room.scene_file_path != entry.scene or String(room.get("visual_motif")) != entry.motif: return false
	var metadata: Dictionary = Catalog.profile(String(issued.id))
	var found: Dictionary = {}
	for child: Node in room.get_children():
		if String(child.name).begins_with("Decor"):
			var key := String(child.name)
			if not entry.native_slots.has(key): return false
			var alias: String = entry.native_slots[key]
			if not metadata.props.has(alias) or child.scene_file_path != metadata.props[alias]: return false
			found[key] = true
	return _keys(found, entry.native_slots.keys())
