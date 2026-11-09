extends "res://tests/foyer_native_fixture.gd"
## Native sphere clearance, target sight and framing on both foyer storeys.
## Run default/--low/--high separately to bound each serial process duration.
const PROFILE := "/tmp/vaultbound-foyer-cameras/profile.json"
const SAMPLES := [Vector3(0, 0, 8), Vector3(0, 0, -6.5), Vector3(0, 0, 0),
	Vector3(6.2, 0, 9), Vector3(9.4246, 0.36, 8.7564), Vector3(11.4, 1.88, -2.2),
	Vector3(9.4246, 3.4, -13.1564), Vector3(6.2, 3.4, -15.2), Vector3(0, 3.4, -15.2),
	Vector3(-6.2, 3.4, -15.2), Vector3(-11.4, 1.88, -2.2), Vector3(-11.1564, 0.36, 7.0246)]
var camera_frames := 0
var minimum_distance := INF
var maximum_distance := 0.0
var retracted_frames := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND FOYER NATIVE CAMERAS"
	_run.call_deferred()

func _run() -> void:
	if await prepare_foyer(PROFILE): await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	game.party.set_paused(true)
	var settings := root.get_node("VisualSettings")
	settings.storage_path = "/tmp/vaultbound-foyer-cameras/graphics.cfg"
	var quality := 0 if OS.get_cmdline_user_args().has("--low") else 2 if OS.get_cmdline_user_args().has("--high") else 1
	var geometry := _geometry_signature()
	check(settings.set_options(quality, 60), "Requested native foyer graphics preset is supported")
	check(_geometry_signature() == geometry, "Graphics quality keeps every essential body, shape and collision layer identical")
	var rig: Node3D = game.camera_rig
	var identity := player.get_instance_id()
	for expected: Vector3 in SAMPLES:
		var actual := supported_position(expected)
		if not check(actual.is_finite() and absf(actual.y - expected.y - 0.15) < 0.025
			and native_capsule_clear(actual, 0.34), "Camera sample begins at its actual supported and clear walk height: " + str(expected)): return
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, actual))
		await frames(6)
		for pitch: float in [0.12, 0.98]:
			for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
				rig.is_isometric = false
				rig.orbit_yaw = yaw
				rig.orbit_pitch = pitch
				rig.reset_position()
				var clear := true
				var sight := true
				var framed := true
				var usable := true
				for transition in range(2):
					input_hub.request_action(&"camera_toggle")
					for frame in range(28):
						await physics_frame
						camera_frames += 1
						var pose := native_camera_pose()
						clear = clear and pose.clear
						sight = sight and pose.sight
						framed = framed and pose.framed
						usable = usable and pose.usable
						minimum_distance = minf(minimum_distance, float(pose.distance))
						maximum_distance = maxf(maximum_distance, float(pose.distance))
						if rig.obstruction_active: retracted_frames += 1
				check(clear and sight and framed and usable and not rig.is_isometric and rig.mode_blend < 0.01,
					"Both full camera transitions stay clear, see/frame the player and retain >=1m distance at %s / pitch%.2f / yaw%.2f / quality%d" % [expected, pitch, yaw, quality])
	check(camera_frames == SAMPLES.size() * 2 * 4 * 2 * 28 and player.get_instance_id() == identity,
		"Every supported foyer pose was observed through both complete transitions on the same player")
	check(_geometry_signature() == geometry, "Camera probing never disables or rewrites any actual world collision")
	await _reduced_motion(geometry)
	assert_secured_unchanged("All upper/lower camera transitions")
	print("FOYER CAMERA METRICS: ", JSON.stringify({"quality": quality, "native_transition_frames": camera_frames,
		"sample_positions": SAMPLES.size(), "minimum_camera_distance": minimum_distance,
		"maximum_camera_distance": maximum_distance, "legitimate_retraction_frames": retracted_frames}))

func _geometry_signature() -> Array:
	var result: Array = []
	for node: Node in foyer.find_children("*", "CollisionObject3D", true, false):
		var body := node as CollisionObject3D
		result.append([body.get_instance_id(), body.global_transform, body.collision_layer, body.collision_mask])
		for collider: Node in body.find_children("*", "CollisionShape3D", true, false):
			result.append([collider.get_instance_id(), collider.shape.get_instance_id(), collider.global_transform, collider.disabled])
	return result

func _reduced_motion(geometry: Array) -> void:
	var settings := root.get_node("VisualSettings")
	var sigil := foyer.get_node("CentralHouseSigil") as Node3D
	var chandelier := foyer.get_node("FoyerChandelier") as Node3D
	check(settings.set_accessibility(100, false, false), "Normal motion can be selected through the existing accessibility service")
	var normal_sigil := sigil.transform
	var normal_chandelier := chandelier.transform
	await frames(40)
	check(sigil.transform != normal_sigil and chandelier.transform != normal_chandelier,
		"Actual central sigil and high chandelier have bounded ambient movement")
	check(settings.set_accessibility(100, true, true), "Reduced motion and effects use the existing saved accessibility service")
	var still_sigil := sigil.transform
	var still_chandelier := chandelier.transform
	await frames(40)
	check(sigil.transform == still_sigil and chandelier.transform == still_chandelier,
		"Reduced motion freezes actual sigil and chandelier transforms")
	check(foyer._sigil_material.albedo_color.a <= 0.25 and _geometry_signature() == geometry,
		"Reduced effects soften the hologram without changing collisions or navigation")
