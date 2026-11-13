extends Area3D
## Original passive native overlap source. Only Session can advance the puzzle.
const Architecture = preload("res://scripts/world/architecture.gd")
var _world: WeakRef
var _generation := -1
var _source: Dictionary = {}
var _shape: CollisionShape3D
var _ring: MeshInstance3D
var _label: Label3D
var _accepted := false

func configure(world: Node3D, row: Dictionary, generation: int) -> bool:
	if is_inside_tree() or _world != null or not is_instance_valid(world) or generation < 0: return false
	_world = weakref(world)
	_source = row.duplicate(true)
	_generation = generation
	return true

func identity_snapshot() -> Dictionary:
	return {"slot_id": String(_source.get("slot_id", "")), "kind": String(_source.get("kind", "")), "generation": _generation}

func source_configuration_matches(row: Dictionary, generation: int) -> bool: return generation == _generation and row == _source

func _ready() -> void:
	if _source.is_empty(): return
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	_shape = CollisionShape3D.new()
	_shape.name = "OriginalPlateFootprint"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.8
	cylinder.height = 0.4
	_shape.shape = cylinder
	_shape.position.y = 0.2
	add_child(_shape)
	var kit := Architecture.new(self)
	kit.cylinder(Vector3(0, 0.052, 0), 0.8, 0.026, "dark_stone", false, 20)
	_ring = kit.ring(Vector3(0, 0.068, 0), 0.70, 0.77, "gold")
	var rune := String(_source.slot_id).trim_prefix("plate_").to_upper()
	_label = kit.label(rune, Vector3(0, 0.6, 0), 25, Color("e8c879"))
	_label.pixel_size = 0.0038
	set_meta("native_placeholder_art", true)

func native_footprint_valid() -> bool:
	return is_instance_valid(_shape) and _shape.get_parent() == self and not _shape.disabled \
		and _shape.position == Vector3(0, 0.2, 0) and _shape.rotation == Vector3.ZERO and _shape.scale == Vector3.ONE \
		and _shape.shape is CylinderShape3D and is_equal_approx(_shape.shape.radius, 0.8) \
		and is_equal_approx(_shape.shape.height, 0.4) and collision_layer == 0 and collision_mask == 2 and monitoring and not monitorable

func set_accepted(value: bool) -> void:
	if value == _accepted: return
	_accepted = value
	if is_instance_valid(_label): _label.modulate = Color("8ef1d9") if value else Color("e8c879")
