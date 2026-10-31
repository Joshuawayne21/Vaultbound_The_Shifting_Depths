extends "res://tests/test_harness.gd"
const Style = preload("res://scripts/visual/visual_style.gd")
const Architecture = preload("res://scripts/world/architecture.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND VISUAL STYLE"
	_run.call_deferred()

func _run() -> void:
	var a := Style.palette()
	var b := Style.palette()
	check(a.size() >= 20, "Shared palette includes architecture, water, flora and bronze")
	for key: String in a:
		check(a[key] is Material and a[key] == b[key], "Shared material identity for " + key)
	a.erase("gold")
	check(b.has("gold") and Style.palette().has("gold"), "A kit cannot erase another kit's palette entries")
	for biome: StringName in [&"sanctuary", &"abyss", &"hall"]:
		var env := Style.environment_preset(biome)
		var other := Style.environment_preset(biome)
		check(env != other and env is Environment, "Each level owns its environment settings: " + String(biome))
		check(env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and env.ambient_light_energy > 0.5, "Ambient color keeps shaded surfaces readable: " + String(biome))
		check(env.fog_enabled and env.fog_mode == Environment.FOG_MODE_DEPTH and env.fog_depth_end > env.fog_depth_begin, "Depth fog range is valid: " + String(biome))
		check(not env.volumetric_fog_enabled and not env.ssr_enabled and not env.ssao_enabled and not env.glow_enabled, "No unsupported expensive post effects: " + String(biome))
	var space := Node3D.new()
	root.add_child(space)
	var kit := Architecture.new(space)
	var decorative := kit.box(Vector3.ZERO, Vector3.ONE, "gold")
	var solid := kit.box(Vector3(2, 0, 0), Vector3.ONE, "stone", true)
	check(decorative.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Small decoration avoids extra shadow draws")
	check(solid.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and solid.get_child_count() == 1, "Solid architecture retains its existing shadow and collision")
	var motes := Style.add_ambience(space, &"abyss", Vector3(10, 2, 10), 71)
	motes.configure_budget(12)
	check(motes.multimesh.instance_count == 24 and motes.multimesh.visible_instance_count <= 12, "Ambient sprites allocate a bounded reusable batch")
	motes.apply_visual_settings({"ambient_budget":8})
	check(motes.multimesh.visible_instance_count == 8, "Low quality limits ambient draws to eight sprites")
	motes.apply_visual_settings({"ambient_budget":24})
	check(motes.multimesh.visible_instance_count == 12, "Room cap still applies on High")
	check(not motes.is_processing() and motes.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Ambient animation needs no CPU processing or shadows")
	var water := load("res://scenes/props/abyss_stream.tscn").instantiate() as Node3D
	space.add_child(water)
	var before := water.get_node("Foam0").position as Vector3
	await frames(12)
	check(water.get_node("Foam0").position != before, "Water ribbons visibly advance without fluid physics")
	water.apply_visual_settings({"quality":0})
	check(not water.get_node("Foam2").visible, "Low quality removes the optional third foam strip")
	var falls := load("res://scenes/props/abyss_falls.tscn").instantiate() as Node3D
	space.add_child(falls)
	check(falls.get_node("Flow/Water").material_override == load("res://resources/materials/abyss_falling_water.tres"), "Waterfall uses its faster falling-water material")
	check(falls.get_node("RockBack/Body/Collision").shape.size == Vector3(2.1, 6, 0.5), "Existing waterfall collision is unchanged")
	for file: String in ["living_water", "living_foliage", "ambient_mote", "soft_foam"]:
		var shader := load("res://resources/shaders/%s.gdshader" % file) as Shader
		check(shader != null and not shader.code.contains("hint_screen_texture") and not shader.code.contains("hint_depth_texture"), "Shader avoids screen/depth framebuffer copies: " + file)
	space.queue_free()
	await frames(3)
	finish()
