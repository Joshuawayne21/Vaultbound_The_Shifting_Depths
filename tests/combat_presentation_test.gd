extends "res://tests/test_harness.gd"
## Presentation budgets and readable depth-tested cues are independent of combat.
const Presentation = preload("res://scripts/visual/combat_presentation.gd")
const Burst = preload("res://scripts/combat/pulse_effect.gd")
const Projectile = preload("res://scripts/combat/projectile.gd")
const Avatar = preload("res://scripts/player/player_avatar.gd")
const Settings = preload("res://scripts/visual/visual_settings.gd")
var world: Node3D
var settings: Node

func _initialize() -> void:
	suite_name = "VAULTBOUND COMBAT PRESENTATION"
	_run.call_deferred()

func _run() -> void:
	settings = root.get_node_or_null("VisualSettings")
	if settings == null:
		settings = Settings.new()
		settings.name = "VisualSettings"
		settings.storage_path = "/tmp/vaultbound-m55-combat-visual-prefs.cfg"
		root.add_child(settings)
	var original_quality: int = settings.current_quality
	Engine.max_fps = 120
	world = Node3D.new()
	root.add_child(world)
	_warning_geometry()
	for quality in range(3):
		settings.current_quality = quality
		await _bounded_bursts(quality)
		_projectile_and_avatar(quality)
	settings.current_quality = original_quality
	world.queue_free()
	# Let the audio server retire the final 120 ms placeholder voice as well.
	await seconds(0.2)
	check(get_nodes_in_group("combat_visual_bursts").is_empty(), "Freeing the visual owner clears all transient burst instances")
	finish()

func _warning_geometry() -> void:
	var circle := Presentation.warning_mesh()
	var cone := Presentation.warning_mesh(0.78)
	var circle_box := circle.get_aabb()
	var cone_box := cone.get_aabb()
	check(circle.get_surface_count() == 1 and cone.get_surface_count() == 1, "Each boss footprint retains one pooled draw surface")
	check(is_equal_approx(circle_box.size.x, 2.0) and is_equal_approx(circle_box.size.z, 2.0), "Circular warning keeps the exact unit-radius footprint")
	check(cone_box.size.x <= sin(0.78) * 2.0 + 0.0001 and cone_box.position.z >= -1.0001 and cone_box.end.z <= 0.0001, "Cone border and notches stay inside the original cone")
	check(circle_box.size.y < 0.001 and cone_box.size.y < 0.001, "Warnings remain ground geometry rather than tall opaque obstructions")
	var material := Presentation.unlit(Color.ORANGE, true)
	check(not material.no_depth_test and material.vertex_color_use_as_albedo, "Warning colors preserve depth testing and per-vertex edge contrast")

func _bounded_bursts(quality: int) -> void:
	var budget := Presentation.burst_limit(world)
	var spawned: Array[Node3D] = []
	for index in range(budget + 5):
		var burst := Burst.new()
		burst.radius = 0.5
		burst.duration = 2.0
		world.add_child(burst)
		spawned.append(burst)
	await frames(1)
	var live := get_nodes_in_group("combat_visual_bursts")
	check(live.size() == budget, "Quality %d enforces its decorative burst cap" % quality)
	var expected_sparks: int = [0, 6, 10][quality]
	var safe := true
	for burst: Node3D in live:
		safe = safe and burst._spark_count == expected_sparks and not burst._material.no_depth_test
		var ring := burst.get_node("ImpactRing") as MeshInstance3D
		safe = safe and ring.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if expected_sparks > 0:
			safe = safe and burst._sparks.multimesh.instance_count == expected_sparks
		burst._process(3.0)
	check(safe, "Quality %d keeps ring cues and bounded batched sparks without shadows or wall vision" % quality)
	await frames(1)
	check(get_nodes_in_group("combat_visual_bursts").is_empty(), "Quality %d burst lifetimes release their entire spark batch" % quality)

func _projectile_and_avatar(quality: int) -> void:
	var source := Node3D.new()
	world.add_child(source)
	var bolt := Projectile.new()
	bolt.configure(source, Vector3.FORWARD, 17.0, 12.0, 2.0, 42, &"combat_targets", Color.CYAN, 0.0, 0.1)
	world.add_child(bolt)
	bolt.set_physics_process(false)
	check(bolt.damage == 17.0 and bolt.attack_id == 42 and bolt.direction == Vector3.FORWARD and bolt.speed == 12.0, "Quality %d does not change projectile authority data" % quality)
	check(bolt.has_node("SpellCore") and bolt.has_node("BoltWake") == (quality > 0), "Quality %d keeps the bolt core and scales only its decorative wake" % quality)
	var avatar := Avatar.new()
	world.add_child(avatar)
	avatar.apply_visual_settings({"quality": quality})
	avatar.set_combat_pose(&"active", 0.4, 0, 0.0, false)
	avatar.animate(0.016, 0.0, 0.2, 0.0)
	check(avatar._slash.visible and not avatar._slash_material.no_depth_test, "Quality %d retains the sword strike cue with wall occlusion" % quality)
	avatar.set_combat_pose(&"dodge", 0.3, 0, 0.0, false)
	avatar.animate(0.016, 0.0, 0.0, 0.2)
	check(not avatar._slash.visible and avatar._dodge_wake.visible == (quality > 0), "Quality %d separates dodge ribbons from the weapon strike cue" % quality)
	avatar.set_weapon(&"staff")
	avatar.set_combat_pose(&"charging", 0.5, 0, 0.5, false)
	avatar.animate(0.016, 0.0, 0.0, 0.0)
	check(avatar._cast_ring.visible == (quality > 0) and not avatar._dodge_wake.visible, "Quality %d shows a bounded staff channel rune and clears dodge ribbons" % quality)
	avatar.set_combat_pose(&"idle", 0, 0, 0.0, false)
	avatar.animate(0.016, 0.0, 0.0, 0.0)
	check(not avatar._cast_ring.visible and not avatar._slash.visible and not avatar._dodge_wake.visible, "Quality %d leaves no stale combat cues after recovery" % quality)
	bolt.queue_free()
	source.queue_free()
	avatar.queue_free()
