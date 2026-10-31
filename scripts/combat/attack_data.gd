class_name AttackData
extends Resource
## Authorable timings and costs. No camera or input references belong in attack data.

@export var label := "Attack"
@export var mode: StringName = &"melee"
@export var damage := 25.0
@export var stamina_cost := 8.0
@export var windup := 0.12
@export var active_time := 0.12
@export var recovery := 0.24
## Minimum interval between starts of this particular attack; independent of recovery.
@export var cooldown := 0.0
@export var attack_range := 2.8
@export var cone_dot := 0.25
@export var movement_scale := 0.6
@export var projectile_speed := 15.0
@export var projectile_lifetime := 1.1
@export var radius := 0.0
@export var stagger := 0.15
@export var slow_duration := 0.0
@export var slow_factor := 1.0

func duration() -> float:
	return windup + active_time + recovery
