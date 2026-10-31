extends Node
## Device presentation preferences only. Never reads or modifies progression data.
## Essential walls, enemy warnings, navigation and simulation stay identical.
signal settings_changed(settings: Dictionary)

const QUALITY_NAMES := ["Low", "Medium", "High"]
const PREFERENCE_VERSION := 3
const UI_SCALES := [100, 110, 120]
const AMBIENT_DENSITIES := [0, 50, 100]
const PRESETS := [
	{"decoration_density": 0.5, "decoration_distance": 24.0, "ambient_budget": 8, "effect_budget": 8, "shadow_size": 512, "shadow_distance": 24.0, "shadows": false, "msaa": Viewport.MSAA_DISABLED, "lod_threshold": 3.0},
	{"decoration_density": 0.75, "decoration_distance": 34.0, "ambient_budget": 16, "effect_budget": 14, "shadow_size": 1024, "shadow_distance": 34.0, "shadows": true, "msaa": Viewport.MSAA_DISABLED, "lod_threshold": 2.0},
	{"decoration_density": 1.0, "decoration_distance": 44.0, "ambient_budget": 24, "effect_budget": 20, "shadow_size": 2048, "shadow_distance": 44.0, "shadows": true, "msaa": Viewport.MSAA_2X, "lod_threshold": 1.0},
]
var current_quality := 1
var target_fps := 30
var ui_scale_percent := 100
var reduced_motion := false
var reduced_effects := false
var ambient_density_percent := 100
var high_contrast_prompts := false
var ambient_sound_enabled := false
var storage_path := "user://vaultbound/visual_settings.cfg"
var storage_error := ""
var _future_storage_path := ""
var quality_name: String:
	get: return QUALITY_NAMES[current_quality]
var decoration_density: float:
	get: return float(PRESETS[current_quality].decoration_density)
var decoration_distance: float:
	get: return float(PRESETS[current_quality].decoration_distance)
var ambient_budget: int:
	get: return maxi(4, int(float(PRESETS[current_quality].ambient_budget) * 0.5)) if reduced_effects else int(PRESETS[current_quality].ambient_budget)
var effect_budget: int:
	get: return maxi(4, int(float(PRESETS[current_quality].effect_budget) * 0.5)) if reduced_effects else int(PRESETS[current_quality].effect_budget)
var ambient_particle_budget: int:
	get: return floori(ambient_budget * ambient_density_percent / 100.0)
var decorative_motion_scale: float:
	get: return 0.0 if reduced_motion else 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_preferences()
	get_tree().node_added.connect(_on_node_added)
	_apply()

func snapshot() -> Dictionary:
	var result: Dictionary = PRESETS[current_quality].duplicate(true)
	result["quality"] = current_quality
	result["quality_name"] = quality_name
	result["target_fps"] = target_fps
	result["ui_scale_percent"] = ui_scale_percent
	result["reduced_motion"] = reduced_motion
	result["reduced_effects"] = reduced_effects
	result["ambient_budget"] = ambient_budget
	result["effect_budget"] = effect_budget
	result["ambient_density_percent"] = ambient_density_percent
	result["ambient_particle_budget"] = ambient_particle_budget
	result["high_contrast_prompts"] = high_contrast_prompts
	result["ambient_sound_enabled"] = ambient_sound_enabled
	result["decorative_motion_scale"] = decorative_motion_scale
	return result

func load_preferences(path: String = "") -> bool:
	if not path.is_empty():
		storage_path = path
	storage_error = ""
	if not FileAccess.file_exists(storage_path):
		return true
	var config := ConfigFile.new()
	var error := config.load(storage_path)
	if error != OK:
		storage_error = "Graphics preferences could not be loaded; current settings remain."
		return false
	var version: Variant = config.get_value("graphics", "version", 1)
	if typeof(version) == TYPE_INT and int(version) > PREFERENCE_VERSION:
		_future_storage_path = ProjectSettings.globalize_path(storage_path)
		storage_error = "Preferences belong to a newer build and will not be replaced. Current settings remain."
		return false
	var preferences := _read_preferences(config)
	if preferences.is_empty():
		storage_error = "Graphics preferences are invalid; current settings remain."
		return false
	if _future_storage_path == ProjectSettings.globalize_path(storage_path):
		_future_storage_path = ""
	_install_preferences(preferences)
	if is_inside_tree():
		_apply()
	return true

func set_options(quality: int, fps: int) -> bool:
	return set_preferences(quality, fps, ui_scale_percent, reduced_motion, reduced_effects)

func set_accessibility(scale_percent: int, motion: bool, effects: bool) -> bool:
	return set_preferences(current_quality, target_fps, scale_percent, motion, effects)

func set_preferences(quality: int, fps: int, scale: int, motion: bool, effects: bool) -> bool:
	# Preserve the added selections for every existing five-argument caller.
	return set_presentation_preferences(quality, fps, scale, motion, effects, ambient_density_percent, high_contrast_prompts, ambient_sound_enabled)

func set_presentation_preferences(quality: int, fps: int, scale: int, motion: bool, effects: bool,
		density: int, contrast: bool, sound: bool) -> bool:
	# Another build may have replaced the destination since our last load.
	# Check its header even for unchanged selections or a newly assigned path.
	if FileAccess.file_exists(storage_path):
		var destination := ConfigFile.new()
		if destination.load(storage_path) == OK:
			var destination_version: Variant = destination.get_value("graphics", "version", 1)
			if typeof(destination_version) == TYPE_INT and int(destination_version) > PREFERENCE_VERSION:
				_future_storage_path = ProjectSettings.globalize_path(storage_path)
	if _future_storage_path == ProjectSettings.globalize_path(storage_path):
		storage_error = "Preferences belong to a newer build and will not be replaced. Current settings remain."
		return false
	if quality not in [0, 1, 2] or fps not in [30, 60] or scale not in UI_SCALES or density not in AMBIENT_DENSITIES:
		storage_error = "Choose a preset, 30/60 FPS, UI 100/110/120%, and ambient density 0/50/100%."
		return false
	var preferences := {"quality": quality, "target_fps": fps, "ui_scale_percent": scale,
		"reduced_motion": motion, "reduced_effects": effects, "ambient_density_percent": density,
		"high_contrast_prompts": contrast, "ambient_sound_enabled": sound}
	if quality == current_quality and fps == target_fps and scale == ui_scale_percent and motion == reduced_motion and effects == reduced_effects \
			and density == ambient_density_percent and contrast == high_contrast_prompts and sound == ambient_sound_enabled and storage_error.is_empty():
		return true
	var config := ConfigFile.new()
	config.set_value("graphics", "version", PREFERENCE_VERSION)
	config.set_value("graphics", "quality", quality)
	config.set_value("graphics", "target_fps", fps)
	config.set_value("accessibility", "ui_scale_percent", scale)
	config.set_value("accessibility", "reduced_motion", motion)
	config.set_value("accessibility", "reduced_effects", effects)
	config.set_value("accessibility", "high_contrast_prompts", contrast)
	config.set_value("ambience", "ambient_density_percent", density)
	config.set_value("ambience", "ambient_sound_enabled", sound)
	var directory := ProjectSettings.globalize_path(storage_path).get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK or config.save(storage_path + ".tmp") != OK:
		storage_error = "Could not save graphics preferences; settings were not changed."
		return false
	var verified := ConfigFile.new()
	if verified.load(storage_path + ".tmp") != OK or _read_preferences(verified) != preferences:
		storage_error = "Could not verify graphics preferences; settings were not changed."
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(storage_path + ".tmp"), ProjectSettings.globalize_path(storage_path)) != OK:
		storage_error = "Could not replace graphics preferences; settings were not changed."
		return false
	_install_preferences(preferences)
	storage_error = ""
	_apply()
	settings_changed.emit(snapshot())
	return true

func _read_preferences(config: ConfigFile) -> Dictionary:
	# A present but truncated file must not silently become a default selection.
	# Original unversioned files are valid only when both graphics keys survived.
	if not config.has_section_key("graphics", "quality") or not config.has_section_key("graphics", "target_fps"):
		return {}
	var version: Variant = config.get_value("graphics", "version", 1)
	var quality: Variant = config.get_value("graphics", "quality", 1)
	var fps: Variant = config.get_value("graphics", "target_fps", 30)
	if typeof(version) != TYPE_INT or int(version) not in [1, 2, PREFERENCE_VERSION] or typeof(quality) != TYPE_INT or typeof(fps) != TYPE_INT or int(quality) not in [0, 1, 2] or int(fps) not in [30, 60]:
		return {}
	var preferences := {"quality": int(quality), "target_fps": int(fps), "ui_scale_percent": 100,
		"reduced_motion": false, "reduced_effects": false, "ambient_density_percent": 100,
		"high_contrast_prompts": false, "ambient_sound_enabled": false}
	if int(version) == 1:
		return preferences # Original graphics-only files migrate in memory, without a write.
	var scale: Variant = config.get_value("accessibility", "ui_scale_percent", -1)
	var motion: Variant = config.get_value("accessibility", "reduced_motion", "missing")
	var effects: Variant = config.get_value("accessibility", "reduced_effects", "missing")
	if typeof(scale) != TYPE_INT or int(scale) not in UI_SCALES or not motion is bool or not effects is bool:
		return {}
	preferences.ui_scale_percent = int(scale)
	preferences.reduced_motion = bool(motion)
	preferences.reduced_effects = bool(effects)
	if int(version) == 2:
		return preferences # All five original choices survive; additions default in memory.
	var density: Variant = config.get_value("ambience", "ambient_density_percent", "missing")
	var contrast: Variant = config.get_value("accessibility", "high_contrast_prompts", "missing")
	var sound: Variant = config.get_value("ambience", "ambient_sound_enabled", "missing")
	if typeof(density) != TYPE_INT or int(density) not in AMBIENT_DENSITIES or not contrast is bool or not sound is bool:
		return {}
	preferences.ambient_density_percent = int(density)
	preferences.high_contrast_prompts = bool(contrast)
	preferences.ambient_sound_enabled = bool(sound)
	return preferences

func _install_preferences(preferences: Dictionary) -> void:
	current_quality = int(preferences.quality)
	target_fps = int(preferences.target_fps)
	ui_scale_percent = int(preferences.ui_scale_percent)
	reduced_motion = bool(preferences.reduced_motion)
	reduced_effects = bool(preferences.reduced_effects)
	ambient_density_percent = int(preferences.ambient_density_percent)
	high_contrast_prompts = bool(preferences.high_contrast_prompts)
	ambient_sound_enabled = bool(preferences.ambient_sound_enabled)

func _apply() -> void:
	Engine.max_fps = target_fps
	if not is_inside_tree():
		return
	var preset := snapshot()
	# Shared decorative shader state changes only on preference application.
	# Reduced motion selects deterministic phase zero; combat shaders are separate.
	RenderingServer.global_shader_parameter_set("vault_decorative_motion_scale", decorative_motion_scale)
	get_tree().root.msaa_3d = preset.msaa
	get_tree().root.mesh_lod_threshold = preset.lod_threshold
	RenderingServer.directional_shadow_atlas_set_size(int(preset.shadow_size), true)
	apply_to(get_tree().root)

func apply_to(node: Node) -> void:
	if not is_instance_valid(node):
		return
	_apply_node(node)
	for child: Node in node.get_children():
		apply_to(child)

func _apply_node(node: Node) -> void:
	if node is DirectionalLight3D:
		if not node.has_meta("visual_original_shadows"):
			node.set_meta("visual_original_shadows", node.shadow_enabled)
		node.shadow_enabled = bool(node.get_meta("visual_original_shadows")) and bool(PRESETS[current_quality].shadows)
		node.directional_shadow_max_distance = float(PRESETS[current_quality].shadow_distance)
	if node != self and node.has_method("apply_visual_settings"):
		node.apply_visual_settings(snapshot())

func _on_node_added(node: Node) -> void:
	# Ready-time property setup must finish before we apply a light's preferences.
	if node is DirectionalLight3D or node.has_method("apply_visual_settings"):
		_apply_new_node.call_deferred(weakref(node))

func _apply_new_node(reference: WeakRef) -> void:
	var node: Node = reference.get_ref()
	if is_instance_valid(node) and node.is_inside_tree():
		_apply_node(node)
