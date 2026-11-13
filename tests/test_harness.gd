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

func enter_nexus_from_sanctuary() -> bool:
	# Test setup still uses the authored source, shared reviewed card and native
	# touch path. It never substitutes direct change_location or edits ownership.
	if game.current_location == &"realm_nexus" and not game.transitioning:
		return true
	if not check(game.current_location == &"sanctuary" and not game.transitioning,
		"Nexus setup starts in the actual Sanctuary or its already loaded hall"):
		return false
	game.hud.close_modals()
	var gate := portal_to(&"realm_nexus")
	if not check(gate != null and gate.get_parent() == game.active_world and gate.require_entry_card,
		"Sanctuary exposes the real reviewed Nexus entrance"):
		return false
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY,
		game.active_world.get_poi_approach_position(&"rootbound_abyss") + Vector3.UP * 0.15))
	await frames(4)
	if not check(game.player.interaction_target == gate and game._city_source_valid(gate),
		"Retained northern approach reaches the authored Nexus entrance"):
		return false
	input_hub.request_action(&"interact")
	var overlay: Control = game.hud.expedition_overlay
	var panel: Control = overlay.sanctuary_panel
	if not check(overlay.mode == &"sanctuary" and panel.kind == &"portal" and panel.entry_enabled,
		"Real city interaction opens the source-bound Nexus review"):
		return false
	var at: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 1901, at, true)
	touch(overlay, 1901, at, false)
	return await arrive(&"realm_nexus")

func sanctuary_service_approach(service: Node) -> Vector3:
	var service_id := StringName(service.get("vendor")) if service.get("service_kind") == &"merchant" else StringName(service.get("service_kind"))
	return game.active_world.get_service_approach_position(service_id) + Vector3.UP * 0.15

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
