extends SceneTree
## Run in TWO separate engine processes using -- --write PATH then -- --read PATH.
## The fixture path must be under /tmp/; real user progress is never modified.

const Store = preload("res://scripts/progression/profile_store.gd")
const Loot = preload("res://scripts/progression/loot_table.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/"):
		push_error("Usage: -- --write|--read /tmp/vaultbound-persistence/profile.json")
		quit(2)
		return
	var path: String = args[1]
	var session := root.get_node_or_null("ExpeditionSession")
	if not _check(session != null, "Progression autoload exists"):
		_finish()
		return
	if args[0] == "--write":
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".expected.json"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
		_check(session.configure_storage(path), "Writer selects isolated test profile")
		_check(session.begin_run(310031), "Writer begins a seeded expedition")
		var reward := {"chest_id": "restart-fixture", "category": "ancient", "gold": 137,
			"items": [{"id": "temple_blade", "quantity": 1}, {"id": "root_fiber", "quantity": 4}, {"id": "rootwarden_heart", "quantity": 1}], "value": 400}
		_check(session.collect_reward(reward), "Writer collects equipment, materials and a discovery")
		_check(not session.extract(), "Writer cannot secure loot before boss completion")
		session.add_kill()
		session.mark_boss_defeated()
		_check(session.extract(), "Writer successfully extracts to local storage")
		_check(not session.extract(), "Writer rejects duplicate extraction")
		_check(FileAccess.file_exists(path), "Writer created a persistent profile file")
		var expected := FileAccess.open(path + ".expected.json", FileAccess.WRITE)
		expected.store_string(JSON.stringify(session.profile))
		expected.close()
	else:
		_check(FileAccess.file_exists(path + ".expected.json"), "Reader finds the previous process fixture")
		_check(session.configure_storage(path), "New engine process loads isolated secured profile")
		var expected: Dictionary = Store.normalize(JSON.parse_string(FileAccess.get_file_as_string(path + ".expected.json")))
		_check(session.profile.gold == 137 and session.profile.items.get("temple_blade", 0) == 1, "Restart preserves extracted gold and equipment")
		_check(session.profile.items.get("root_fiber", 0) == 4 and session.profile.discoveries.has("rootwarden_heart"), "Restart preserves materials and collection discovery")
		_check(session.profile.statistics.completed == 1 and session.profile.statistics.last_seed == 310031, "Restart preserves completed expedition statistics")
		_check(session.profile.gold == expected.gold and session.profile.items == expected.items, "Loaded bank matches the previous process exactly")
		_check(session.begin_run(310032), "Reader starts a second expedition")
		_check(session.collect_reward({"chest_id": "lost-on-death", "category": "common", "gold": 59,
			"items": [{"id": "runic_staff", "quantity": 1}], "value": 90}), "Reader collects unsecured loot for death test")
		session.fail_run("death")
		_check(not session.active and session.unsecured_gold == 0, "Death clears only the active run bag")
		_check(session.profile.gold == expected.gold and session.profile.items == expected.items, "Death preserves previously secured gold and equipment")
		var store := Store.new(path)
		var disk: Dictionary = store.load_profile()
		_check(disk.gold == expected.gold and disk.items == expected.items, "Secured bank remains intact on disk after dungeon death")
		_check(disk.statistics.completed == 1 and disk.statistics.deaths == 1, "Death statistics persist without erasing completion history")
	_finish()

func _check(condition: bool, description: String) -> bool:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
	return condition

func _finish() -> void:
	print("VAULTBOUND RESTART %s: %d checks" % ["PASSED" if failures.is_empty() else "FAILED", checks])
	quit(0 if failures.is_empty() else 1)
