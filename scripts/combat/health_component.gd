class_name HealthComponent
extends RefCounted
## Simulation-only health; presentation and scene travel listen to the owner.

signal changed(current: float, maximum: float)
signal died

var maximum := 100.0
var current := 100.0

func damage(amount: float) -> float:
	if amount <= 0.0 or current <= 0.0:
		return 0.0
	var applied := minf(current, amount)
	current -= applied
	changed.emit(current, maximum)
	if current <= 0.0:
		died.emit()
	return applied

func heal(amount: float) -> float:
	if current <= 0.0 or amount <= 0.0:
		return 0.0
	var restored := minf(maximum - current, amount)
	current += restored
	changed.emit(current, maximum)
	return restored

func reset() -> void:
	current = maximum
	changed.emit(current, maximum)
