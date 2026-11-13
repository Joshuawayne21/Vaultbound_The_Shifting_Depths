extends "res://tests/test_harness.gd"
## ordinary combat defaults and bounded resource-rate seam.
func _initialize() -> void:
	suite_name = "VAULTBOUND ECHOES EFFECT DEFAULTS"
	_run.call_deferred()

func _run() -> void:
	var stamina := StaminaComponent.new()
	stamina.current = 20.0
	stamina.regeneration = 10.0
	stamina.tick(1.0)
	check(is_equal_approx(stamina.current, 30.0), "All old two-argument stamina callers retain the original rate")
	stamina.recovery_delay = 0.5
	stamina.tick(0.25, true, 1.24)
	check(is_equal_approx(stamina.current, 30.0) and is_equal_approx(stamina.recovery_delay, 0.25), "Temporary regeneration never bypasses recovery delay")
	stamina.tick(0.25, false, 1.24)
	check(is_equal_approx(stamina.current, 30.0), "Blocking and other regeneration exclusions remain effective")
	stamina.tick(1.0, true, 1.24)
	check(is_equal_approx(stamina.current, 42.4), "Two regeneration boons increase only the rate by 24 percent")
	stamina.tick(1.0, true, 1000.0)
	check(is_equal_approx(stamina.current, 54.8), "Untrusted multiplier cannot exceed the configured temporary cap")
	stamina.tick(1.0, true, NAN)
	check(is_equal_approx(stamina.current, 64.8), "Nonfinite rate safely falls back to identity")
	var player := load("res://scripts/player/player.gd").new() as Node3D
	var saved_stats: Dictionary = player._derived_stats.duplicate(true)
	check(player.activity_effect_snapshot() == {"damage_multiplier": 1.0, "regen_multiplier": 1.0}, "An unbound or off-tree player has no temporary effects")
	check(not player.bind_activity_effects(null, null, 1), "An absent authority and world cannot bind effects")
	check(is_equal_approx(player.combat_damage_multiplier(), 1.0) and player._derived_stats == saved_stats, "Normal damage and saved gear derivation remain unchanged")
	player._activity_effect_generation = 7
	player.clear_activity_effects(6)
	check(player._activity_effect_generation == 7, "A stale generation cleanup cannot clear a newer effect binding")
	player.clear_activity_effects(7)
	check(player._activity_effect_generation == -1, "The matching generation can retire its binding")
	player.free()
	finish()
