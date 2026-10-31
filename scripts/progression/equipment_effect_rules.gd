class_name VaultEquipmentEffectRules
extends Resource
## Pure, authored equipment policy. No inventory, scene, camera or save ownership.
## Randomness is explicit and local; existing instances are never rerolled here.

const EFFECT_IDS := ["crit_chance", "lifesteal", "block_strength", "ability_cooldown_reduction"]
@export var modifier_limits: Dictionary = {}
@export var aggregate_caps: Dictionary = {}
@export var roll_weights: Dictionary = {}
## Each rarity contains count, minimum and maximum fraction of its stat limit.
@export var rarity_rolls: Dictionary = {}
@export var critical_multiplier := 1.5
@export var lifesteal_per_attack := 4.0

func roll_modifiers(rarity: String, seed: int, base_stats: Dictionary = {}) -> Dictionary:
	var rule: Dictionary = rarity_rolls.get(rarity, {})
	var count := clampi(int(rule.get("count", 0)), 0, 2)
	if count == 0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var candidates: Array[String] = []
	for id: String in modifier_limits:
		if safe_value(roll_weights.get(id, 0.0), 100.0) > 0.0 and _roll_headroom(id, base_stats) >= 0.001:
			candidates.append(id)
	# Resource dictionary ordering is not part of a persisted roll's contract.
	candidates.sort()
	var result := {}
	for index in range(mini(count, candidates.size())):
		var total := 0.0
		for id: String in candidates:
			total += safe_value(roll_weights.get(id, 0.0), 100.0)
		var selection := rng.randf() * total
		var chosen := candidates.back() as String
		for id: String in candidates:
			selection -= safe_value(roll_weights.get(id, 0.0), 100.0)
			if selection <= 0.0:
				chosen = id
				break
		var lower := safe_value(rule.get("minimum", 0.25), 1.0)
		var upper := maxf(lower, safe_value(rule.get("maximum", 1.0), 1.0))
		var limit := _roll_headroom(chosen, base_stats)
		var amount := snappedf(rng.randf_range(lower, upper) * limit, 0.001)
		result[chosen] = clampf(amount, minf(0.001, limit), limit)
		candidates.erase(chosen)
	return result

func _roll_headroom(id: String, base_stats: Dictionary) -> float:
	var limit := safe_value(modifier_limits.get(id, 0.0), 100.0)
	# Authored proc stats share an item cap with their roll; choose another stat
	# when the base already fills it. Legacy flat bonuses retain their own ranges.
	return maxf(0.0, limit - safe_value(base_stats.get(id, 0.0), limit)) if EFFECT_IDS.has(id) else limit

func empty_effects() -> Dictionary:
	var result := {}
	for id: String in EFFECT_IDS:
		result[id] = 0.0
	return result

func clamp_effects(values: Dictionary) -> Dictionary:
	var result := empty_effects()
	for id: String in EFFECT_IDS:
		result[id] = safe_value(values.get(id, 0.0), float(aggregate_caps.get(id, 0.0)))
	return result

func item_effect(base: Dictionary, modifiers: Variant, id: String) -> float:
	if not EFFECT_IDS.has(id):
		return 0.0
	var limit := float(modifier_limits.get(id, 0.0))
	var value := safe_value(base.get(id, 0.0), limit)
	if modifiers is Dictionary:
		value += safe_value(modifiers.get(id, 0.0), limit)
	return minf(value, limit)

func critical_factor(chance: float, roll: float) -> float:
	if not is_finite(roll) or roll < 0.0 or roll >= 1.0:
		return 1.0
	return clampf(critical_multiplier, 1.0, 1.5) if roll < safe_value(chance, float(aggregate_caps.get("crit_chance", 0.0))) else 1.0

func blocked_multiplier(original: float, strength: float) -> float:
	return original * (1.0 - safe_value(strength, float(aggregate_caps.get("block_strength", 0.0))))

func ability_cooldown(original: float, action_duration: float, reduction: float) -> float:
	if original <= 0.0:
		return original
	var shortened := original * (1.0 - safe_value(reduction, float(aggregate_caps.get("ability_cooldown_reduction", 0.0))))
	return maxf(action_duration, shortened)

func healing_for_damage(actual: float, rate: float, remaining: float) -> float:
	if not is_finite(actual) or actual <= 0.0:
		return 0.0
	return minf(actual * safe_value(rate, float(aggregate_caps.get("lifesteal", 0.0))), safe_value(remaining, minf(4.0, lifesteal_per_attack)))

func safe_value(value: Variant, maximum: float) -> float:
	if not (value is int or value is float) or not is_finite(float(value)):
		return 0.0
	return clampf(float(value), 0.0, maxf(0.0, maximum))
