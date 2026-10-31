class_name VaultVisualStyle
extends RefCounted
## Original Enchanted Dark Fantasy style. Shared resources, no imported asset pack.
## All presets use Compatibility depth fog and one directional key; no volumetrics,
## screen-space reflections, post-process glow or height-fog dependency.

const Ambient = preload("res://scripts/visual/ambient_motes.gd")
const MATERIALS := {
	"stone": "sanctuary_stone", "light_stone": "sanctuary_light_stone",
	"dark_stone": "sanctuary_slate", "paving_a": "sanctuary_paving_a",
	"paving_b": "sanctuary_paving_b", "path": "sanctuary_path",
	"gold": "sanctuary_gold", "bronze": "sanctuary_bronze",
	"wood": "sanctuary_wood", "leaf": "abyss_leaf",
	"leaf_light": "sanctuary_leaf_light", "cloth": "sanctuary_cloth",
	"glow": "abyss_glow", "flame": "sanctuary_flame",
	"crystal": "sanctuary_crystal", "moss": "abyss_moss",
	"water": "abyss_water", "water_deep": "abyss_dark_water",
	"foam": "abyss_foam", "flower": "abyss_flower",
}
static func palette() -> Dictionary:
	# ResourceLoader's cache shares each asset while any kit uses it. Avoid a static
	# resource dictionary, which would pin shader/texture RIDs after scene teardown.
	var result: Dictionary = {}
	for key: String in MATERIALS:
		result[key] = load("res://resources/materials/%s.tres" % MATERIALS[key])
	return result

static func environment_preset(biome: StringName = &"sanctuary") -> Environment:
	var safe_biome := String(biome) if biome in [&"sanctuary", &"abyss", &"hall"] else "sanctuary"
	# Each level owns its tunable Environment; underlying materials stay shared.
	return load("res://resources/environments/%s.tres" % safe_biome).duplicate() as Environment

static func apply_environment(parent: Node3D, biome: StringName = &"sanctuary") -> WorldEnvironment:
	var world := WorldEnvironment.new()
	world.name = "EnchantedEnvironment"
	world.environment = environment_preset(biome)
	parent.add_child(world)
	var key := DirectionalLight3D.new()
	key.name = "WarmKey" if biome != &"abyss" else "CanopyKey"
	key.rotation_degrees = Vector3(-48, -28, 0)
	key.light_color = Color("edbd82") if biome != &"abyss" else Color("c6dac0")
	key.light_energy = 1.0 if biome != &"abyss" else 0.82
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 36.0
	key.shadow_bias = 0.05
	parent.add_child(key)
	return world

static func add_ambience(parent: Node3D, biome: StringName, bounds: Vector3, visual_seed: int = 1) -> Node3D:
	var motes := Ambient.new()
	motes.name = "EnchantedMotes"
	motes.biome = biome
	motes.bounds = bounds
	motes.visual_seed = visual_seed
	parent.add_child(motes)
	return motes
