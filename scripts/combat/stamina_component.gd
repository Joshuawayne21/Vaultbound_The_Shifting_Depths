class_name StaminaComponent
extends RefCounted
## Reusable resource budget; costs are committed once at action start.

var maximum := 100.0
var current := 100.0
var regeneration := 23.0
var recovery_delay := 0.0

func spend(amount: float, delay: float = 0.65) -> bool:
	if amount < 0.0 or current + 0.0001 < amount:
		return false
	current = maxf(0.0, current - amount)
	recovery_delay = maxf(recovery_delay, delay)
	return true

func tick(delta: float, can_regenerate: bool = true) -> void:
	recovery_delay = maxf(0.0, recovery_delay - delta)
	if recovery_delay <= 0.0 and can_regenerate:
		current = minf(maximum, current + regeneration * delta)

func reset() -> void:
	current = maximum
	recovery_delay = 0.0
