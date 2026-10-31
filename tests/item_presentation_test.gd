extends "res://tests/test_harness.gd"

const ItemPresentation = preload("res://scripts/visual/item_presentation.gd")
const Avatar = preload("res://scripts/player/player_avatar.gd")
const Hall = preload("res://scripts/world/collection_hall.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND ITEM PRESENTATION"
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("VisualSettings")
	var saved: Dictionary = settings.snapshot()
	settings.current_quality = 1
	settings.reduced_motion = false
	settings.reduced_effects = false
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var viewer := Node3D.new()
	viewer.add_to_group("player")
	world.add_child(viewer)
	var definition := VaultLootTable.item_for("rootwarden_heart").duplicate() as VaultItemDefinition
	definition.rarity = "legendary"
	definition.display_animation = {"rotation_speed": 0.3, "bob_height": 0.06, "bob_speed": 1.2}
	var entry := {"uid": "presentation-only", "item_id": String(definition.id), "enhancement": 5}
	var before := entry.duplicate(true)
	var components: Array[VaultItemPresentation] = []
	var targets: Array[Node3D] = []
	for index in range(12):
		var target := Node3D.new()
		target.position = Vector3(float(index) * 0.4, 1.2, 0)
		target.rotation.y = 0.32
		target.scale = Vector3(0.8, 1.1, 0.9)
		world.add_child(target)
		var component := ItemPresentation.new()
		world.add_child(component)
		component.position = target.position
		component.configure(definition, entry, target, &"display")
		components.append(component)
		targets.append(target)
	await frames(3)
	var managers := get_nodes_in_group("item_presentation_budget")
	check(managers.size() == 1, "Twelve displays share one scheduler")
	var manager: Node = managers[0]
	manager.refresh()
	check(_spark_total(components) == 8, "Medium gives all nearby item cues a shared eight-spark ceiling")
	check(int(manager.snapshot().allocated_sparks) == 8, "Scheduler reports actual bounded spark allocation")
	for component in components:
		check(int(component.snapshot().spark_count) <= 3, "Individual effects never exceed three sparks")
	var base: Transform3D = components[0]._base
	for tick in range(2400):
		components[0]._process(0.05)
	check(absf(targets[0].position.y - base.origin.y) <= 0.0601, "Long-running bob remains bounded around the authored anchor")
	check(targets[0].position.x == base.origin.x and targets[0].position.z == base.origin.z, "Display motion cannot drift horizontally")
	check(is_equal_approx(targets[0].basis.determinant(), base.basis.determinant()), "Rotation preserves model scale and handedness")
	settings.reduced_motion = true
	settings._apply()
	manager.refresh()
	var frozen := targets[0].transform
	await frames(3)
	check(targets[0].transform == frozen and not components[0].is_processing(), "Reduced motion freezes the existing pose without snapping")
	check(_spark_total(components) == 0, "Reduced motion also removes moving sparks")
	settings.reduced_motion = false
	settings.reduced_effects = true
	settings._apply()
	manager.refresh()
	check(_spark_total(components) == 0 and components[0].visible, "Reduced effects removes sparks while retaining readable static rarity accents")
	var material := components[0]._rim.material_override as StandardMaterial3D
	check(material.albedo_color.r < ItemPresentation.COLORS.legendary.r, "Reduced effects lowers accent intensity")
	settings.reduced_effects = false
	for quality in range(3):
		settings.current_quality = quality
		settings._apply()
		manager.refresh()
		check(_spark_total(components) == [4, 8, 12][quality], "Preset %d enforces its shared item budget" % quality)
	components[0].hide()
	targets[1].position.x = 100.0
	components[1].position.x = 100.0
	manager.refresh()
	check(not components[0].is_processing() and not components[1].is_processing(), "Hidden and distant displays stop processing")
	components[0].show()
	manager.refresh()
	check(components[0].is_processing(), "Visible nearby displays resume without rebuilding owned models")
	check(entry == before, "Presentation never mutates the supplied inventory snapshot")
	var copy := components[0].snapshot()
	copy.uid = "forged"
	check(components[0].snapshot().uid == before.uid, "Snapshot is defensive and cannot alter display identity")
	check(_safe_tree(components[0]), "Accents add no lights, physics, depth bypass or animated shaders")
	components[0].clear()
	check(targets[0].transform == base and not components[0].is_processing(), "Clearing restores the exact authored model transform")
	check(not components[0].is_in_group("item_presentations"), "Empty displays leave the allocator")
	await _preview_checks(world, definition, entry)
	_completion_checks()
	await _hall_checks()
	settings.current_quality = int(saved.quality)
	settings.reduced_motion = bool(saved.reduced_motion)
	settings.reduced_effects = bool(saved.reduced_effects)
	settings._apply()
	world.queue_free()
	await frames(3)
	finish()

func _preview_checks(world: Node3D, definition: VaultItemDefinition, entry: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(384, 384)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	world.add_child(viewport)
	var pivot := Node3D.new()
	pivot.rotation.y = 0.7
	viewport.add_child(pivot)
	var component := ItemPresentation.new()
	pivot.add_child(component)
	component.configure(definition, entry, pivot, &"inspection")
	var baseline := pivot.transform
	component.set_world_activity(true, 3)
	check(not component.is_processing() and not component.is_in_group("item_presentations"), "Artifact inspector stays outside world processing and allocation")
	check(component.get_node_or_null("BoundedSparks") == null, "Artifact inspector never allocates particles")
	await frames(3)
	check(pivot.transform == baseline, "Artifact inspector preserves the drag-controlled pivot")
	for explicit in [true, false]:
		var avatar := Avatar.new()
		avatar.static_item_presentation = explicit
		viewport.add_child(avatar)
		avatar.set_process(false)
		var sword_before: Transform3D = avatar._sword.transform
		var staff_before: Transform3D = avatar._staff.transform
		avatar.set_equipment_appearance({"main_weapon": {"item_id": "verdant_oathblade", "weapon_style": "sword", "rarity": "mythic", "enhancement": 7}})
		var sword_cue: VaultItemPresentation = avatar._sword_presentation
		check(sword_cue.snapshot().context == "weapon_preview" and not sword_cue.is_processing() and not sword_cue.is_in_group("item_presentations"), "Character preview has static child effects with explicit flag=%s" % explicit)
		check(sword_cue.get_node_or_null("BoundedSparks") == null, "Hidden character preview has no particle allocations")
		avatar.set_weapon(&"staff")
		avatar.set_equipment_appearance({"main_weapon": {"item_id": "vaultheart_staff", "weapon_style": "staff", "rarity": "ancient_relic", "enhancement": 10}})
		check(not avatar._sword.visible and avatar._staff.visible, "Weapon family visibility remains authoritative")
		check(avatar._sword.transform == sword_before and avatar._staff.transform == staff_before, "Enhancement cues never move real weapon attachment anchors")
		avatar.hide()
		await frames(2)
		check(not avatar._staff_presentation.is_processing() and not avatar._sword_presentation.is_processing(), "Hidden Equipment preview has no child aura work")
		avatar.queue_free()
	viewport.queue_free()

func _completion_checks() -> void:
	var obtainable := VaultLootTable.item_for("rootwarden_heart").duplicate() as VaultItemDefinition
	var future := obtainable.duplicate() as VaultItemDefinition
	future.id = &"unreleased_boss"
	future.obtainable = false
	var currency := obtainable.duplicate() as VaultItemDefinition
	currency.id = &"coins"
	currency.catalog_group = "currency"
	var profile := {"discoveries": ["rootwarden_heart", "rootwarden_heart", "unreleased_boss"]}
	var before := profile.duplicate(true)
	var result := Hall.completion_snapshot(profile, {"heart": obtainable, "future": future, "currency": currency})
	check(result == {"discovered": 1, "total": 1, "trophies": 1, "trophy_total": 1}, "Completion excludes unreleased content, currency and duplicate records")
	check(profile == before, "Collection completion is a read-only discovery snapshot")

func _hall_checks() -> void:
	var session := root.get_node("ExpeditionSession")
	var saved: Dictionary = session.profile.duplicate(true)
	var fixture: Dictionary = saved.duplicate(true)
	fixture.inventory = [{"uid": "hall-kept", "item_id": "rootwarden_heart", "quantity": 1, "enhancement": 0}]
	fixture.displays = {"relic_0": "hall-kept"}
	fixture.discoveries = ["rootwarden_heart"]
	fixture.revision = int(fixture.revision) + 1
	session.profile = fixture
	var hall := load("res://scenes/world/collection_hall.tscn").instantiate() as Node3D
	root.add_child(hall)
	await frames(3)
	var stand: Node3D = hall.stands.relic_0
	check(stand._presentation.snapshot().uid == "hall-kept", "Occupied Hall stand uses the exact owned UID")
	check(hall.collection_completion.discovered == 1 and hall.get_node("CollectionCompletion").text.contains("DISCOVERIES 1 /"), "World label shows secured discovery completion")
	check(stand._presentation._rim.mesh != null and stand.displayed_model != null, "Static architecture bake preserves dynamic item art and accents")
	var anchor: Transform3D = stand._presentation._base
	var model_id: int = stand.displayed_model.get_instance_id()
	hall.refresh_displays(false)
	check(stand.displayed_model.get_instance_id() == model_id, "Unchanged revisions do not rebuild presentation models")
	check(session.profile == fixture and session.profile.inventory[0].uid == "hall-kept", "Hall visual refresh preserves complete secured progression")
	session.profile.displays.clear()
	session.profile.revision += 1
	hall.refresh_displays(false)
	check(stand.displayed_uid.is_empty() and not stand._presentation.snapshot().has("uid") and not stand._presentation.visible, "Cleared stand removes its accent and retains empty state")
	check(stand._model_anchor.transform == anchor, "Clearing an untouched Hall display restores its original anchor")
	session.profile = saved
	hall.queue_free()
	await frames(2)

func _spark_total(components: Array[VaultItemPresentation]) -> int:
	var total := 0
	for component in components:
		total += int(component.snapshot().spark_count)
	return total

func _safe_tree(node: Node) -> bool:
	if node is Light3D or node is CollisionObject3D or node is CollisionShape3D:
		return false
	if node is GeometryInstance3D:
		var surface: Material = node.material_override
		if surface is ShaderMaterial or (surface is BaseMaterial3D and surface.no_depth_test):
			return false
	for child in node.get_children():
		if not _safe_tree(child):
			return false
	return true
