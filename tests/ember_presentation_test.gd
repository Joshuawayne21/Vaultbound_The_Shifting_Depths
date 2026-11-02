extends "res://tests/biome_presentation_test.gd"
const Catalog = preload("res://scripts/visual/dungeon_presentation_catalog.gd")
const EmberProfile = preload("res://resources/visual/ember_presentation.tres")
const PriorProfile = preload("res://resources/visual/crystal_presentation.tres")
const EmberTheme = preload("res://resources/biomes/ember_crypt.tres")

func _initialize() -> void:
	suite_name = "VAULTBOUND EMBER PRESENTATION"
	_run.call_deferred()

func _run() -> void:
	var shown: Dictionary = EmberProfile.snapshot()
	var old: Dictionary = RootboundTheme.snapshot()
	var prior: Dictionary = PriorProfile.snapshot()
	if not check(Presentation.valid_snapshot(shown) and shown.id == "ember_native_v1", "Actual Ember profile resolves all closed presentation data"):
		finish()
		return
	check(shown.size() == 7 and shown.modules.size() == 14 and shown.material_roles.size() == 18 and _plain(shown), "Ember uses exactly seven detached fields, fourteen modules and eighteen roles")
	check(old.presentation.id == "rootbound_native_v1" and old.presentation.modules == Presentation.MODULES \
		and old.presentation.dressing == Presentation.DRESSING_ROLES and old.presentation.budgets == Presentation.BUDGETS,
		"Rootbound retains its original snapshot fields and metadata aliases")
	check(Presentation.valid_snapshot(prior) and prior.id == "crystal_native_v1" and prior.modules == Catalog.CRYSTAL_MODULES, "Existing Crystal native profile retains its own exact metadata")
	var theme: Resource = EmberTheme.duplicate()
	theme.available = true
	var themed: Dictionary = theme.snapshot()
	check(Definition.valid_snapshot(themed) and themed.presentation == shown, "Ember metadata admits only its actual closed profile when enabled")
	theme.presentation = PriorProfile
	check(theme.snapshot().is_empty(), "Ember cannot issue a Crystal presentation")
	theme.presentation = RootboundTheme.presentation
	check(theme.snapshot().is_empty(), "Ember cannot issue a Rootbound presentation")
	for key: String in Presentation.SNAPSHOT_KEYS:
		var missing := shown.duplicate(true)
		missing.erase(key)
		check(not Presentation.valid_snapshot(missing), "Ember rejects missing " + key)
	for role: String in Presentation.ROLE_PATHS:
		var changed := shown.duplicate(true)
		changed.material_roles[role].path = Presentation.ROLE_PATHS[role]
		check(not Presentation.valid_snapshot(changed), "Ember rejects cross-profile authored path for " + role)
	var mixed := shown.duplicate(true)
	mixed.modules.boss_heart = Presentation.MODULES.boss_heart.duplicate(true)
	check(not Presentation.valid_snapshot(mixed) and Presentation.module_path(mixed, &"boss_heart").is_empty(), "Unknown mixed module map cannot reach runtime loading")
	check(Presentation.module_path(shown, &"unknown").is_empty() and Catalog.profile("future_theme").is_empty(), "Unknown theme and logical module fail closed")
	var metadata: Dictionary = Catalog.profile("ember_native_v1")
	metadata.modules.boss_heart.motif = "changed"
	check(Catalog.profile("ember_native_v1").modules == shown.modules, "Catalog callers receive detached metadata")
	var materials := Presentation.build_materials(shown)
	var environment := Presentation.build_environment(shown)
	check(materials.size() == 18 and Presentation._properties(environment, Presentation.ENV_FIELDS) == shown.environment, "Actual issued Ember materials and environment reconstruct exactly")
	for role: String in Catalog.EMBER_ROLE_PATHS:
		var source := load(Catalog.EMBER_ROLE_PATHS[role]) as Material
		check(materials[role] != source and _material_values(materials[role], role) == _material_values(source, role), "Detached native Ember material preserves authored values: " + role)
	var crystal := load(Catalog.EMBER_ROLE_PATHS.crystal) as StandardMaterial3D
	var previous := crystal.albedo_color
	crystal.albedo_color = Color.RED
	var rebuilt := Presentation.build_materials(shown)
	check(rebuilt.crystal.albedo_color == previous and Presentation.valid_snapshot(shown), "Issued furnace colors remain frozen after authoring-resource edits")
	crystal.albedo_color = previous
	stage = Node3D.new()
	root.add_child(stage)
	for id: String in shown.modules:
		var room := (load(Presentation.module_path(shown, StringName(id))) as PackedScene).instantiate() as AbyssRoom
		check(Presentation.module_instance_valid(shown, room) and not Presentation.module_instance_valid(old.presentation, room) and not Presentation.module_instance_valid(prior, room), "Actual Ember scene/slots/motif match only their profile: " + id)
		var original := _geometry(room)
		room.configure_visuals(85432, 3, true)
		check(room.configure_presentation(shown, materials) and _geometry(room) == original, "Shared presentation preserves every native collider/anchor/mesh: " + id)
		seed(19321)
		var expected := randi()
		seed(19321)
		stage.add_child(room)
		check(randi() == expected, "Temple dressing preserves gameplay RNG: " + id)
		check(room.dressing.get_script().resource_path == "res://scripts/visual/ember_decoration.gd" \
			and room.get_node_or_null("EnchantedDressing") == null and room.get_node("EnchantedMotes").biome == &"ember" and room.get_node("EnchantedMotes").maximum_motes == 12 and _resolved(room, materials), "Only actual Ember dressing and frozen material roles are used: " + id)
		check(not room.configure_presentation(old.presentation, materials), "Live room cannot change presentation: " + id)
		var preview := (load(Presentation.module_path(shown, StringName(id))) as PackedScene).instantiate() as AbyssRoom
		preview.configure_visuals(85432, 3, true)
		stage.add_child(preview)
		check(preview.dressing.get_script() == room.dressing.get_script() and preview.dressing.fingerprint() == room.dressing.fingerprint() \
			and _geometry(preview) == _geometry(room), "Closed standalone Ember preview matches issued native geometry/dressing without enabling gameplay: " + id)
		var preview_floor := preview.get_node("Floor") as MeshInstance3D
		check(_material_values(preview_floor.material_override, "soil") == _material_values(materials.soil, "soil"), "Standalone native preview reconstructs the actual temple palette: " + id)
		stage.remove_child(preview)
		preview.free()
		stage.remove_child(room)
		room.free()
		var wrong := (load(Presentation.module_path(shown, StringName(id))) as PackedScene).instantiate() as AbyssRoom
		wrong.get_node("Decor00").name = "UnregisteredDecoration"
		check(not Presentation.module_instance_valid(shown, wrong) and not wrong.configure_presentation(shown, materials), "Missing actual native slot rejects before activation: " + id)
		stage.add_child(wrong)
		check(wrong.dressing == null and wrong.get_node_or_null("EnchantedDressing") == null, "Rejected standalone Ember scene cannot silently add forest dressing: " + id)
		stage.remove_child(wrong)
		wrong.free()
	stage.queue_free()
	await frames(3)
	check(EmberProfile.snapshot() == shown and RootboundTheme.snapshot() == old and PriorProfile.snapshot() == prior, "Source resources and legacy profile remain unchanged after all checks")
	finish()

func _resolved(node: Node, materials: Dictionary) -> bool:
	if node is GeometryInstance3D and node.material_override != null:
		var material: Material = node.material_override
		if material.resource_path in Presentation.ROLE_PATHS.values() or material.resource_path in Catalog.EMBER_ROLE_PATHS.values() or material.resource_path in Catalog.CRYSTAL_ROLE_PATHS.values(): return false
		if node.get_parent() != null and node.get_parent().name == "EmberDressing" and material not in materials.values(): return false
	for child: Node in node.get_children():
		if not _resolved(child, materials): return false
	return true
