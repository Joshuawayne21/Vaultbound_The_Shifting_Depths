class_name AbyssHazard
extends Node3D
## Two reusable hazards per expedition. A generous ground telegraph precedes damage.
signal finished
var active := false
var state: StringName = &"idle"
var radius := 2.0
var damage := 12.0
var room_id := -1
var _remaining := 0.0
var _windup := 2.0
var _attack_id := 0
var _ring: MeshInstance3D
var _thorns: Node3D
var _material: StandardMaterial3D

func _ready() -> void:
	add_to_group("abyss_hazards")
	add_to_group("combat_telegraphs")
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color("dc965f")
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring.material_override = _material
	_ring.position.y = 0.09
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_thorns = Node3D.new()
	add_child(_thorns)
	var thorn_mesh := CylinderMesh.new()
	thorn_mesh.top_radius = 0.0
	thorn_mesh.bottom_radius = 0.16
	thorn_mesh.height = 1.2
	thorn_mesh.radial_segments = 5
	thorn_mesh.rings = 1
	for index in range(7):
		var thorn := MeshInstance3D.new()
		thorn.mesh = thorn_mesh
		thorn.material_override = _material
		thorn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * index / 7.0
		thorn.position = Vector3(sin(angle) * 0.65, 0.5, cos(angle) * 0.65)
		_thorns.add_child(thorn)
	cancel()

func trigger(at: Vector3, owner_room: int, warning_time: float = 2.0, size: float = 2.0, amount: float = 12.0) -> bool:
	if active:
		return false
	global_position = at
	room_id = owner_room
	radius = size
	damage = amount
	_windup = maxf(1.5, warning_time)
	_remaining = _windup
	active = true
	state = &"warning"
	visible = true
	_ring.visible = true
	_ring.scale = Vector3.ONE * radius
	_thorns.visible = false
	return true

func cancel() -> void:
	active = false
	state = &"idle"
	visible = false
	if _thorns != null:
		_thorns.visible = false

func _physics_process(delta: float) -> void:
	if not active:
		return
	var members := CombatRules.party_targets(self)
	if members.is_empty():
		return
	_remaining -= delta
	if state == &"warning":
		_material.albedo_color = Color("e9c56b").lerp(Color("d8664f"), 1.0 - _remaining / _windup)
		if _remaining <= 0.0:
			state = &"impact"
			_remaining = 0.45
			_thorns.visible = true
			_thorns.scale = Vector3(radius, 1.0, radius)
			_attack_id = CombatRules.next_attack_id()
			for member: Node3D in members:
				var offset := member.global_position - global_position
				offset.y = 0.0
				if offset.length() <= radius and CombatRules.has_line_of_sight(self, member):
					CombatRules.apply_hit(self, member, damage, _attack_id, &"roots", 0.2)
	elif _remaining <= 0.0:
		cancel()
		finished.emit()

func get_danger_zones() -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	if active:
		zones.append({"position": global_position, "radius": radius,
			"remaining": _remaining if state == &"warning" else 0.0, "kind": &"roots"})
	return zones
