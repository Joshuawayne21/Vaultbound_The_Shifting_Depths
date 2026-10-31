extends SceneTree
## Shared headless integration helpers. No game implementation is replaced by mocks.

var failures: Array[String] = []
var checks := 0
var game: Node3D
var input_hub: Node
var suite_name := "VAULTBOUND"

func boot_game() -> bool:
	input_hub = root.get_node_or_null("InputHub")
	if not check(input_hub != null, "InputHub autoload exists"):
		return false
	var packed := load("res://scenes/main.tscn") as PackedScene
	if not check(packed != null, "Main scene loads"):
		return false
	game = packed.instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	return await arrive(&"sanctuary")

func resources_load(path: String) -> void:
	var directory := DirAccess.open(path)
	if not check(directory != null, "Resource directory opens: " + path):
		return
	for folder: String in directory.get_directories():
		resources_load(path.path_join(folder))
	for file: String in directory.get_files():
		if file.get_extension() in ["tscn", "gd", "tres"]:
			var resource := load(path.path_join(file))
			check(resource != null, "Resource loads: " + path.path_join(file))

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func seconds(duration: float) -> void:
	await create_timer(duration, false, true).timeout

func eventually(predicate: Callable, timeout: float = 4.0) -> bool:
	for i in range(int(ceil(timeout * Engine.physics_ticks_per_second))):
		await physics_frame
		if predicate.call():
			return true
	return false

func arrive(destination: StringName) -> bool:
	var success := await eventually(func() -> bool: return game.current_location == destination and not game.transitioning)
	return check(success, "Arrived in " + String(destination))

func portal_to(destination: StringName) -> Node3D:
	for portal: Node in get_nodes_in_group("interactables"):
		if portal.get("destination") == destination:
			return portal as Node3D
	return null

func touch(surface: Control, index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = surface.get_global_transform_with_canvas() * point
	event.pressed = pressed
	event.canceled = canceled
	surface._input(event)

func drag(surface: Control, index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = surface.get_global_transform_with_canvas() * point
	event.relative = surface.get_global_transform_with_canvas().basis_xform(relative)
	surface._input(event)

func obstacle(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	game.add_child(body)
	body.global_position = at
	return body

func check(condition: bool, description: String) -> bool:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
	return condition

func finish() -> void:
	Input.action_release("move_forward")
	if failures.is_empty():
		print("%s CHECKS PASSED: %d" % [suite_name, checks])
	else:
		print("%s CHECKS FAILED: %d / %d" % [suite_name, failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
