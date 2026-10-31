class_name VaultItemPresentation
extends Node3D
## Original native-mesh accents around existing family models. Owns no gameplay
## state. Inspection/weapon_preview contexts are strictly static and demand-only.

const Budget = preload("res://scripts/visual/item_presentation_budget.gd")
const COLORS := {"common": Color("a6b2bd"), "uncommon": Color("68c985"),
	"rare": Color("5fa9ef"), "epic": Color("b07aee"), "legendary": Color("edc36b"),
	"mythic": Color("db526f"), "ancient_relic": Color("57dcc5")}
var _record: Dictionary = {}
var _context: StringName = &"inspection"
var _target: Node3D
var _base := Transform3D.IDENTITY
var _rotation_speed := 0.0
var _bob_height := 0.0
var _bob_speed := 0.0
var _phase := 0.0
var _active := false
var _reduced_motion := false
var _reduced_effects := false
var _spark_count := 0
var _rank := 0
var _rarity_index := 0
var _rim: MeshInstance3D
var _runes: MultiMeshInstance3D
var _sparks: MultiMeshInstance3D
var _materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	set_meta("dynamic_visual", true)
	set_process(false)
	_sync_registration()

func configure(definition: VaultItemDefinition, entry: Dictionary,
		motion_target: Node3D = null, context: StringName = &"display") -> void:
	clear()
	if definition == null or entry.is_empty():
		return
	_context = context if context in [&"display", &"weapon", &"inspection", &"weapon_preview"] else &"inspection"
	_rank = clampi(int(entry.get("enhancement", 0)), 0, 10)
	_rarity_index = maxi(0, VaultItemDefinition.RARITIES.find(definition.rarity))
	_record = {"uid": String(entry.get("uid", "")), "item_id": String(definition.id),
		"enhancement": _rank, "rarity": definition.rarity}
	if _context == &"display" and is_instance_valid(motion_target):
		_target = motion_target
		_base = motion_target.transform
		_rotation_speed = clampf(float(definition.display_animation.get("rotation_speed", 0.22)), -0.5, 0.5)
		_bob_height = clampf(float(definition.display_animation.get("bob_height", 0.0)), 0.0, 0.08)
		_bob_speed = clampf(float(definition.display_animation.get("bob_speed", 1.2)), 0.0, 2.0)
	_build(COLORS.get(definition.rarity, COLORS.common))
	visible = true
	_sync_registration()
	var settings := get_node_or_null("/root/VisualSettings") if is_inside_tree() else null
	if settings != null:
		apply_visual_settings(settings.snapshot())

func clear() -> void:
	set_process(false)
	if is_instance_valid(_target):
		_target.transform = _base
	_target = null
	_record.clear()
	_phase = 0.0
	_active = false
	_spark_count = 0
	_rotation_speed = 0.0
	_bob_height = 0.0
	_bob_speed = 0.0
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_rim = null
	_runes = null
	_sparks = null
	_materials.clear()
	visible = false
	if is_in_group("item_presentations"):
		remove_from_group("item_presentations")

func _sync_registration() -> void:
	if not is_inside_tree() or _record.is_empty():
		return
	if _context in [&"display", &"weapon"]:
		add_to_group("item_presentations")
		Budget.ensure(get_tree())
	else:
		set_process(false)

func _surface(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Keep depth testing enabled: accents never expose items through walls.
	result.no_depth_test = false
	result.cull_mode = BaseMaterial3D.CULL_BACK
	_materials.append(result)
	return result

func _build(color: Color) -> void:
	var weapon := _context in [&"weapon", &"weapon_preview"]
	var radius := 0.12 if weapon else 0.48
	var rim := TorusMesh.new()
	rim.inner_radius = radius * 0.93
	rim.outer_radius = radius
	rim.rings = 24
	rim.ring_segments = 4
	_rim = MeshInstance3D.new()
	_rim.name = "RarityRim"
	_rim.mesh = rim
	_rim.material_override = _surface(color)
	_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rim)
	var rune := BoxMesh.new()
	rune.size = Vector3(0.015, 0.012, 0.08) * (0.35 if weapon else 1.0)
	_runes = _multi("RarityRunes", rune, _rarity_index + 1,
		Color("e5be70") if _rarity_index == 6 else color)
	for index in range(_rarity_index + 1):
		var angle := TAU * float(index) / float(_rarity_index + 1)
		_runes.multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.UP, angle), Vector3(sin(angle), 0.008, cos(angle)) * radius * 1.1))
	# Static previews never even allocate a particle mesh.
	if _context in [&"display", &"weapon"]:
		var spark := SphereMesh.new()
		spark.radius = 0.012 if weapon else 0.025
		spark.height = spark.radius * 2.0
		spark.radial_segments = 6
		spark.rings = 3
		_sparks = _multi("BoundedSparks", spark, 3, color)
		_sparks.multimesh.visible_instance_count = 0

func _multi(label: String, mesh: Mesh, count: int, color: Color) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.mesh = mesh
	node.multimesh.instance_count = count
	node.material_override = _surface(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func apply_visual_settings(options: Dictionary) -> void:
	_reduced_motion = bool(options.get("reduced_motion", false))
	_reduced_effects = bool(options.get("reduced_effects", false))
	var color: Color = COLORS.get(String(_record.get("rarity", "common")), COLORS.common)
	for index in range(_materials.size()):
		var tint := Color("e5be70") if _rarity_index == 6 and index == 1 else color
		_materials[index].albedo_color = tint.darkened(0.48 if _reduced_effects else 0.0)
	set_world_activity(_active, _spark_count)

func requested_sparks() -> int:
	if _record.is_empty() or _reduced_effects or _reduced_motion:
		return 0
	return clampi(_rarity_index - 2 + (1 if _rank >= 5 else 0), 0, 3)

func set_world_activity(active: bool, sparks: int) -> void:
	if _context not in [&"display", &"weapon"]:
		set_process(false)
		return
	_active = active and not _record.is_empty()
	_spark_count = mini(clampi(sparks, 0, 3), requested_sparks()) if _active else 0
	if is_instance_valid(_sparks):
		_sparks.multimesh.visible_instance_count = _spark_count
	set_process(_active and not _reduced_motion and
		(_spark_count > 0 or (is_instance_valid(_target) and (not is_zero_approx(_rotation_speed) or _bob_height > 0.0))))

func _process(delta: float) -> void:
	if not _active or _reduced_motion or not is_visible_in_tree():
		return
	_phase += minf(delta, 0.1)
	if is_instance_valid(_target):
		var pose := _base
		pose.basis = _base.basis * Basis(Vector3.UP, fmod(_phase * _rotation_speed, TAU))
		pose.origin.y = _base.origin.y + sin(_phase * _bob_speed) * _bob_height
		_target.transform = pose
	if is_instance_valid(_sparks):
		var weapon := _context == &"weapon"
		for index in range(_spark_count):
			var angle := _phase * 0.6 + float(index) * TAU / 3.0
			var radius := 0.13 if weapon else 0.52
			var at := Vector3(sin(angle) * radius, (0.05 if weapon else 0.12) + (sin(angle * 1.7) + 1.0) * (0.035 if weapon else 0.12), cos(angle) * radius)
			_sparks.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, at))

func snapshot() -> Dictionary:
	var result := _record.duplicate(true)
	result.merge({"context": String(_context), "spark_count": _spark_count,
		"processing": is_processing(), "registered": is_in_group("item_presentations")})
	return result
