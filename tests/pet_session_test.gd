extends "res://tests/test_harness.gd"
const Fixtures = preload("res://tests/pet_test_fixtures.gd")
const PATH := "/tmp/vaultbound-6e-pet-session/profile.json"
var session: Node
var terminal: Node3D
var reentrant_results: Array[bool] = []
var held_quote: Dictionary = {}
var replace_once := false
var published_results: Array[Dictionary] = []

func _initialize() -> void:
	suite_name = "VAULTBOUND PET SESSION"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
	var store := VaultProfileStore.new(PATH)
	check(store.save_profile(Fixtures.funded()), "Isolated cosmetic ingredients fixture saved")
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PATH), "Session loads isolated profile")
	if not await boot_game():
		finish()
		return
	for node: Node in get_nodes_in_group("city_terminals"):
		if node.get("terminal_id") == &"conservatory":
			terminal = node as Node3D
	if not check(terminal != null, "Actual Conservatory source exists"):
		finish()
		return
	game.player.global_position = terminal.global_position + Vector3(0, 0.1, 2.0)
	game.player.velocity = Vector3.ZERO
	await frames(3)
	check(session.open_pet_service(terminal, game.player), "Nearby actual current-world terminal opens pet service")
	var protected: Dictionary = session.profile.duplicate(true)
	var maximum_health: float = game.player.max_health
	var maximum_stamina: float = game.player.max_stamina
	var quote: Dictionary = session.quote_pet_action(&"create", {"recipe_id": "weave_lantern_fox"})
	check(bool(quote.get("ok", false)), "Source-bound creation quote available")
	var variant := String(quote.get("preview", {}).get("after", {}).get("variant", ""))
	check(session.cancel_pet_action(quote) and not session.commit_pet_action(quote), "Canceled token cannot be replayed")
	quote = session.quote_pet_action(&"create", {"recipe_id": "weave_lantern_fox"})
	check(quote.preview.after.variant == variant, "Canceled quote cannot reroll mutation")
	held_quote = quote.duplicate(true)
	session.pet_changed.connect(_reenter)
	quote.preview.costs.clear()
	quote.preview.after.variant = "forged"
	check(session.commit_pet_action(quote), "Commit uses saved intent rather than edited preview")
	session.pet_changed.disconnect(_reenter)
	check(reentrant_results == [false] and not session.commit_pet_action(quote), "Reentrant and repeated commits cannot duplicate ownership")
	check(session.profile.pets.owned.lantern_fox.variant == variant and session.profile.pets.owned.size() == 1, "Only trusted fixed appearance is installed")
	check(session.profile.gold == protected.gold and session.profile.inventory == protected.inventory and session.profile.companions == protected.companions and session.profile.character == protected.character, "Creation leaves earned currency, gear, AI roster and character untouched")
	check(game.player.max_health == maximum_health and game.player.max_stamina == maximum_stamina, "Cosmetic creation never changes player statistics")
	var before: Dictionary = session.profile.duplicate(true)
	quote = session.quote_pet_action(&"rename", {"pet_id": "lantern_fox", "alias": "灯"})
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	var bytes := FileAccess.get_file_as_bytes(PATH)
	check(not session.commit_pet_action(quote) and session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes, "Failed write rolls back alias and all profile fields")
	DirAccess.remove_absolute(PATH + ".tmp")
	check(not session.commit_pet_action(quote), "Failed write still consumes confirmation token")
	quote = session.quote_pet_action(&"rename", {"pet_id": "lantern_fox", "alias": "灯"})
	check(session.commit_pet_action(quote) and session.profile.pets.owned.lantern_fox.alias == "灯", "Fresh retry persists legitimate Unicode alias")
	quote = session.quote_pet_action(&"rest", {})
	check(session.set_companion_recruited("guardian", true), "Independent existing companion transaction advances the shared revision")
	check(not session.commit_pet_action(quote) and session.profile.pets.active_id == "lantern_fox", "A different persistent system invalidates the old pet quote")
	check(session.set_companion_recruited("guardian", false), "Existing companion roster can return to its prior state")
	quote = session.quote_pet_action(&"rest", {})
	game.hud.close_modals()
	check(not session.commit_pet_action(quote), "Overall modal close invalidates pending pet quote")
	game.player.global_position = terminal.global_position + Vector3(0, 0.1, 2.0)
	await frames(2)
	check(session.open_pet_service(terminal), "Service can be reopened legitimately")
	quote = session.quote_pet_action(&"rest", {})
	game.player.global_position += Vector3(9, 0, 0)
	check(not session.commit_pet_action(quote) and session.profile.pets.active_id == "lantern_fox", "Leaving source radius rejects pending action")
	game.hud.close_modals()
	_finish_lifecycle()
	game.player.global_position = terminal.global_position + Vector3(0, 0.1, 2.0)
	await frames(2)
	check(session.open_pet_service(terminal), "Source remains legitimate after pure lifecycle checks")
	quote = session.quote_pet_action(&"rest", {})
	terminal.queue_free()
	check(not session.commit_pet_action(quote) and not session.pet_snapshot().service_available, "Queued service cannot commit or advertise availability")
	await frames(2)
	check(not session.quote_pet_action(&"rest", {}).ok and not session.pet_snapshot().service_available, "Fully freed typed service is rejected without a runtime error")
	game.hud.close_modals()
	game.queue_free()
	await frames(2)
	finish()

func _reenter(_appearance: Dictionary) -> void:
	reentrant_results.append(session.commit_pet_action(held_quote))

func _replace_on_changed(_data: Dictionary) -> void:
	if not replace_once or not session.active:
		return
	replace_once = false
	session.fail_run("abandoned")
	session.begin_run(911)

func _replace_on_finish() -> void:
	if replace_once and not session.active:
		replace_once = false
		session.begin_run(913)

func _capture_results(result: Dictionary) -> void:
	published_results.append(result.duplicate(true))

func _replace_on_failed_death(message: String) -> void:
	if message.begins_with("Death statistics could not save"):
		session.begin_run(916)

func _finish_lifecycle() -> void:
	replace_once = true
	session.changed.connect(_replace_on_changed)
	check(not session.begin_run(910) and session.active and session.run_seed == 911, "begin_run reports callback-replaced generation instead of loading old seed")
	session.changed.disconnect(_replace_on_changed)
	session.fail_run("abandoned")
	check(session.begin_run(912), "Pure extraction fixture starts")
	var findings := VaultPetCatalog.findings_for(912, "fixture_secret", "rescue")
	session._pet_pending = VaultPetProgression.append_findings(VaultPetProgression.empty_pending(), findings, "fixture_secret")
	session.mark_boss_defeated()
	var before: Dictionary = session.profile.duplicate(true)
	var pending: Dictionary = session._pet_pending.duplicate(true)
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	check(not session.extract() and session.active and session._pet_pending == pending and session.profile == before, "Failed extraction preserves exact unsecured findings and provenance")
	DirAccess.remove_absolute(PATH + ".tmp")
	replace_once = true
	session.loot_changed.connect(_replace_on_finish)
	session.results_ready.connect(_capture_results)
	check(session.extract() and session.active and session.run_seed == 913 and session._pet_pending.sources.is_empty(), "Successful extraction clears old state before callback creates new run")
	check(published_results.is_empty(), "Replacement run suppresses stale extraction results")
	session.loot_changed.disconnect(_replace_on_finish)
	session.fail_run("abandoned")
	check(session.begin_run(914), "Death fixture starts")
	session._pet_pending = pending.duplicate(true)
	var secured: Dictionary = session.profile.pets.duplicate(true)
	session.fail_run("death")
	check(session.profile.pets == secured and not session.active and session._pet_pending.sources.is_empty(), "Death loses only unsecured pet findings and preserves secured collection")
	check(not published_results.is_empty() and published_results.back().outcome == "death" and not published_results.back().pet_findings.ingredients.is_empty(), "Immutable death results retain lost findings after clearing")
	session.results_ready.disconnect(_capture_results)
	check(session.begin_run(915), "Failed death write fixture starts")
	session._pet_pending = pending.duplicate(true)
	before = session.profile.duplicate(true)
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	session.notice.connect(_replace_on_failed_death)
	session.fail_run("death")
	session.notice.disconnect(_replace_on_failed_death)
	DirAccess.remove_absolute(PATH + ".tmp")
	check(session.active and session.run_seed == 916 and session.profile == before and session._pet_pending.sources.is_empty(), "Failed death notification cannot erase a callback-created replacement run or secured possessions")
	session.fail_run("abandoned")
