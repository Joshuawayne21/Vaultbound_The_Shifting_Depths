class_name VaultItemPresentationBudget
extends Node
## One presentation-only scheduler. Preview worlds never register here.
## Item sparks share half the ambient preset budget (4/8/12), maximum 3 each.

static var _instance: WeakRef
var _remaining := 0.0
var _last_count := 0

static func ensure(tree: SceneTree) -> void:
	if _instance != null and is_instance_valid(_instance.get_ref()):
		return
	var manager := VaultItemPresentationBudget.new()
	manager.name = "ItemPresentationBudget"
	_instance = weakref(manager)
	tree.root.add_child.call_deferred(manager)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("item_presentation_budget")

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining > 0.0:
		return
	_remaining = 0.25
	refresh()

func refresh() -> void:
	var settings := get_node_or_null("/root/VisualSettings")
	var options: Dictionary = settings.snapshot() if settings != null else {}
	var budget := clampi(int(options.get("ambient_budget", 16)) / 2, 0, 12)
	if bool(options.get("reduced_effects", false)) or bool(options.get("reduced_motion", false)):
		budget = 0
	var camera := get_viewport().get_camera_3d()
	var viewer: Node3D = null
	for player: Node in get_tree().get_nodes_in_group("player"):
		if player is Node3D and player.get_viewport() == get_viewport():
			viewer = player
			break
	if viewer == null:
		viewer = camera
	var candidates: Array[Dictionary] = []
	for component: Node3D in get_tree().get_nodes_in_group("item_presentations"):
		var distance := INF
		if is_instance_valid(viewer) and component.get_world_3d() == viewer.get_world_3d():
			distance = viewer.global_position.distance_squared_to(component.global_position)
		var nearby := component.is_visible_in_tree() and distance <= pow(minf(20.0, float(options.get("decoration_distance", 34.0))), 2.0)
		if nearby and camera != null:
			nearby = camera.is_position_in_frustum(component.global_position)
		component.set_world_activity(nearby, 0)
		if nearby:
			candidates.append({"component": component, "distance": distance, "allocated": 0})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	_last_count = 0
	# Fair first pass gives each nearby display one spark before adding extras.
	for pass_index in range(3):
		for candidate: Dictionary in candidates:
			if budget <= 0:
				break
			var component: Node3D = candidate.component
			if component.requested_sparks() > pass_index:
				candidate.allocated += 1
				budget -= 1
				_last_count += 1
	for candidate: Dictionary in candidates:
		candidate.component.set_world_activity(true, int(candidate.allocated))

func snapshot() -> Dictionary:
	return {"allocated_sparks": _last_count, "maximum_sparks": 12, "interval": 0.25}
