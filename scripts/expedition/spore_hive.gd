class_name RootSporeHive
extends StaticBody3D
## Stationary destructible objective. Deliberately never a monster/lifesteal target.
const Rules = preload("res://scripts/combat/combat_rules.gd")
var health := 160.0
var max_health := 160.0
var combat_active := false
var state: StringName = &"dormant"
var display_name := "Root Spore Hive"
var _director: WeakRef
var _hits: Dictionary = {}
var _visual: Node3D

func configure(director: Node3D, amount: float, materials: Dictionary) -> void:
	if _director != null or is_inside_tree(): return
	_director = weakref(director)
	health = amount
	max_health = amount
	collision_layer = 4 | 8 | 16
	collision_mask = 0
	disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.8
	shape.height = 1.8
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)
	var visual_script := load("res://scripts/visual/spore_hive_visual.gd") as Script
	if visual_script != null:
		_visual = visual_script.new()
		_visual.configure(materials)
		add_child(_visual)

func _ready() -> void:
	add_to_group("combat_targets")

func receive_hit(packet: Dictionary) -> bool:
	var owner := _director.get_ref() as Node3D if _director != null else null
	if not is_instance_valid(owner) or not owner.core_can_receive(self) or health <= 0.0 or not combat_active: return false
	var attack: Variant = packet.get("attack_id")
	var amount: Variant = packet.get("damage")
	var source_id: Variant = packet.get("source_id")
	if not attack is int or attack <= 0 or _hits.has(attack) or not source_id is int: return false
	if not (amount is float or amount is int) or not is_finite(float(amount)) or float(amount) <= 0.0: return false
	var source := instance_from_id(source_id) as Node3D
	if not owner.core_source_allowed(source): return false
	_hits[attack] = true
	if _hits.size() > 128: _hits.erase(_hits.keys()[0])
	health = maxf(0.0, health - float(amount))
	owner.core_hit(self)
	return true

func retire_body() -> void:
	collision_layer = 0
	combat_active = false
	state = &"dead"
	remove_from_group("combat_targets")
	if _visual != null: _visual.set_state(&"dead")

func present(next: StringName, delta: float) -> void:
	var visual_state: StringName = next
	if next == &"waiting": visual_state = &"active"
	elif next == &"resuming": visual_state = &"warning"
	elif next in [&"cancelled", &"complete"]: visual_state = &"paused"
	if health > 0.0: state = next
	if _visual != null:
		_visual.set_state(&"dead" if health <= 0.0 else visual_state)
		_visual.tick_visual(delta)
