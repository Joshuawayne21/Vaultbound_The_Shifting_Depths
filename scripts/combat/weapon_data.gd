class_name WeaponData
extends Resource
## Future weapons can reuse PlayerCombat by supplying another data resource.

@export var style: StringName = &"sword"
@export var display_name := "Sword & Shield"
@export var light_attacks: Array[AttackData] = []
@export var heavy: AttackData
@export var ability_one: AttackData
@export var ability_two: AttackData
@export var charge_time := 0.9
@export var full_charge_multiplier := 1.8
@export var block_damage_multiplier := 0.25
@export var block_stamina_per_damage := 0.45
@export var block_drain_per_second := 4.0
@export var block_all_directions := false
@export var effect_color := Color(0.94, 0.76, 0.4)
