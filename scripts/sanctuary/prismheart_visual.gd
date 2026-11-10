extends Node3D
## One original floating landmark, one throttled cosmetic driver. No simulated
## world events, gameplay light, currency or remote service are created here.
const CONFIG = preload("res://resources/sanctuary/prismheart_capital.tres")
var _diamond: MeshInstance3D
var _rings: Array[MeshInstance3D] = []
var _sparks: MultiMeshInstance3D
var _phase := 0.0
var _elapsed := 0.0
var _interval := 0.05
var _motion := 1.0
var _effects := 1.0
var _spark_count := 8
var _surfaces: Array[StandardMaterial3D] = []

func _ready() -> void:
	name = "LivingPrismheart"
	position = Vector3(0, float(CONFIG.crystal_center_y), 0)
	set_meta("dynamic_visual", true)
	set_meta("native_placeholder_art", true)
	add_to_group("visual_quality")
	_build()
	var settings := get_node_or_null("/root/VisualSettings")
	apply_visual_settings(settings.snapshot() if settings != null else {"quality": 1})
	_update_pose()

func _surface(tint: Color, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = 0.55
	material.roughness = 0.50
	material.emission_enabled = emission > 0.0
	material.emission = tint
	material.emission_energy_multiplier = emission
	_surfaces.append(material)
	return material

func _build() -> void:
	var diamond := SurfaceTool.new()
	diamond.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(8):
		var a := float(index) * TAU / 8.0
		var b := float(index + 1) * TAU / 8.0
		var pa := Vector3(cos(a) * 1.5, 0, sin(a) * 1.5)
		var pb := Vector3(cos(b) * 1.5, 0, sin(b) * 1.5)
		for upper: bool in [true, false]:
			var tip := Vector3(0, 3.4 if upper else -3.4, 0)
			var vertices := PackedVector3Array([tip, pb, pa] if upper else [tip, pa, pb])
			var normal := (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0]).normalized()
			var tint := Color("6194ed") if index % 2 == 0 else Color("65d6e0")
			if not upper: tint = tint.darkened(0.17)
			for corner: int in [0, 2, 1]:
				diamond.set_normal(normal)
				diamond.set_color(tint)
				diamond.add_vertex(vertices[corner])
	_diamond = MeshInstance3D.new()
	_diamond.name = "PrismheartFacets"
	_diamond.mesh = diamond.commit()
	var crystal := _surface(Color.WHITE, 0.28)
	crystal.vertex_color_use_as_albedo = true
	crystal.emission = Color("5ba9e8")
	_diamond.material_override = crystal
	_diamond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_diamond)
	var gold := _surface(Color("d9b35e"), 0.08)
	for index in range(2):
		var ring := MeshInstance3D.new()
		ring.name = "GoldenOrbit_%d" % index
		var mesh := TorusMesh.new()
		mesh.inner_radius = 3.05 + index * 0.28
		mesh.outer_radius = mesh.inner_radius + 0.10
		mesh.rings = 48
		mesh.ring_segments = 6
		ring.mesh = mesh
		ring.material_override = gold
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_rings.append(ring)
	_sparks = MultiMeshInstance3D.new()
	_sparks.name = "BoundedPrismheartMotes"
	var sparks := MultiMesh.new()
	sparks.transform_format = MultiMesh.TRANSFORM_3D
	var spark := BoxMesh.new()
	spark.size = Vector3(0.065, 0.065, 0.065)
	sparks.mesh = spark
	sparks.instance_count = 12
	_sparks.multimesh = sparks
	_sparks.material_override = _surface(Color("97e9e4"), 0.35)
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)
	# One fixed envelope contains all rotated rings, bobbing facets and motes.
	# It affects camera obstruction only; all original ground arrivals stay clear.
	var body := StaticBody3D.new()
	body.name = "PrismheartCameraEnvelope"
	body.collision_layer = 8
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(7.8, 7.4, 7.8)
	shape.shape = bounds
	body.add_child(shape)
	add_child(body)

func apply_visual_settings(settings: Dictionary) -> void:
	var quality := clampi(int(settings.get("quality", 1)), 0, 2)
	_interval = 0.1 if quality == 0 else 0.05
	_motion = clampf(float(settings.get("decorative_motion_scale", 0.0 if settings.get("reduced_motion", false) else 1.0)), 0.0, 1.0)
	_effects = 0.35 if bool(settings.get("reduced_effects", false)) else 1.0
	var density := clampi(int(settings.get("ambient_density_percent", 100)), 0, 100)
	_spark_count = floori(float(CONFIG.sparkle_counts[quality]) * density / 100.0)
	if bool(settings.get("reduced_effects", false)): _spark_count = mini(_spark_count, 4)
	if is_instance_valid(_sparks): _sparks.multimesh.visible_instance_count = _spark_count
	if _surfaces.size() == 3:
		_surfaces[0].emission_energy_multiplier = 0.28 * _effects
		_surfaces[1].emission_energy_multiplier = 0.08 * _effects
		_surfaces[2].emission_energy_multiplier = 0.35 * _effects
	set_process(_motion > 0.0)
	if is_instance_valid(_diamond): _update_pose()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_elapsed += clampf(delta, 0.0, 0.1)
	if _elapsed < _interval: return
	_phase += _elapsed * _motion
	_elapsed = 0.0
	_update_pose()

func _update_pose() -> void:
	_diamond.rotation.y = _phase * 0.12
	_diamond.position.y = sin(_phase * 0.7) * 0.10 * _motion
	for index in range(_rings.size()):
		_rings[index].rotation = Vector3(0.42 if index == 0 else -0.46, _phase * (0.055 if index == 0 else -0.045), 0.18 if index == 0 else -0.22)
	for index in range(12):
		var angle := float(index) * TAU / 12.0 + _phase * 0.08
		var point := Vector3(cos(angle) * 3.65, sin(angle * 2.0 + _phase * 0.4) * 0.75, sin(angle) * 3.65)
		_sparks.multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.UP, angle), point))

func presentation_snapshot() -> Dictionary:
	return {"spark_cap": 12, "active_sparks": _spark_count, "pose_interval": _interval,
		"motion_scale": _motion, "effects_scale": _effects, "realtime_lights": 0,
		"native_placeholder_art": true, "center_y": position.y}
