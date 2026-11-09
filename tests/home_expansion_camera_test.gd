extends "res://tests/home_expansion_fixture.gd"
## The shipped camera rig is loaded after autoload startup. Every authored route
## sample uses both compositions; full transitions are observed beside scenery.
var _rig: Node3D
var _target: Node3D
var _camera_samples := 0
var _transition_frames := 0
var _minimum_distance := INF
var _room_metrics: Dictionary = {}

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND HOME EXPANSION CAMERAS"
	_run.call_deferred()

func _run() -> void:
	if not prepare_profile():
		restore_profile()
		finish()
		return
	# Deliberately resolve the real packed rig here. Strongly preloading its
	# script in a standalone fixture can compile InputHub before autoload setup.
	var packed := load("res://scenes/player/camera_rig.tscn") as PackedScene
	if not check(packed != null, "Actual shared camera rig loads after project autoloads initialize"):
		restore_profile()
		finish()
		return
	_target = Node3D.new()
	_target.name = "NativeCameraSubject"
	root.add_child(_target)
	_rig = packed.instantiate() as Node3D
	root.add_child(_rig)
	_rig.set_target(_target)
	var settings: Node = root.get_node("VisualSettings")
	var original_quality: int = settings.current_quality
	for room_id: String in ROOM_IDS:
		if not await open_room(room_id, false): break
		var collision := collision_signature()
		var layout: Dictionary = world.room_layout()
		var samples: Array[Vector3] = []
		for point: Vector3 in layout.camera_points:
			var at := Vector3(point.x, 0, point.z)
			if not samples.has(at): samples.append(at)
		if room_id == "rooftop_garden":
			# Real walkable views near the parapets test the outside panorama and
			# canopy boundary, not only the unobstructed garden center.
			samples.append(Vector3(-12.2, 0, -6.5))
			samples.append(Vector3(12.2, 0, -6.5))
		var all_supported := true
		for at: Vector3 in samples: all_supported = floor_clear(at, true) and all_supported
		if not check(all_supported, "All camera subjects occupy real grounded, capsule-clear room approaches: " + room_id):
			await close_room()
			continue
		var metrics := {"positions": samples.size(), "static_poses": 0, "transition_frames": 0, "minimum_distance": INF}
		for quality in range(3):
			settings.current_quality = quality
			settings.apply_to(world)
			await frames(2)
			check(collision_signature() == collision, "Actual graphics preset preserves all essential collision and visibility boundaries: " + room_id + "/" + str(quality))
			for at: Vector3 in samples:
				_target.position = at
				var clear := true
				var framed := true
				for yaw: float in [0.0, PI * 0.5, PI, PI * 1.5]:
					_rig.is_isometric = false
					_rig.orbit_yaw = yaw
					_rig.orbit_pitch = 0.32
					_rig.reset_position()
					var pose := _pose()
					clear = bool(pose.clear) and bool(pose.sight) and bool(pose.usable) and clear
					framed = bool(pose.framed) and framed
					metrics.minimum_distance = minf(metrics.minimum_distance, pose.distance)
					metrics.static_poses += 1
				_rig.is_isometric = true
				_rig.reset_position()
				var isometric := _pose()
				clear = bool(isometric.clear) and bool(isometric.sight) and bool(isometric.usable) and clear
				framed = bool(isometric.framed) and framed
				metrics.minimum_distance = minf(metrics.minimum_distance, isometric.distance)
				metrics.static_poses += 1
				check(clear and framed, "Both native camera compositions retain clear sphere, line of sight, framing and >=0.5m distance: %s/%d/%s" % [room_id, quality, at])
			for at: Vector3 in _transition_points(room_id):
				if not check(floor_clear(at, true), "Transition subject is on a usable room route: " + room_id + str(at)): continue
				_target.position = at
				_rig.is_isometric = false
				_rig.orbit_yaw = PI * 0.5
				_rig.orbit_pitch = 0.32
				_rig.reset_position()
				var transition_clear := true
				for direction in range(2):
					_rig.toggle_mode()
					for frame in range(28):
						await physics_frame
						var pose := _pose()
						transition_clear = bool(pose.clear) and bool(pose.sight) and bool(pose.usable) and bool(pose.framed) and transition_clear
						metrics.minimum_distance = minf(metrics.minimum_distance, pose.distance)
						metrics.transition_frames += 1
						_transition_frames += 1
				check(transition_clear and not _rig.is_isometric and _rig.mode_blend < 0.01,
					"Full native camera transitions remain clear beside room architecture: %s/%d/%s" % [room_id, quality, at])
		check(metrics.static_poses == samples.size() * 5 * 3 and metrics.transition_frames == _transition_points(room_id).size() * 2 * 28 * 3,
			"Every declared composition and transition frame was sampled for all three presets: " + room_id)
		check(collision_signature() == collision and session.profile == source_profile,
			"Camera switching and all presets leave exact collision and secured ownership unchanged: " + room_id)
		_room_metrics[room_id] = metrics
		await close_room()
	settings.current_quality = original_quality
	_rig.set_target(null)
	_rig.queue_free()
	_target.queue_free()
	await frames(3)
	restore_profile()
	print("HOME EXPANSION CAMERA METRICS: ", JSON.stringify({"samples": _camera_samples,
		"transition_frames": _transition_frames, "minimum_distance": _minimum_distance, "rooms": _room_metrics}))
	finish()

func _transition_points(room_id: String) -> Array[Vector3]:
	if room_id in WORKROOM_IDS: return [Vector3(9.7, 0, -5), Vector3(-4, 0, 7)]
	if room_id == "rooftop_garden": return [Vector3(12.2, 0, -6.5), Vector3(5.6, 0, -5.6)]
	return [Vector3(5.6, 0, -5.6), Vector3(0, 0, 7)]

func _pose() -> Dictionary:
	_camera_samples += 1
	var anchor := _target.global_position + Vector3.UP * 1.35
	var camera: Camera3D = _rig.camera
	var eye := camera.global_position
	var distance := anchor.distance_to(eye)
	_minimum_distance = minf(_minimum_distance, distance)
	var shape := SphereShape3D.new()
	shape.radius = 0.23
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1 | 8
	query.collide_with_areas = false
	query.transform.origin = eye
	var space := world.get_world_3d().direct_space_state
	var overlaps := space.intersect_shape(query, 4)
	var ray := PhysicsRayQueryParameters3D.create(eye, anchor, 1 | 8)
	ray.collide_with_areas = false
	var obstruction := space.intersect_ray(ray)
	var framed := not camera.is_position_behind(anchor) and camera.get_viewport().get_visible_rect().has_point(camera.unproject_position(anchor))
	var result := {"clear": eye.is_finite() and overlaps.is_empty(), "sight": obstruction.is_empty(),
		"framed": framed, "distance": distance, "usable": distance >= 0.5}
	if not result.clear or not result.sight or not result.framed or not result.usable:
		var paths: Array[String] = []
		for hit: Dictionary in overlaps: paths.append(str(hit.collider.get_path()))
		print("HOME EXPANSION CAMERA FAILURE: ", JSON.stringify({"room": world.room_id, "target": str(_target.position),
			"eye": str(eye), "isometric": _rig.is_isometric, "yaw": _rig.orbit_yaw, "distance": distance,
			"overlaps": paths, "ray_body": str(obstruction.collider.get_path()) if not obstruction.is_empty() else "", "framed": framed}))
	return result
