extends "res://tests/test_harness.gd"
## Presentation contracts only: no replacement combat controller or authority data.
const Avatar = preload("res://scripts/player/player_avatar.gd")
var world: Node3D

func _initialize() -> void:
	suite_name = "VAULTBOUND CHARACTER PRESENTATION"
	_run.call_deferred()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var avatar := Avatar.new()
	world.add_child(avatar)
	_geometry_and_anchors(avatar)
	_equipment_tints(avatar)
	_pose_contracts(avatar)
	_accessibility(avatar)
	_frame_rate_convergence()
	world.queue_free()
	await frames(2)
	finish()

func _meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_meshes(child, result)

func _geometry_and_anchors(avatar: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_meshes(avatar, meshes)
	var rounded_count := 0
	var triangles := 0
	var shared_mesh: Mesh
	var shared := true
	var body_bounds := AABB()
	var bounds_started := false
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh is PrimitiveMesh:
			triangles += mesh.mesh.get_faces().size() / 3
		if mesh.mesh is SphereMesh:
			rounded_count += 1
			if shared_mesh == null:
				shared_mesh = mesh.mesh
			shared = shared and mesh.mesh == shared_mesh
		if not avatar._body.is_ancestor_of(mesh) or avatar._sword.is_ancestor_of(mesh) or avatar._shield.is_ancestor_of(mesh) or avatar._staff.is_ancestor_of(mesh):
			continue
		var relative: Transform3D = avatar.global_transform.affine_inverse() * mesh.global_transform
		var bounds: AABB = relative * mesh.mesh.get_aabb()
		body_bounds = body_bounds.merge(bounds) if bounds_started else bounds
		bounds_started = true
	print("CHARACTER GEOMETRY: %d mesh instances, %d primitive triangles, %d shared rounded surfaces" % [meshes.size(), triangles, rounded_count])
	check(rounded_count >= 24 and shared, "Rounded body parts reuse one bounded smooth mesh")
	check(triangles <= 7000 and meshes.size() <= 80, "Full avatar including both weapon models stays within its geometry budget")
	check(body_bounds.position.y >= 0.0 and body_bounds.end.y <= 1.95 and body_bounds.size.x <= 1.2 and body_bounds.size.z <= 0.8, "Rest body remains grounded and within its original character envelope")
	check(avatar._left_leg.position == Vector3(-0.17, 0.65, 0) and avatar._right_leg.position == Vector3(0.17, 0.65, 0), "Both hip bind anchors remain compatible")
	check(avatar._left_arm.position == Vector3(-0.39, 1.25, 0) and avatar._right_arm.position == Vector3(0.39, 1.25, 0), "Both shoulder bind anchors remain compatible")
	check(avatar._sword.get_parent() == avatar._right_arm and avatar._sword.position == Vector3.ZERO and avatar._staff.get_parent() == avatar._right_arm and avatar._staff.position == Vector3(0, -0.50, -0.05), "Sword and staff retain the same right-hand attachments")
	check(avatar._shield.get_parent() == avatar._left_arm and avatar._shield.position == Vector3(-0.12, -0.34, -0.06), "Shield retains its left-hand attachment")
	var hand: MeshInstance3D = avatar._equipment_surfaces.gloves[3]
	var sword_grip: MeshInstance3D = avatar._sword.get_child(0)
	check(hand.position.distance_to(sword_grip.position) < 0.01, "Rounded hand still encloses the sword grip at rest")

func _equipment_tints(avatar: Node3D) -> void:
	var appearance := {
		"chest_armor": {"rarity": "epic", "enhancement": 3},
		"helmet": {"rarity": "rare", "enhancement": 2},
		"gloves": {"rarity": "uncommon", "enhancement": 1},
		"leg_armor": {"rarity": "rare"},
		"necklace": {"rarity": "legendary"},
		"ring": {"rarity": "mythic"},
		"accessory": {"rarity": "ancient_relic"}}
	avatar.set_equipment_appearance(appearance)
	var colors: Dictionary = {}
	for slot: String in ["helmet", "gloves", "leg_armor", "necklace", "ring", "accessory"]:
		var surface: MeshInstance3D = avatar._equipment_surfaces[slot][0]
		colors[slot] = surface.material_override.albedo_color
	for iteration in range(8):
		avatar.set_equipment_appearance(appearance)
	var stable := true
	for slot: String in colors:
		var surface: MeshInstance3D = avatar._equipment_surfaces[slot][0]
		stable = stable and surface.material_override.albedo_color.is_equal_approx(colors[slot])
	check(stable, "Repeated appearance refreshes do not compound rarity or chest tints")
	var other := Avatar.new()
	world.add_child(other)
	var other_armor_color: Color = other._armor.albedo_color
	avatar.set_equipment_appearance({"ring": {"rarity": "ancient_relic"}})
	check(other._armor.albedo_color.is_equal_approx(other_armor_color) and avatar._armor != other._armor, "Equipping one actor cannot recolor a companion or preview actor")
	avatar.set_equipment_appearance({})
	var reset := true
	for slot: String in colors:
		for surface: MeshInstance3D in avatar._equipment_surfaces[slot]:
			reset = reset and surface.material_override == avatar._surface_originals[surface.get_instance_id()]
	check(reset and avatar._equipment_appearance.is_empty(), "Unequipping restores the native surfaces without inventing equipped records")

func _pose_contracts(avatar: Node3D) -> void:
	avatar.apply_visual_settings({"quality": 1, "reduced_motion": true})
	avatar.set_combat_pose(&"idle", 0.0, 0, 0.0, true)
	var before: Quaternion = avatar._left_arm.quaternion
	avatar.animate(1.0 / 60.0, 0.0, 0.0, 0.0)
	var blocked := Quaternion.from_euler(Vector3(-1.1, 0, -0.65))
	check(before.angle_to(avatar._left_arm.quaternion) > 0.05 and avatar._left_arm.quaternion.angle_to(blocked) > 0.05, "Defensive pose starts promptly with a short visual blend")
	for frame in range(60):
		avatar.animate(1.0 / 60.0, 0.0, 0.0, 0.0)
	check(avatar._left_arm.quaternion.angle_to(blocked) < 0.002, "Blended defense settles into the expected shield pose")
	var stable := true
	for style: StringName in [&"sword", &"staff"]:
		avatar.begin_weapon_switch(style)
		stable = stable and avatar._staff.visible == (style == &"staff") and avatar._sword.visible == (style == &"sword") and avatar._shield.visible == (style == &"sword")
		for state: StringName in [&"idle", &"charging", &"windup", &"active", &"recovery", &"stagger", &"dead"]:
			for combo in range(3):
				for frame in range(31):
					var progress := float(frame) / 30.0
					avatar.set_combat_pose(state, progress, combo, progress, false)
					avatar.animate(1.0 / 30.0, 4.8 if state == &"idle" else 0.0, 0.0, 0.0)
					for part: Node3D in [avatar._body, avatar._left_arm, avatar._right_arm, avatar._left_leg, avatar._right_leg, avatar._staff, avatar._sword]:
						stable = stable and part.global_transform.is_finite() and part.global_basis.determinant() > 0.0
	check(stable, "Idle, locomotion, both weapons, all combos, cast, hit and death poses stay finite and non-reflected")
	avatar.set_weapon(&"sword")
	avatar.set_combat_pose(&"active", 0.4, 1, 0.0, false)
	avatar.animate(1.0 / 120.0, 0.0, 0.1, 0.0)
	check(avatar._slash.visible, "Strike cue timing remains immediate while the body blends")
	var full_roll := true
	for progress in [0.25, 0.5, 0.75, 1.0]:
		avatar.set_combat_pose(&"dodge", progress, 0, 0.0, false)
		avatar.animate(1.0 / 60.0, 0.0, 0.0, 0.1)
		var expected := Basis(Vector3.RIGHT, -TAU * progress)
		var center := Vector3(0, 0.78, 0)
		full_roll = full_roll and avatar._body.basis.is_equal_approx(expected) and avatar._body.position.is_equal_approx(center - expected * center)
	check(full_roll and not avatar._slash.visible, "Dodge preserves its entire waist-centered revolution without interpolation shortcuts")
	avatar.set_combat_pose(&"idle", 0, 0, 0, false)
	for frame in range(60):
		avatar.animate(1.0 / 60.0, 0, 0, 0)
	check(avatar._body.position.length() < 0.001 and avatar._body.quaternion.angle_to(Quaternion.IDENTITY) < 0.002, "Recovery leaves no residual roll or body offset")

func _accessibility(avatar: Node3D) -> void:
	avatar.set_weapon(&"staff")
	avatar.apply_visual_settings({"quality": 2, "reduced_motion": true, "reduced_effects": true})
	avatar.set_combat_pose(&"idle", 0, 0, 0, false)
	for frame in range(60):
		avatar.animate(1.0 / 60.0, 0, 0, 0)
	var crystal: Vector3 = avatar._staff_crystal.rotation
	var cape: float = avatar._cape.rotation.x
	var body: Vector3 = avatar._body.position
	for frame in range(60):
		avatar.animate(1.0 / 60.0, 0, 0, 0)
	check(avatar._staff_crystal.rotation.is_equal_approx(crystal) and is_equal_approx(cape, avatar._cape.rotation.x) and body.distance_to(avatar._body.position) < 0.00001, "Reduced motion removes idle crystal, breathing and cape movement")
	avatar.set_combat_pose(&"charging", 0.5, 0, 0.5, false)
	avatar.animate(1.0 / 60.0, 0, 0, 0)
	check(avatar._cast_ring.visible and avatar._staff_crystal.scale.x <= 1.08, "Reduced effects keeps the charge cue while restraining crystal expansion")
	avatar.set_combat_pose(&"dodge", 0.4, 0, 0, false)
	avatar.animate(1.0 / 60.0, 0, 0, 0.1)
	check(not avatar._dodge_wake.visible and not avatar._body.basis.is_equal_approx(Basis.IDENTITY), "Reduced effects removes decorative dodge ribbons without removing the roll")

func _frame_rate_convergence() -> void:
	var poses: Array[Quaternion] = []
	for fps in [30, 60, 120]:
		var avatar := Avatar.new()
		world.add_child(avatar)
		avatar.apply_visual_settings({"reduced_motion": true})
		avatar.set_combat_pose(&"idle", 0, 0, 0, true)
		for frame in range(fps / 10):
			avatar.animate(1.0 / float(fps), 0, 0, 0)
		poses.append(avatar._left_arm.quaternion)
	check(poses[0].angle_to(poses[1]) < 0.002 and poses[1].angle_to(poses[2]) < 0.002, "Pose damping converges consistently at 30, 60 and 120 FPS")
