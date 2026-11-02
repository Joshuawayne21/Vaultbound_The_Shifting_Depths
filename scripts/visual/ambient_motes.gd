class_name VaultAmbientMotes
extends MultiMeshInstance3D
## One bounded draw, no CPU animation/physics/navigation or dynamic lights.
## Room visibility naturally culls the sprites. The shader never disables depth tests.

@export var bounds := Vector3(10.0, 2.4, 10.0)
@export var biome: StringName = &"sanctuary"
@export var visual_seed: int = 1
@export_range(0, 24, 1) var maximum_motes := 24
var _quality_budget := 16

func _ready() -> void:
	add_to_group("visual_quality")
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 0.6
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.065, 0.065)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = 24
	var rng := RandomNumberGenerator.new()
	rng.seed = visual_seed
	for index in range(24):
		var point := Vector3(rng.randf_range(-bounds.x * 0.5, bounds.x * 0.5), rng.randf_range(0.3, maxf(0.31, bounds.y)), rng.randf_range(-bounds.z * 0.5, bounds.z * 0.5))
		instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, point))
		var tint := Color("9ebfee") if biome == &"crystal" else Color("a7e8b2") if biome == &"abyss" else Color("ffd69a")
		if index % 3 == 0:
			tint = Color("6bd9cc")
		tint.a = 0.85 if index % 2 == 0 else 0.45
		instances.set_instance_color(index, tint)
		instances.set_instance_custom_data(index, Color(rng.randf(), rng.randf(), 0, 1))
	multimesh = instances
	material_override = preload("res://resources/materials/ambient_mote.tres")
	var settings := get_node_or_null("/root/VisualSettings")
	if settings != null and settings.has_method("apply_to"):
		settings.apply_to(self)
	else:
		_apply_budget()

func configure_budget(count: int) -> void:
	maximum_motes = clampi(count, 0, 24)
	_apply_budget()

func apply_visual_settings(settings: Dictionary) -> void:
	_quality_budget = clampi(int(settings.get("ambient_particle_budget", settings.get("ambient_budget", 16))), 0, 24)
	_apply_budget()

func _apply_budget() -> void:
	if multimesh != null:
		multimesh.visible_instance_count = mini(maximum_motes, _quality_budget)
