extends Node3D
## Small shared mesh pulse and self-authored synthesized sound placeholder.
## No particle simulation, lights, imported audio, or third-party assets.

static var _tone: AudioStreamWAV
static var _last_sound_msec: int = 0
var tint := Color("eac37d")
var radius := 0.7
var duration := 0.3
var _age := 0.0
var _material: StandardMaterial3D

func _ready() -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.82
	mesh.outer_radius = 1.0
	mesh.rings = 16
	mesh.ring_segments = 4
	ring.mesh = mesh
	_material = StandardMaterial3D.new()
	_material.albedo_color = tint
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = _material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	scale = Vector3.ONE * radius * 0.2
	if Time.get_ticks_msec() - _last_sound_msec > 70:
		_last_sound_msec = Time.get_ticks_msec()
		_play_placeholder()

func _process(delta: float) -> void:
	_age += delta
	var progress := clampf(_age / duration, 0.0, 1.0)
	scale = Vector3.ONE * maxf(0.01, radius * lerpf(0.2, 1.0, progress))
	_material.albedo_color = Color(tint, 1.0 - progress)
	if progress >= 1.0:
		queue_free()

func _play_placeholder() -> void:
	if _tone == null:
		_tone = AudioStreamWAV.new()
		_tone.format = AudioStreamWAV.FORMAT_16_BITS
		_tone.mix_rate = 11025
		var samples := PackedByteArray()
		var sample_count := 1323
		samples.resize(sample_count * 2)
		for i in range(sample_count):
			var time := float(i) / 11025.0
			var envelope := pow(1.0 - float(i) / sample_count, 2.0)
			var value := int(sin(TAU * (230.0 * time - 450.0 * time * time)) * envelope * 9000.0)
			samples.encode_s16(i * 2, value)
		_tone.data = samples
	var sound := AudioStreamPlayer3D.new()
	sound.stream = _tone
	sound.volume_db = -15.0
	sound.max_distance = 24.0
	add_child(sound)
	sound.play()
