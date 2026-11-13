extends "res://tests/test_harness.gd"
## Real Game/Session/world fixtures. Only disposable earned-state setup is synthetic.
const Store = preload("res://scripts/progression/profile_store.gd")
const Pets = preload("res://scripts/pets/pet_progression.gd")
const Plan = preload("res://scripts/activities/activity_run_plan.gd")
const PROTECTED := ["gold", "items", "inventory", "equipment", "depth_progression", "character", "talents", "statistics", "pets", "home", "encounter_records", "companions", "displays", "legacy_reserve"]
var session: Node
var world: Node3D
var overlay: Control
var panel: Control
var profile_path := ""

func prepare_beastwilds(suffix: String) -> bool:
	profile_path = "/tmp/vaultbound-beast-game-" + suffix + "/profile.json"
	DirAccess.make_dir_recursive_absolute(profile_path.get_base_dir())
	for file: String in DirAccess.open(profile_path.get_base_dir()).get_files(): DirAccess.remove_absolute(profile_path.get_base_dir().path_join(file))
	if DirAccess.dir_exists_absolute(profile_path + ".tmp"): DirAccess.remove_absolute(profile_path + ".tmp")
	var initial := Store.empty_profile()
	initial.depth_progression = {"version": 1, "highest_unlocked_depth": 3, "highest_cleared_depth": 2}
	initial.gold = 91
	initial.companions.guardian.recruited = true
	initial.companions.mystic.recruited = true
	check(VaultInventory.add_items(initial, {"traveler_sword": 1, "rootwarden_heart": 1}, 22), "Disposable earned fixture owns real equipment and an existing trophy")
	for item: Dictionary in initial.inventory: item.locked = true
	initial.pets.ingredients = {"rootbound_essence": 6, "mysterious_egg": 1, "lantern_fox_memory": 1}
	initial.pets.ingredient_discoveries = ["rootbound_essence", "mysterious_egg", "lantern_fox_memory"]
	initial.pets.weave_seeds = {"lantern_fox": 44}
	var woven: Dictionary = Pets.plan(initial, &"create", {"recipe_id": "weave_lantern_fox"}, "beast_game_pet", int(initial.revision))
	if not check(woven.ok and Store.new(profile_path).save_profile(woven.profile), "Existing Spiritweaving planner secures the selected test pet without granting fake world rewards"): return false
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(profile_path), "Game fault fixture uses isolated versioned storage"): return false
	if not await boot_game(): return false
	overlay = game.hud.expedition_overlay
	panel = overlay.sanctuary_panel
	if not await enter_nexus_from_sanctuary(): return false
	await frames(6)
	return check(game.party.members.size() == 3 and active_pet() != null, "Real Nexus has the player, both original companions and one selected pet")

func enter_beastwilds(seed_value := 71, through_card := false) -> bool:
	game.hud.close_modals()
	if not check(game.current_location == &"realm_nexus" and not session.active, "A new Beastwilds visit starts only from the actual idle Nexus"): return false
	if through_card:
		var gate: Node3D = game.active_world.registered_activity_sources().get(&"beastwilds")
		game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, game.active_world.get_poi_approach_position(&"beastwilds") + Vector3.UP * 0.15))
		await frames(12)
		input_hub.request_action(&"interact")
		if not check(gate != null and game.player.interaction_target == gate and panel.visible and panel.entry_enabled \
			and game._city_portal_route.get("activity_id") == &"beastwilds", "Real Beastwilds gate reviews this profile's earned eligibility"): return false
		game.debug_expedition_seed = seed_value
		tap(panel.primary_rect().get_center())
	else:
		await game.change_location(&"beastwilds", &"default", seed_value)
	if not await arrive(&"beastwilds"): return false
	world = game.active_world
	await frames(6)
	return check(session.activity_context_valid(world, session.run_generation) and world.activity_ready_valid(), "Real native world is admitted by the existing Session before gameplay")

func approach(slot: String) -> Node3D:
	game.hud.close_modals()
	world = game.active_world
	var node: Node3D = world.registered_activity_sources().get(slot)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, world.source_approach_position(slot)))
	game.camera_rig.reset_position()
	await frames(12)
	check(node != null and game.player.interaction_target == node, "Actual interaction target selects " + slot)
	return node

func claim(slot: String) -> Node3D:
	var node := await approach(slot)
	if node == null: return null
	input_hub.request_action(&"interact")
	check(node.claimed and session.activity_snapshot().claimed.has(slot), "Real player interaction claims issued source once: " + slot)
	return node

func review_exit() -> Node3D:
	var spring := await approach("return_spring")
	if spring == null: return null
	input_hub.request_action(&"interact")
	check(overlay.mode == &"sanctuary" and panel.kind == &"portal" and panel.visible and panel.entry_enabled \
		and not game._activity_exit_review.is_empty(), "Actual Return spring opens the existing reviewed mobile modal")
	return spring

func tap(point: Vector2, finger := 1701) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func possessions(profile: Variant = null) -> Dictionary:
	var data: Dictionary = session.profile if profile == null else profile
	var result := {}
	for key: String in PROTECTED: result[key] = data.get(key)
	return result.duplicate(true)

func files() -> Dictionary:
	var result := {}
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		result[suffix] = {"exists": FileAccess.file_exists(profile_path + suffix), "bytes": FileAccess.get_file_as_bytes(profile_path + suffix) if FileAccess.file_exists(profile_path + suffix) else PackedByteArray()}
	return result

func pending_bag() -> Dictionary:
	return {"gold": session.unsecured_gold, "items": session.run_items.duplicate(true), "pets": session._pet_pending.duplicate(true), "claims": session._activity_claims.duplicate(true)}

func active_pet() -> Node3D:
	return game._pet_presenter.get_ref() as Node3D if game._pet_presenter != null else null

func pet_is_single(owner: Node3D, exact: Node3D = null) -> bool:
	var pet := active_pet()
	return pet != null and (exact == null or exact == pet) and pet.get_parent() == owner \
		and pet.get_meta("definition_id", &"") == &"lantern_fox" \
		and owner.find_children("CosmeticPet", "Node3D", true, false).size() == 1
