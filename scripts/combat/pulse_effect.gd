extends Node3D
## A thin impact ring and one batched spark spray. Decorative bursts are capped
## independently from damage; low quality retains the ring without spark work.
## No particle simulation, realtime lights or imported third-party assets.

const Presentation = preload("res://scripts/visual/combat_presentation.gd")

var tint := Color("eac37d")
var radius := 0.7
var duration := 0.3
var _age := 0.0
var _material: StandardMaterial3D
var _sparks: MultiMeshInstance3D
var _spark_count := 0
var _retired := false

func _ready() -> void:
	if get_tree().get_nodes_in_group("combat_visual_bursts").size() >= Presentation.burst_limit(self):
		_retired = true
		set_process(false)
		queue_free()
		return
	add_to_group("combat_visual_bursts")
	var ring := MeshInstance3D.new()
	ring.name = "ImpactRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.94
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 4
	ring.mesh = mesh
	_material = Presentation.unlit(tint, true)
	ring.material_override = _material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_spark_count = [0, 6, 10][Presentation.quality(self)]
	if _spark_count > 0:
		_create_sparks()
	scale = Vector3.ONE * radius * 0.2
	var sound_state := _sound_state()
	if Time.get_ticks_msec() - int(sound_state.last_sound_msec) > 70:
		sound_state.last_sound_msec = Time.get_ticks_msec()
		_play_placeholder(sound_state)

func _process(delta: float) -> void:
	if _retired:
		return
	_age += delta
	var progress := clampf(_age / duration, 0.0, 1.0)
	scale = Vector3.ONE * maxf(0.01, radius * lerpf(0.2, 1.0, 1.0 - pow(1.0 - progress, 2.0)))
	_material.albedo_color = Color(tint, pow(1.0 - progress, 1.4))
	if _sparks != null:
		for index in range(_spark_count):
			var angle := float(index) * TAU / _spark_count + 0.31
			var direction := Vector3(cos(angle), 0.5 + float(index % 3) * 0.25, sin(angle)).normalized()
			var basis := Basis(Quaternion(Vector3.UP, direction)).scaled(Vector3(0.025, 0.11 * (1.0 - progress) + 0.025, 0.025))
			_sparks.multimesh.set_instance_transform(index, Transform3D(basis, direction * (0.3 + progress * 0.8)))
	if progress >= 1.0:
		queue_free()

func _create_sparks() -> void:
	_sparks = MultiMeshInstance3D.new()
	_sparks.name = "BatchedImpactSparks"
	var batches := MultiMesh.new()
	batches.transform_format = MultiMesh.TRANSFORM_3D
	var shard := BoxMesh.new()
	shard.size = Vector3.ONE
	batches.mesh = shard
	batches.instance_count = _spark_count
	_sparks.multimesh = batches
	_sparks.material_override = _material
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)

func _sound_state() -> Dictionary:
	# Tree ownership releases the cached sample on shutdown; static Resource
	# variables can keep a transient effect script alive after its last instance.
	var tree := get_tree()
	if not tree.has_meta("vaultbound_combat_sound"):
		tree.set_meta("vaultbound_combat_sound", {"tone": null, "last_sound_msec": 0})
	return tree.get_meta("vaultbound_combat_sound")

func _play_placeholder(sound_state: Dictionary) -> void:
	var tone: AudioStreamWAV = sound_state.tone
	if tone == null:
		tone = AudioStreamWAV.new()
		tone.format = AudioStreamWAV.FORMAT_16_BITS
		tone.mix_rate = 11025
		var samples := PackedByteArray()
		var sample_count := 1323
		samples.resize(sample_count * 2)
		for i in range(sample_count):
			var time := float(i) / 11025.0
			var envelope := pow(1.0 - float(i) / sample_count, 2.0)
			var value := int(sin(TAU * (230.0 * time - 450.0 * time * time)) * envelope * 9000.0)
			samples.encode_s16(i * 2, value)
		tone.data = samples
		sound_state.tone = tone
	var sound := AudioStreamPlayer3D.new()
	sound.stream = tone
	sound.volume_db = -15.0
	sound.max_distance = 24.0
	add_child(sound)
	sound.play()
