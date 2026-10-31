extends "res://tests/test_harness.gd"
## Pure progression contracts plus real player/weapon/armor/camera integration.
const Progression = preload("res://scripts/progression/character_progression.gd")
const PROFILE := "/tmp/vaultbound-m5-character/profile.json"

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND CHARACTER PROGRESSION"
	_run.call_deferred()

func _run() -> void:
	_curve_and_talents()
	_equipment_policy()
	var session := root.get_node("ExpeditionSession")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix):
			DirAccess.remove_absolute(PROFILE + suffix)
	check(session.configure_storage(PROFILE), "Character runtime test uses an isolated secured profile")
	if await boot_game():
		await _real_actor_stats()
	finish()

func _curve_and_talents() -> void:
	var fresh := Progression.empty_character()
	check(fresh.level == 1 and fresh.experience == 0 and Progression.unspent_points(fresh) == 0, "New characters begin at level one without unearned talent points")
	check(Progression.DATA.experience_thresholds.size() == 30 and Progression.DATA.health_by_level.size() == 30 and Progression.DATA.stamina_by_level.size() == 30, "One authored progression resource defines all thirty levels")
	var previous := -1
	for index in range(30):
		var threshold := int(Progression.DATA.experience_thresholds[index])
		check(threshold > previous and Progression.level_for_xp(threshold) == index + 1, "Level %d has an increasing reproducible experience threshold" % (index + 1))
		previous = threshold
	var earned := Progression.award_xp(fresh, 500)
	check(earned.level == 3 and earned.experience == 500 and fresh.experience == 0, "Experience awards derive level without mutating the input character")
	check(Progression.unspent_points(earned) == 2, "Each earned level grants one available talent point")
	var offense := Progression.allocate(earned, "offense")
	var defense := Progression.allocate(offense, "defense")
	check(offense.talents.offense == 1 and defense.talents.defense == 1 and Progression.unspent_points(defense) == 0, "Offense and Defense spend individual points exactly once")
	check(Progression.allocate(defense, "utility").is_empty() and Progression.allocate(earned, "unknown").is_empty(), "Allocation rejects exhausted points and unsupported branches")
	var maximum := Progression.award_xp(fresh, 9223372036854775807)
	check(maximum.level == 30 and maximum.experience == 46400 and Progression.unspent_points(maximum) == 29, "Huge awards safely clamp to level thirty and its finite talent budget")
	for _index in range(10):
		maximum = Progression.allocate(maximum, "utility")
	check(maximum.talents.utility == 10 and Progression.allocate(maximum, "utility").is_empty(), "A talent branch cannot exceed its authored ten ranks")
	check(Progression.award_xp(fresh, -1).is_empty(), "Negative experience cannot erase or manufacture progression")
	var bad := fresh.duplicate(true)
	bad.level = 2
	check(Progression.normalize_character(bad).is_empty(), "A forged level inconsistent with its experience is rejected")
	bad = fresh.duplicate(true)
	bad.talents.offense = 1
	check(Progression.normalize_character(bad).is_empty(), "A saved character cannot allocate unearned talent points")
	bad = fresh.duplicate(true)
	bad.experience = INF
	check(Progression.normalize_character(bad).is_empty(), "Nonfinite saved experience is rejected")
	var snapshot := Progression.snapshot(defense)
	check(snapshot.branches.size() == 3 and snapshot.next_level_experience == 900 and snapshot.talent_points == 0, "Progression snapshot exposes branch descriptions and the next level threshold")

func _entry(id: String, uid: String, enhancement: int = 0) -> Dictionary:
	return {"uid": uid, "item_id": id, "quantity": 1, "enhancement": enhancement,
		"durability": 100, "modifiers": {}, "identified": true, "locked": false, "favorite": false}

func _profile() -> Dictionary:
	var result := {"character": Progression.empty_character(), "inventory": [], "equipment": {}}
	var items := {"main_weapon": "temple_blade", "off_hand": "warden_shield", "helmet": "iron_helm",
		"chest_armor": "traveler_coat", "boots": "trail_boots", "accessory": "amber_ring"}
	for slot: String in items:
		var uid := "fixture_" + slot
		result.inventory.append(_entry(items[slot], uid))
		result.equipment[slot] = uid
	return result

func _equipment_policy() -> void:
	var empty := Progression.resolve_stats({})
	check(empty.max_health == 100.0 and empty.max_stamina == 100.0 and empty.damage_multiplier == 1.0 and empty.armor == 0.0 and empty.stamina_regen == 23.0, "Unequipped level-one stats preserve the original combat baseline")
	var profile := _profile()
	var sword := Progression.resolve_stats(profile, &"sword")
	check(is_equal_approx(sword.max_health, 111.0) and is_equal_approx(sword.max_stamina, 108.0), "All six equipment slots add their configured health and stamina values")
	check(is_equal_approx(sword.damage_multiplier, 1.04) and is_equal_approx(sword.armor, 0.06), "Weapon damage and armor use conservative fractional bonuses")
	var staff := Progression.resolve_stats(profile, &"staff")
	check(staff.damage_multiplier == 1.0 and is_equal_approx(staff.armor, 0.03) and staff.max_stamina == 104.0, "Changing weapon family cannot borrow the other family's weapon or shield bonuses")
	profile.inventory[0].enhancement = 5
	profile.inventory[0].modifiers = {"damage_bonus": 0.01}
	var improved := Progression.resolve_stats(profile)
	check(is_equal_approx(improved.damage_multiplier, 1.066), "Enhancement improves base gear stats while preserving the instance's rolled modifier")
	profile.inventory[0].durability = 0
	check(Progression.resolve_stats(profile).damage_multiplier == 1.0, "Broken equipment retains its identity but contributes no stat bonuses")
	profile.inventory[0].durability = 100
	profile.inventory[0].identified = false
	check(Progression.resolve_stats(profile).damage_multiplier == 1.0, "Hidden equipment properties cannot grant power before identification")
	profile = _profile()
	profile.equipment.main_weapon = "missing_instance"
	check(Progression.resolve_stats(profile).damage_multiplier == 1.0, "A missing equipment instance cannot manufacture a weapon bonus")
	profile.equipment.helmet = profile.equipment.off_hand
	check(Progression.resolve_stats(profile).max_health == 108.0, "One instance referenced in the wrong slot cannot duplicate its bonuses")
	profile = _profile()
	profile.character = Progression.allocate(Progression.allocate(Progression.award_xp(Progression.empty_character(), 500), "offense"), "utility")
	var developed := Progression.resolve_stats(profile)
	check(developed.max_health == 117.0 and developed.max_stamina == 112.0 and is_equal_approx(developed.damage_multiplier, 1.052) and developed.stamina_regen == 23.25, "Authored levels and allocated talents combine with equipment without replacing its rules")
	var normalized := Progression.resolve_stats(profile, &"sword", true)
	check(normalized.max_health == 100.0 and normalized.max_stamina == 100.0 and normalized.damage_multiplier == 1.0 and normalized.armor == 0.0, "An explicit future normalization policy removes earned stat advantages without mutating progression")
	var unequipped := profile.duplicate(true)
	unequipped.equipment.main_weapon = ""
	var comparison := Progression.compare_item(unequipped, "fixture_main_weapon")
	check(is_equal_approx(comparison.difference.damage_multiplier, 0.04) and unequipped.equipment.main_weapon == "", "Item comparison predicts the candidate bonus without changing equipped ownership")
	profile.inventory[0].modifiers = {"damage_bonus": INF, "armor": -900.0, "unsupported": 5000}
	var defensive := Progression.resolve_stats(profile)
	check(is_finite(defensive.damage_multiplier) and defensive.damage_multiplier < 2.0 and defensive.armor >= 0.0, "Defensive stat resolution ignores nonfinite, negative and unsupported modifiers")

func _real_actor_stats() -> void:
	var player: CharacterBody3D = game.player
	var profile := _profile()
	player.health = 61.0
	player.stamina = 47.0
	player.apply_progression(profile)
	check(player.max_health == 111.0 and player.max_stamina == 108.0 and player.health == 61.0 and player.stamina == 47.0, "Applying equipment changes real maxima without healing or refilling the existing actor")
	for _index in range(8):
		player.apply_progression({})
		player.apply_progression(profile)
	check(player.health == 61.0 and player.stamina == 47.0, "Repeated equip and unequip cannot create health or stamina")
	player.combat.equip_style(&"staff")
	check(player.combat_damage_multiplier() == 1.0 and player.max_stamina == 104.0, "The existing weapon swap immediately refreshes family-dependent gear stats")
	player.combat.equip_style(&"sword")
	check(is_equal_approx(player.combat_damage_multiplier(), 1.04) and player.visual._equipment_appearance.size() == 6, "Equipped sword restores its own bonus and all stable avatar appearance slots")
	player.health = player.max_health
	player.invulnerable_remaining = 0.0
	player.combat.cancel_action()
	var before: float = player.health
	player.take_damage(20.0)
	check(is_equal_approx(before - player.health, 18.8), "Real incoming damage applies the resolved armor after shared combat defenses")
	await seconds(0.3)
	var dummy := get_first_node_in_group("combat_targets") as Node3D
	dummy.max_health = 1000
	dummy.health = 1000
	dummy.global_position = Vector3(0, 0, 2)
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 4)))
	player.set_controls_enabled(true)
	player.stamina = player.max_stamina
	await frames(3)
	player.select_target(dummy, true)
	player.combat.light_attack()
	var cast_id: int = player.combat.attack_id
	var expected_damage: float = 22.0 * player.combat_damage_multiplier()
	input_hub.request_action(&"camera_toggle")
	check(player.combat.attack_id == cast_id and player.combat.state == &"windup", "Camera switching preserves the empowered attack's unique cast and phase")
	check(await eventually(func() -> bool: return dummy.health < 1000, 2.0), "The existing melee attack delivers equipment-adjusted damage")
	check(is_equal_approx(1000.0 - dummy.health, expected_damage), "Equipment damage resolves once through the original shared hit detection")
	await eventually(func() -> bool: return player.combat.state == &"idle", 2.0)
	player.apply_progression({})
	check(player.max_health == 100.0 and player.combat_damage_multiplier() == 1.0 and player.progression_stats().appearance.is_empty(), "Unequipping restores base combat and avatar appearance without recreating the player")
