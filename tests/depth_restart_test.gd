extends "res://tests/test_harness.gd"
## Separate processes: -- --write /tmp/.../profile.json, then -- --read PATH.
const Store = preload("res://scripts/progression/profile_store.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND DEPTH RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/"):
		push_error("Use -- --write|--read /tmp/vaultbound-depth-restart/profile.json")
		quit(2)
		return
	var path: String = args[1]
	var session: Node = root.get_node("ExpeditionSession")
	if args[0] == "--write":
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
		check(session.configure_storage(path) and not session.depth_entry_status(2).ok, "Fresh writer cannot enter Depth two")
		check(session.begin_depth_run(7171, 1), "Writer issues the first floor")
		check(session.collect_reward({"chest_id": "depth_restart", "category": "common", "gold": 7, "items": [{"id": "temple_blade", "quantity": 1}], "value": 22}), "Writer collects original inventory equipment")
		session.mark_boss_defeated()
		check(session.extract() and session.profile.depth_progression.highest_unlocked_depth == 2, "Writer commits secured possessions and next floor in one profile")
	else:
		check(session.configure_storage(path), "Independent reader loads the prior engine's profile")
		check(session.depth_entry_status(2).ok and not session.depth_entry_status(3).ok, "Restart retains exactly the earned unlock")
		check(session.profile.gold == 7 and session.profile.items.get("temple_blade", 0) == 1, "Restart retains earned Depthmarks and equipment")
		var secured: Dictionary = session.profile.duplicate(true)
		check(session.begin_depth_run(7172, 2), "Reader begins the unlocked next floor")
		session.collect_reward({"chest_id": "lost_after_restart", "category": "common", "gold": 14, "items": [], "value": 14})
		session.mark_boss_defeated()
		session.fail_run("death")
		var disk := Store.new(path).load_profile()
		check(disk.depth_progression == secured.depth_progression and disk.gold == secured.gold and disk.items == secured.items, "Death after restart preserves secured unlocks, currency and inventory")
		check(disk.statistics.completed == 1 and disk.statistics.deaths == 1, "Death does not masquerade as a completed deeper floor")
	finish()
