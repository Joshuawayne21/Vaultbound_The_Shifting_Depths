class_name CompanionData
extends Resource
## Small authored decision budgets. Stats and weapon rules stay in shared combat.

@export var id := "guardian"
@export var display_name := "Rowan"
@export var role := "Guardian"
@export var weapon_style: StringName = &"sword"
@export var personality := "Steadfast"
@export var maximum_health := 145.0
@export var move_speed := 4.65
@export_range(0.20, 1.0) var decision_interval := 0.34
@export_range(0.0, 0.5) var reaction_jitter := 0.12
@export_range(0.3, 1.0) var accuracy := 0.86
@export var detection_range := 10.5
@export var maximum_pursuit := 12.0
@export var desired_range := 2.0
@export var heal_amount := 30.0
@export var heal_cooldown := 13.0
@export var heal_cast_time := 0.7
@export var heal_range := 7.0
@export var heal_stamina_cost := 20.0
@export var tint := Color("b88b4b")
