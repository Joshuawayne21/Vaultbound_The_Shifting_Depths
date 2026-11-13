extends Node3D
## A secondary receiver of the city's Prismheart visual language, not a second
## LivingPrismheart actor. No event state, progression or gameplay light exists.
const CONFIG = preload("res://resources/sanctuary/prismheart_capital.tres")
const Style = preload("res://scripts/visual/visual_style.gd")
var _core: Node3D
var _rings: Array[MeshInstance3D] = []
var _sparks: MultiMeshInstance3D
var _elapsed := 0.0
var _phase := 0.0
var _interval := 0.08
var _motion := 1.0
var _spark_count := 8
var _glow: StandardMaterial3D

func _ready() -> void:
	name = "RealmConduit"
	set_meta("dynamic_visual", true)
	set_meta("native_placeholder_art", true)
	set_meta("prismheart_visual_source", CONFIG.resource_path)
	add_to_group("visual_quality")
	var palette := Style.palette()
	_glow = (palette.crystal as StandardMaterial3D).duplicate() as StandardMaterial3D
	_glow.albedo_color = Color("88c7e9")
	_glow.emission_enabled = true
	_glow.emission = Color("79cce5")
	_glow.emission_energy_multiplier = 0.28
	_core = Node3D.new()
	_core.name = "SuspendedHexagonalPrism"
	add_child(_core)
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 1.15
	body_mesh.bottom_radius = 1.15
	body_mesh.height = 3.0
	body_mesh.radial_segments = 6
	body_mesh.rings = 1
	_mesh(_core, body_mesh, Vector3.ZERO, _glow)
	for side: float in [-1.0, 1.0]:
		var cap := CylinderMesh.new()
		cap.top_radius = 0.0 if side > 0 else 1.15
		cap.bottom_radius = 1.15 if side > 0 else 0.0
		cap.height = 1.2
		cap.radial_segments = 6
		cap.rings = 1
		_mesh(_core, cap, Vector3(0, side * 2.1, 0), _glow)
	for index in range(2):
		var mesh := TorusMesh.new()
		mesh.inner_radius = 2.3 + float(index) * 0.32
		mesh.outer_radius = mesh.inner_radius + 0.07
		mesh.rings = 32
		mesh.ring_segments = 4
		var ring := _mesh(self, mesh, Vector3.ZERO, palette.gold)
		ring.name = "ReceiverOrbit%d" % index
		_rings.append(ring)
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3.ONE * 0.045
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = spark_mesh
	instances.instance_count = 12
	_sparks = MultiMeshInstance3D.new()
	_sparks.name = "BoundedReceiverSparks"
	_sparks.multimesh = instances
	_sparks.material_override = _glow
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)
	var envelope := StaticBody3D.new()
	envelope.name = "ConduitCameraEnvelope"
	envelope.collision_layer = 8
	envelope.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(6.4, 6.1, 6.4)
	shape.shape = bounds
	envelope.add_child(shape)
	add_child(envelope)
	var settings := get_node_or_null("/root/VisualSettings")
	apply_visual_settings(settings.snapshot() if settings != null else {"quality": 1})
	_update_pose()

func apply_visual_settings(settings: Dictionary) -> void:
	var quality := clampi(int(settings.get("quality", 1)), 0, 2)
	_interval = 0.16 if quality == 0 else 0.08
	_motion = clampf(float(settings.get("decorative_motion_scale", 0.0 if bool(settings.get("reduced_motion", false)) else 1.0)), 0.0, 1.0)
	var density := clampi(int(settings.get("ambient_density_percent", 100)), 0, 100)
	_spark_count = floori(float(CONFIG.sparkle_counts[quality]) * float(density) / 100.0)
	if bool(settings.get("reduced_effects", false)): _spark_count = mini(_spark_count, 4)
	if is_instance_valid(_sparks): _sparks.multimesh.visible_instance_count = _spark_count
	if _glow != null: _glow.emission_energy_multiplier = 0.10 if bool(settings.get("reduced_effects", false)) else 0.28
	set_process(_motion > 0.0)
	if is_instance_valid(_core): _update_pose()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_elapsed += clampf(delta, 0.0, 0.1)
	if _elapsed < _interval: return
	_phase += _elapsed * _motion
	_elapsed = 0.0
	_update_pose()

func _update_pose() -> void:
	_core.rotation.y = _phase * 0.13
	_core.position.y = sin(_phase * 0.7) * 0.08 * _motion
	for index in range(_rings.size()):
		_rings[index].rotation = Vector3(0.35 if index == 0 else -0.45, _phase * (0.05 if index == 0 else -0.04), 0.12)
	for index in range(12):
		var angle := float(index) * TAU / 12.0 + _phase * 0.07
		_sparks.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(sin(angle) * 3.05, sin(angle * 2.0) * 0.6, cos(angle) * 3.05)))

func presentation_snapshot() -> Dictionary:
	return {"spark_cap": 12, "active_sparks": _spark_count, "pose_interval": _interval,
		"motion_scale": _motion, "realtime_lights": 0, "prismheart_visual_source": CONFIG.resource_path,
		"native_placeholder_art": true, "center_y": position.y}

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
