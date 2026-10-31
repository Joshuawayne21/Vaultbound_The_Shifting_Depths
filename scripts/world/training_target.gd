extends Node3D
## Passive practice target. It never attacks and restores itself after defeat.

signal hit_received(damage: float)

@export var max_health: float = 100.0
var health: float = 100.0
var _visuals: Node3D
var _health_label: Label3D
var _hit_label: Label3D
var _armor: StandardMaterial3D
var _flash_remaining: float = 0.0
var _reset_remaining: float = 0.0


func _ready() -> void:
	add_to_group("combat_targets")
	health = max_health
	_visuals = Node3D.new()
	_visuals.name = "SentinelVisuals"
	add_child(_visuals)
	var wood := _material(Color("665240"))
	var stone := _material(Color("374b58"))
	_armor = _material(Color("809499"))
	var gold := _material(Color("bda269"))
	var eye := _material(Color("85d8cd"))
	eye.emission_enabled = true
	eye.emission = Color("4dbbab")
	_box(Vector3(0, 0.12, 0), Vector3(1.3, 0.24, 1.0), stone)
	_box(Vector3(0, 1.15, 0), Vector3(0.23, 1.9, 0.24), wood)
	_box(Vector3(0, 1.52, 0), Vector3(1.65, 0.16, 0.18), wood)
	_box(Vector3(0, 1.42, 0.04), Vector3(0.73, 0.9, 0.47), _armor)
	_box(Vector3(0, 1.4, 0.29), Vector3(0.12, 0.65, 0.05), gold)
	_box(Vector3(0, 1.4, 0.31), Vector3(0.55, 0.12, 0.06), gold)
	_box(Vector3(0, 1.02, 0.04), Vector3(0.81, 0.12, 0.51), gold)
	_box(Vector3(0, 2.03, 0), Vector3(0.52, 0.44, 0.5), stone)
	_box(Vector3(0, 2.07, 0.26), Vector3(0.36, 0.07, 0.03), eye)
	for side in [-1.0, 1.0]:
		var shoulder := _box(Vector3(side * 0.58, 1.74, 0), Vector3(0.36, 0.3, 0.5), _armor)
		shoulder.rotation.z = side * -0.16
		_box(Vector3(side * 0.77, 1.37, 0), Vector3(0.2, 0.43, 0.25), wood)
		_box(Vector3(side * 0.21, 0.58, 0), Vector3(0.24, 0.63, 0.27), wood)
		_box(Vector3(side * 0.21, 0.33, 0.05), Vector3(0.29, 0.27, 0.36), stone)

	var body := StaticBody3D.new()
	body.name = "TargetCollision"
	body.collision_layer = 4
	body.collision_mask = 1
	add_child(body)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 2.3
	collider.shape = capsule
	collider.position.y = 1.15
	body.add_child(collider)
	_health_label = _label(2.8, 30, Color("d8e5d9"))
	_hit_label = _label(2.43, 40, Color("f1cc7d"))
	_update_label()


func take_hit(damage: float, _from: Vector3) -> void:
	if health <= 0.0 or damage <= 0.0:
		return
	health = maxf(0.0, health - damage)
	_flash_remaining = 0.35
	_armor.emission_enabled = true
	_armor.emission = Color("e5a562")
	_armor.emission_energy_multiplier = 0.7
	_visuals.rotation.x = -0.14
	_hit_label.text = "−%d" % int(damage)
	_hit_label.position.y = 2.43
	hit_received.emit(damage)
	if health <= 0.0:
		_reset_remaining = 2.0
		_hit_label.text = "RESTORING"
	_update_label()


func _process(delta: float) -> void:
	_visuals.rotation.x = lerpf(_visuals.rotation.x, 0.0, minf(delta * 7.0, 1.0))
	if _flash_remaining > 0.0:
		_flash_remaining -= delta
		_hit_label.position.y += delta * 0.65
		if _flash_remaining <= 0.0:
			_armor.emission_enabled = false
			if health > 0.0:
				_hit_label.text = ""
	if _reset_remaining > 0.0:
		_reset_remaining -= delta
		_visuals.scale.y = move_toward(_visuals.scale.y, 0.72, delta * 2.0)
		if _reset_remaining <= 0.0:
			health = max_health
			_hit_label.text = ""
			_update_label()
	else:
		_visuals.scale.y = move_toward(_visuals.scale.y, 1.0, delta * 2.0)


func _update_label() -> void:
	_health_label.text = "PRACTICE SENTINEL\n%d / %d" % [int(health), int(max_health)]


func _label(height: float, font_size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.position.y = height
	label.font_size = font_size
	label.pixel_size = 0.003
	label.outline_size = 7
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	return label


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func _box(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	_visuals.add_child(instance)
	return instance
