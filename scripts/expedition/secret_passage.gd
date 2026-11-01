extends Node3D
## Optional roots conceal a side chamber; opening never gates the required route.
signal revealed(room_id: int)
var interaction_radius := 3.0
var target_room_id := -1
var opened := false
var _barrier: StaticBody3D
var _visual: Node3D
var _level: WeakRef
var _generation := -1

func _ready() -> void:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("can_use_run_source"):
			_level = weakref(ancestor)
			_generation = int(ancestor.run_generation)
			break
		ancestor = ancestor.get_parent()
	add_to_group("interactables")
	add_to_group("secret_passages")
	_visual = Node3D.new()
	add_child(_visual)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("315746")
	material.roughness = 0.9
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("83dcb5")
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in range(7):
		var branch := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.32, 3.6, 0.45)
		branch.mesh = mesh
		branch.material_override = material if index % 3 != 0 else glow
		branch.position = Vector3(-2.6 + index * 0.86, 1.8, 0)
		branch.rotation.z = 0.12 if index % 2 == 0 else -0.12
		_visual.add_child(branch)
	_barrier = StaticBody3D.new()
	_barrier.collision_layer = 1
	_barrier.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 4.0, 0.5)
	collision.shape = box
	collision.position.y = 2.0
	_barrier.add_child(collision)
	add_child(_barrier)
	var label := Label3D.new()
	label.text = "WHISPERING ROOTS"
	label.font_size = 28
	label.pixel_size = 0.006
	label.modulate = Color("badab4")
	label.position.y = 3.7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual.add_child(label)

func get_prompt() -> String:
	return "Reveal the hidden passage" if not opened else "Passage revealed"

func can_interact(player: Node3D) -> bool:
	var level := _level.get_ref() as Node3D if _level != null else null
	var excluded: Array[RID] = []
	if is_instance_valid(_barrier): excluded.append(_barrier.get_rid())
	return not opened and is_instance_valid(level) and int(level.run_generation) == _generation \
		and level.can_use_run_source(self, player, interaction_radius, excluded)

func interact(player: Node3D) -> void:
	if not can_interact(player): return
	opened = true
	_barrier.set_deferred("collision_layer", 0)
	_visual.visible = false
	remove_from_group("interactables")
	revealed.emit(target_room_id)
