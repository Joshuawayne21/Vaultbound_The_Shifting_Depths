class_name SanctuaryAmbience
extends Node3D
## Local presentation only: native residents, small animals, a readable daylight
## cycle and an optional original sound loop. No gameplay actors or physics.

const Style = preload("res://scripts/visual/visual_style.gd")
const DAY_INTERVAL := 0.5
const ACTOR_INTERVAL := 0.1
const DAY_SECONDS := 1200.0
const MAX_TOWNSFOLK := 4
const MAX_ANIMALS := 4
const TOWNSFOLK_BUDGETS := [2, 3, 4]
const ANIMAL_BUDGETS := [0, 2, 4]
const ACTOR_RADIUS := 28.8
const AUDIO_SAMPLE_RATE := 11025
const AUDIO_SECONDS := 3

var _city: Node3D
var _layout: Resource
var _environment: Environment
var _key: DirectionalLight3D
var _viewer: Node3D
var _audio: AudioStreamPlayer
var _actors: Array[Dictionary] = []
var _palette: Dictionary = {}
var _cube: BoxMesh
var _round: SphereMesh
var _skin: StandardMaterial3D
var _fur: StandardMaterial3D
var _quality := 1
var _distance := 34.0
var _motion_scale := 1.0
var _sound_enabled := false
var _phase := 0.5
var _night_amount := 0.0
var _animation_time := 0.0
var _day_elapsed := 0.0
var _actor_elapsed := 0.0
var _daylight_updates := 0
var _actor_updates := 0
var _activity_updates := 0
var _active_townsfolk := 0
var _active_animals := 0

func configure(city: Node3D, layout: Resource) -> void:
	_city = city
	_layout = layout

func _ready() -> void:
	name = "SanctuaryAmbience"
	set_meta("dynamic_visual", true)
	add_to_group("visual_quality")
	if not is_instance_valid(_city):
		_city = get_parent() as Node3D
	if is_instance_valid(_city):
		var world_environment := _city.get_node_or_null("EnchantedEnvironment") as WorldEnvironment
		if world_environment != null:
			_environment = world_environment.environment
		_key = _city.get_node_or_null("WarmKey") as DirectionalLight3D
	_palette = Style.palette()
	_cube = BoxMesh.new()
	_cube.size = Vector3.ONE
	_round = SphereMesh.new()
	_round.radius = 0.5
	_round.height = 1.0
	_round.radial_segments = 8
	_round.rings = 3
	_skin = _material(Color("bc9874"))
	_fur = _material(Color("a9a99a"))
	for index in range(MAX_TOWNSFOLK):
		_build_resident(index)
	for index in range(MAX_ANIMALS):
		_build_hare(index)
	_audio = AudioStreamPlayer.new()
	_audio.name = "OptionalGardenWind"
	_audio.volume_db = -32.0
	add_child(_audio)
	_apply_daylight()
	var settings := get_node_or_null("/root/VisualSettings")
	if settings != null and settings.has_method("apply_to"):
		settings.apply_to(self)
	else:
		_refresh_activity()

func apply_visual_settings(settings: Dictionary) -> void:
	_quality = clampi(int(settings.get("quality", 1)), 0, 2)
	_distance = clampf(float(settings.get("decoration_distance", 34.0)), 20.0, 60.0)
	_motion_scale = clampf(float(settings.get("decorative_motion_scale", 0.0 if settings.get("reduced_motion", false) else 1.0)), 0.0, 1.0)
	_sound_enabled = bool(settings.get("ambient_sound_enabled", false))
	# Freeze the current presentation pose and phase; no jump to another time.
	if _motion_scale <= 0.0:
		_day_elapsed = 0.0
		_actor_elapsed = 0.0
	_refresh_activity()
	if _sound_enabled:
		# A settings change followed by travel/teardown in the same frame must not
		# enqueue a new AudioServer playback that no live world will own.
		_sync_audio.call_deferred()
	else:
		_sync_audio()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_day_elapsed = 0.0
		_actor_elapsed = 0.0
		if _active_townsfolk > 0 or _active_animals > 0:
			_refresh_activity()
		_sync_audio()
		return
	if _motion_scale > 0.0:
		_phase = fposmod(_phase + delta * _motion_scale / DAY_SECONDS, 1.0)
		_animation_time += delta * _motion_scale
		_day_elapsed += delta
		if _day_elapsed >= DAY_INTERVAL:
			_day_elapsed = 0.0
			_apply_daylight()
	_actor_elapsed += delta
	if _actor_elapsed >= ACTOR_INTERVAL:
		_actor_elapsed = 0.0
		_refresh_activity()
		if _motion_scale > 0.0:
			_animate_actors()
		_sync_audio()

func _apply_daylight() -> void:
	var daylight := 0.5 - cos(_phase * TAU) * 0.5
	_night_amount = 1.0 - daylight
	if is_instance_valid(_city):
		_city.set_meta("presentation_night_amount", _night_amount)
	if _environment != null:
		_environment.ambient_light_energy = lerpf(0.60, 0.72, daylight)
		_environment.ambient_light_color = Color("718fa8").lerp(Color("8cb0b5"), daylight)
		_environment.background_color = Color("102139").lerp(Color("19313a"), daylight)
		# The static sky shader/resource stays untouched; only background intensity
		# changes, so the local cycle does not request radiance cubemap updates.
		_environment.background_energy_multiplier = lerpf(0.38, 1.0, daylight)
		_environment.fog_light_color = Color("193345").lerp(Color("1f3d40"), daylight)
	if is_instance_valid(_key):
		_key.light_energy = lerpf(0.45, 1.0, daylight)
		_key.light_color = Color("91adca").lerp(Color("edbd82"), daylight)
		_key.rotation_degrees = Vector3(lerpf(-32.0, -48.0, daylight), -28.0 + sin(_phase * TAU) * 10.0, 0)
	_daylight_updates += 1

func _build_resident(index: int) -> void:
	var resident := Node3D.new()
	resident.name = "LocalResident_%d" % index
	resident.add_to_group("city_ambient_actors")
	resident.set_meta("ambient_kind", &"townsfolk")
	add_child(resident)
	var clothing: Material = _palette[["cloth", "stone", "bronze", "wood"][index]]
	_part(resident, _round, Vector3(0, 0.98, 0), Vector3(0.42, 0.58, 0.25), clothing)
	_part(resident, _round, Vector3(0, 0.62, 0), Vector3(0.43, 0.22, 0.27), clothing)
	_part(resident, _cube, Vector3(0, 0.73, 0), Vector3(0.44, 0.065, 0.28), _palette.bronze)
	_part(resident, _round, Vector3(0, 1.43, 0), Vector3(0.29, 0.32, 0.29), _skin)
	_part(resident, _round, Vector3(0, 1.55, -0.025), Vector3(0.31, 0.17, 0.30), _palette.wood)
	var limbs: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.12, 0.54, 0)
		resident.add_child(leg)
		_part(leg, _round, Vector3(0, -0.25, 0), Vector3(0.14, 0.5, 0.17), _palette.dark_stone)
		limbs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.285, 1.2, 0)
		resident.add_child(arm)
		_part(arm, _round, Vector3(0, -0.23, 0), Vector3(0.12, 0.46, 0.14), clothing)
		limbs.append(arm)
	_part(resident, _round, Vector3(0.05, 0.92, -0.19), Vector3(0.21, 0.28, 0.14), _palette.wood)
	var angle := (float(index * 2) + 0.5) * TAU / 8.0
	resident.position = _route_position(angle, float(index) * 1.7)
	resident.rotation.y = -angle - PI / 2.0
	_actors.append({"node": resident, "kind": &"townsfolk", "index": index, "angle": angle, "offset": float(index) * 1.7, "limbs": limbs})

func _build_hare(index: int) -> void:
	var hare := Node3D.new()
	hare.name = "GardenHare_%d" % index
	hare.add_to_group("city_ambient_actors")
	hare.set_meta("ambient_kind", &"animal")
	add_child(hare)
	_part(hare, _round, Vector3(0, 0.19, 0), Vector3(0.27, 0.30, 0.40), _fur)
	_part(hare, _round, Vector3(0, 0.31, 0.2), Vector3(0.20, 0.22, 0.21), _fur)
	for side: float in [-1.0, 1.0]:
		var ear := _part(hare, _round, Vector3(side * 0.058, 0.51, 0.19), Vector3(0.055, 0.26, 0.065), _fur)
		ear.rotation.x = -0.18
		_part(hare, _round, Vector3(side * 0.115, 0.07, 0.08), Vector3(0.12, 0.12, 0.25), _fur)
	_part(hare, _round, Vector3(0, 0.24, -0.22), Vector3.ONE * 0.12, _palette.light_stone)
	var angle := (float(index * 2 + 1) + 0.5) * TAU / 8.0
	hare.position = _route_position(angle, float(index) * 2.3)
	hare.rotation.y = -angle - PI / 2.0
	_actors.append({"node": hare, "kind": &"animal", "index": index, "angle": angle, "offset": float(index) * 2.3, "limbs": []})

func _part(parent: Node3D, mesh: Mesh, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.scale = size
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part

func _material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.92
	return material

func _route_position(angle: float, cycle: float) -> Vector3:
	var theta := angle + sin(cycle * 0.17) * deg_to_rad(2.0)
	var radius := ACTOR_RADIUS + sin(cycle * 0.11) * 0.08
	return Vector3(sin(theta) * radius, 0, -cos(theta) * radius)

func _refresh_activity() -> void:
	if not is_inside_tree():
		return
	_viewer = null
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		if candidate is Node3D and candidate.get_viewport() == get_viewport():
			_viewer = candidate
			break
	if _viewer == null:
		_viewer = get_viewport().get_camera_3d()
	var viewer_position := global_position
	if is_instance_valid(_viewer):
		viewer_position = _viewer.global_position
	var candidates: Array[Dictionary] = []
	for actor: Dictionary in _actors:
		var node := actor.node as Node3D
		node.visible = false
		var distance := viewer_position.distance_squared_to(node.global_position)
		if is_visible_in_tree() and distance <= _distance * _distance:
			candidates.append({"actor": actor, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	_active_townsfolk = 0
	_active_animals = 0
	for candidate: Dictionary in candidates:
		var actor: Dictionary = candidate.actor
		var townsperson: bool = actor.kind == &"townsfolk"
		if townsperson and _active_townsfolk >= TOWNSFOLK_BUDGETS[_quality]:
			continue
		if not townsperson and _active_animals >= ANIMAL_BUDGETS[_quality]:
			continue
		actor.node.visible = true
		if townsperson:
			_active_townsfolk += 1
		else:
			_active_animals += 1
	_activity_updates += 1

func _animate_actors() -> void:
	for actor: Dictionary in _actors:
		var node := actor.node as Node3D
		if not node.visible:
			continue
		var cycle: float = _animation_time + float(actor.offset)
		node.position = _route_position(float(actor.angle), cycle)
		var forward := cos(cycle * 0.17)
		var tangent: float = -float(actor.angle) - PI / 2.0 if forward >= 0.0 else -float(actor.angle) + PI / 2.0
		node.rotation.y = lerp_angle(node.rotation.y, tangent, 0.12)
		if actor.kind == &"townsfolk":
			var gait := sin(cycle * 3.6) * 0.2 * absf(forward)
			var limbs: Array = actor.limbs
			for index in range(limbs.size()):
				limbs[index].rotation.x = gait * (1.0 if index in [0, 3] else -1.0)
		else:
			# A small hop stays in the authored decorative garden pocket.
			node.position.y = maxf(0.0, sin(cycle * 2.8)) * 0.055
	_actor_updates += 1

func _sync_audio() -> void:
	if not is_instance_valid(_audio):
		return
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			_audio.stop()
			return
		ancestor = ancestor.get_parent()
	if not _sound_enabled:
		if _audio.playing:
			_audio.stop()
		return
	if not is_visible_in_tree():
		_audio.stream_paused = true
		return
	if _audio.stream == null:
		_audio.stream = _make_wind_loop()
	_audio.stream_paused = false
	if not _audio.playing:
		_audio.play()

func _make_wind_loop() -> AudioStreamWAV:
	# Original periodic, low-pass noise. Two filter passes converge across the
	# loop seam. This one bounded sample is generated only on first enable.
	var sample_count := AUDIO_SAMPLE_RATE * AUDIO_SECONDS
	var random := RandomNumberGenerator.new()
	random.seed = 601071
	var noise := PackedFloat32Array()
	noise.resize(sample_count)
	for index in range(sample_count):
		noise[index] = random.randf_range(-1.0, 1.0)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	var smooth := 0.0
	for pass_index in range(2):
		for index in range(sample_count):
			smooth = lerpf(smooth, noise[index], 0.035)
			if pass_index == 0:
				continue
			var phase := float(index) * TAU / float(sample_count)
			var envelope := 0.7 + sin(phase) * 0.13 + cos(phase * 3.0) * 0.07
			var value := (smooth * 0.85 + noise[index] * 0.018) * envelope
			samples.encode_s16(index * 2, clampi(roundi(value * 25000.0), -32767, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = samples
	return stream

func get_presentation_snapshot() -> Dictionary:
	var actors: Array[Dictionary] = []
	for actor: Dictionary in _actors:
		var node := actor.node as Node3D
		actors.append({"name": String(node.name), "kind": actor.kind, "position": node.position, "visible": node.visible, "sector_angle": actor.angle})
	var allocated_bytes := 0
	if is_instance_valid(_audio) and _audio.stream is AudioStreamWAV:
		allocated_bytes = (_audio.stream as AudioStreamWAV).data.size()
	return {"phase": _phase, "night_amount": _night_amount, "cycle_seconds": DAY_SECONDS, "daylight_updates": _daylight_updates, "actor_updates": _actor_updates,
		"activity_updates": _activity_updates, "daylight_interval": DAY_INTERVAL, "actor_interval": ACTOR_INTERVAL,
		"active_townsfolk": _active_townsfolk, "active_animals": _active_animals, "allocated_townsfolk": MAX_TOWNSFOLK, "allocated_animals": MAX_ANIMALS,
		"townsfolk_cap": TOWNSFOLK_BUDGETS[_quality], "animal_cap": ANIMAL_BUDGETS[_quality], "motion_scale": _motion_scale,
		"optional_audio": _sound_enabled, "audio_playing": is_instance_valid(_audio) and _audio.playing and not _audio.stream_paused,
		"audio_allocated_bytes": allocated_bytes,
		"actors": actors, "uses_existing_environment": _environment != null, "uses_existing_light": is_instance_valid(_key)}

func _exit_tree() -> void:
	_sound_enabled = false
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null
