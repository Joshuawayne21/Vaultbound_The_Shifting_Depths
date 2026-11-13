extends "res://tests/test_harness.gd"
## Disposable profile and real Game/Portal input helpers. No fake world or reward authority.
const Store = preload("res://scripts/progression/profile_store.gd")
const Catalog = preload("res://scripts/realms/realm_catalog.gd")
const Layout = preload("res://resources/nexus/layout.tres")
const PetProgress = preload("res://scripts/pets/pet_progression.gd")
var session: Node
var overlay: Control
var panel: Control
var hall: Node3D
var profile_path := ""

func prepare_nexus(test_id: String, companions := false, enter := true, cosmetic_pet := false) -> bool:
	profile_path = "/tmp/vaultbound-nexus-" + test_id + "/profile.json"
	DirAccess.make_dir_recursive_absolute(profile_path.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(profile_path + suffix): DirAccess.remove_absolute(profile_path + suffix)
	var initial := Store.empty_profile()
	if companions:
		initial.companions.guardian.recruited = true
		initial.companions.mystic.recruited = true
	if cosmetic_pet:
		# Earned-material fixture setup only; use the actual atomic Spiritweaving
		# planner to create one persisted, selected pet with its original variant.
		initial.pets.ingredients = {"rootbound_essence": 6, "mysterious_egg": 1, "lantern_fox_memory": 1}
		initial.pets.ingredient_discoveries = ["rootbound_essence", "mysterious_egg", "lantern_fox_memory"]
		initial.pets.weave_seeds = {"lantern_fox": 44}
		var woven: Dictionary = PetProgress.plan(initial, &"create", {"recipe_id": "weave_lantern_fox"}, "nexus_pet_fixture", int(initial.revision))
		if not check(woven.ok, "Disposable fixture creates one owned cosmetic pet through existing Spiritweaving rules"): return false
		initial = woven.profile
	if not check(Store.new(profile_path).save_profile(initial), "Nexus fixture writes only its disposable profile"): return false
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(profile_path), "Nexus fixture binds isolated save storage"): return false
	if not await boot_game(): return false
	overlay = game.hud.expedition_overlay
	panel = overlay.sanctuary_panel
	if enter: return await enter_nexus()
	return true

func enter_nexus() -> bool:
	game.hud.close_modals()
	if game.current_location == &"realm_nexus":
		hall = game.active_world
		return true
	if not check(game.current_location == &"sanctuary", "Nexus test enters through its real Sanctuary entrance"): return false
	var gate := portal_to(&"realm_nexus")
	if not check(gate != null and gate.require_entry_card, "North wing has the real reviewed Nexus entrance"): return false
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, game.active_world.get_poi_approach_position(&"rootbound_abyss") + Vector3.UP * 0.15))
	await frames(12)
	input_hub.request_action(&"interact")
	if not check(overlay.mode == &"sanctuary" and panel.kind == &"portal" and panel.entry_enabled, "Actual north entrance interaction opens an enabled source-bound card"): return false
	tap(panel.primary_rect().get_center())
	if not await arrive(&"realm_nexus"): return false
	hall = game.active_world
	await frames(6)
	return check(hall.get_script().resource_path == "res://scripts/world/realm_nexus.gd", "Travel installs the canonical Nexus scene")

func source(id: StringName) -> Node3D:
	var sources: Dictionary = hall.registered_portal_sources()
	return sources.get(id) as Node3D

func approach(id: StringName) -> void:
	game.hud.close_modals()
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, hall.get_poi_approach_position(id) + Vector3.UP * 0.15))
	await frames(12)

func open_gate(id: StringName) -> Node3D:
	await approach(id)
	var gate := source(id)
	if not check(gate != null and game.player.interaction_target == gate, "Real interaction selection reaches " + String(id)): return null
	input_hub.request_action(&"interact")
	if not check(overlay.mode == &"sanctuary" and panel.kind == &"portal" and panel.visible, "Actual input opens the source-bound card: " + String(id)): return null
	return gate

func tap(point: Vector2, finger := 601) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func save_files() -> Dictionary:
	var files := {}
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		files[suffix] = {"exists": FileAccess.file_exists(profile_path + suffix),
			"bytes": FileAccess.get_file_as_bytes(profile_path + suffix) if FileAccess.file_exists(profile_path + suffix) else PackedByteArray()}
	return files

func no_travel() -> bool:
	return game.current_location == &"realm_nexus" and game.active_world == hall and not game.transitioning and not session.active

func capsule_clear(at: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = at + Vector3.UP * 0.91
	query.collision_mask = 1 | 16
	query.collide_with_areas = false
	return hall.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func supported(at: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at - Vector3.UP * 0.25, 1)
	ray.collide_with_areas = false
	var hit := hall.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.collider == hall._floor_body and absf(Vector3(hit.position).y) < 0.025 and Vector3(hit.normal).dot(Vector3.UP) > 0.98
