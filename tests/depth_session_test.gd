extends "res://tests/test_harness.gd"
## Pure Session transactions plus real configured-world identity are covered
## separately by depth_world/portal suites; no fabricated actor deaths here.
const Store = preload("res://scripts/progression/profile_store.gd")
const Policy = preload("res://resources/expedition/depth_policy.tres")
const Rewards = preload("res://resources/loot/monster_rewards.tres")
const PATH := "/tmp/vaultbound-7c-depth-session/profile.json"
var session: Node
var replaced := false
var replacement_result := false
var callbacks: Array[Dictionary] = []

func _initialize() -> void:
	suite_name = "VAULTBOUND DEPTH SESSION"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files():
		DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PATH), "Depth transaction fixture uses isolated storage")
	check(VaultInventory.add_items(session.profile, {"temple_blade": 1}, 72), "Fixture owns secured equipment before any expedition")
	session.profile.gold = 55
	check(session.set_companion_recruited("guardian", true), "Participating Guardian is persisted before floor entry")
	var generation: int = session.run_generation
	check(not session.begin_depth_run(701, 2) and not session.active and session.run_generation == generation, "Depth two cannot start before the first full extraction")
	check(not session.begin_depth_run(701, 0) and not session.begin_depth_run(701, 51), "Invalid and unsupported floor intents never start a run")
	var admission: Dictionary = session.depth_entry_status(1)
	admission.policy.reward_multiplier = 99.0
	check(session.begin_depth_run(701, 1), "Explicit depth one is admitted")
	var issued: Dictionary = session.issued_run_context()
	check(issued.expedition_depth == 1 and issued.policy.reward_multiplier == 1.0, "Edited admission preview cannot change issued policy")
	issued.policy.minimum_rooms = 24
	issued.expedition_depth = 50
	var snapshot: Dictionary = session.snapshot()
	snapshot.depth_progression.highest_unlocked_depth = 50
	check(session.issued_run_context().expedition_depth == 1 and session.issued_run_context().policy.minimum_rooms == 6 and session.profile.depth_progression.highest_unlocked_depth == 1, "Issued context and snapshots do not expose mutable policy or unlock references")
	check(session.collect_reward({"chest_id": "depth_one_reward", "category": "common", "gold": 8, "items": [{"id": "root_fiber", "quantity": 3}], "value": 12}), "Pending depth reward enters the original unsecured bag")
	check(not session.extract() and session.profile.depth_progression.highest_unlocked_depth == 1, "Loot alone cannot complete a depth")
	session.mark_boss_defeated()
	check(session.profile.depth_progression.highest_unlocked_depth == 1 and not session.depth_entry_status(2).ok, "Boss objective completion alone does not unlock the next floor")
	var secured: Dictionary = session.profile.duplicate(true)
	var primary := FileAccess.get_file_as_bytes(PATH)
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	check(not session.extract() and session.active and session.unsecured_gold == 8 and session.profile == secured, "Interrupted save leaves both pending loot and secured depth unchanged")
	check(FileAccess.get_file_as_bytes(PATH) == primary, "Failed extraction never changes secured primary bytes")
	DirAccess.remove_absolute(PATH + ".tmp")
	session.results_ready.connect(func(data: Dictionary) -> void: callbacks.append(data.duplicate(true)))
	check(session.extract(), "Retry secures loot and completion together")
	check(not session.active and session.profile.depth_progression == {"version": 1, "highest_unlocked_depth": 2, "highest_cleared_depth": 1}, "Successful extraction unlocks exactly Depth two")
	check(session.profile.gold == 63 and session.profile.items.root_fiber == 3 and session.profile.items.temple_blade == 1, "Completion preserves secured possessions and adds earned loot once")
	check(callbacks.size() == 1 and callbacks[0].expedition_depth == 1 and callbacks[0].highest_unlocked_depth == 2 and callbacks[0].character_experience == 250 and callbacks[0].companion_experience.guardian == 150, "Result callbacks show the completed issued floor and baseline actual XP")
	check(not session.extract() and session.profile.statistics.completed == 1, "Repeated extraction cannot duplicate rewards or completion")
	check(Store.new(PATH).load_profile().depth_progression == session.profile.depth_progression, "Depth unlock survives an independent disk read")
	check(session.begin_depth_run(702, 2), "Unlocked second depth begins through the same Session authority")
	var frozen: Dictionary = session.issued_run_context().policy
	var source: String = Rewards.source_for("skeleton", false)
	var ordinary: Dictionary = Rewards.roll(702, "frozen_reward", source, 0)
	var expected: Dictionary = Rewards.roll_for_depth(702, "frozen_reward", source, 0, 2, frozen)
	check(expected.gold == roundi(float(ordinary.gold) * 1.035) and expected.value == ordinary.value + expected.gold - ordinary.gold, "Floor DM scaling rounds once and changes aggregate value by the actual currency delta")
	var old_reward_step: float = Policy.reward_step
	var old_maximum: int = Policy.supported_maximum_depth
	var mutable_policy: VaultDepthPolicy = Policy
	mutable_policy.reward_step = 0.1
	mutable_policy.supported_maximum_depth = 1
	var changed: Dictionary = Rewards.roll_for_depth(702, "frozen_reward", source, 0, 2, frozen)
	check(changed == expected and session.issued_run_context().policy == frozen, "Changing shared authoring resources after admission cannot reinterpret issued rewards")
	session.add_kill("skeleton")
	session.mark_boss_defeated()
	check(session.extract(), "An already admitted floor can complete while later shared policy authoring changes")
	mutable_policy.reward_step = old_reward_step
	mutable_policy.supported_maximum_depth = old_maximum
	check(Policy.is_valid(), "The test restores the exact shared authored policy")
	check(session.last_results.expedition_depth == 2 and session.last_results.character_experience == roundi(270.0 * 1.035) and session.last_results.companion_experience.guardian == roundi(160.0 * 1.035), "Depth two awards character and participating companion XP from the frozen policy once")
	check(session.profile.depth_progression.highest_unlocked_depth == 3 and session.profile.depth_progression.highest_cleared_depth == 2, "Second full completion unlocks the third depth")
	var retained: Dictionary = session.profile.duplicate(true)
	check(session.begin_depth_run(703, 3), "An eligible deeper floor can be attempted")
	session.collect_reward({"chest_id": "lost_depth_reward", "category": "common", "gold": 9, "items": [], "value": 9})
	session.fail_run("death")
	check(session.profile.depth_progression == retained.depth_progression and session.profile.gold == retained.gold and session.profile.items == retained.items, "Death loses only unsecured rewards and does not change secured floor unlocks")
	check(session.begin_depth_run(704, 3), "Death does not relock the attempted floor")
	session.mark_boss_defeated()
	session.fail_run("abandoned")
	check(session.profile.depth_progression == retained.depth_progression, "Leaving after the boss without extraction grants no unlock")
	check(session.begin_depth_run(705, 1), "An earlier unlocked floor remains replayable")
	session.mark_boss_defeated()
	check(session.extract() and session.profile.depth_progression == retained.depth_progression, "Replaying a lower floor preserves the higher unlock and deepest clear")
	session.changed.connect(_replace_admission)
	check(not session.begin_depth_run(706, 1) and replaced and replacement_result, "A callback replacing even the same seed and depth cannot make the original admission succeed")
	session.changed.disconnect(_replace_admission)
	check(session.active and session.run_seed == 706 and session.issued_run_context().expedition_depth == 1, "Admission cleanup does not destroy a replacement run")
	session.fail_run("abandoned")
	finish()

func _replace_admission(data: Dictionary) -> void:
	if replaced or not bool(data.active):
		return
	replaced = true
	session.fail_run("abandoned")
	replacement_result = session.begin_depth_run(706, 1)
