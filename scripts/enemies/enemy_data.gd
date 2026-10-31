class_name EnemyData
extends Resource
## Reusable enemy tuning. Presentation and AI consume the same archetype data.

@export var archetype: StringName = &"skeleton"
@export var display_name: String = "Skeleton Warrior"
@export var max_health: float = 90.0
@export var damage: float = 12.0
@export_range(0.0, 0.75) var armor: float = 0.0
@export var move_speed: float = 2.4
@export var detection_range: float = 7.5
@export var attack_range: float = 2.25
@export var preferred_range: float = 1.9
@export var leash_radius: float = 11.0
@export var patrol_radius: float = 1.8
@export var windup_time: float = 0.65
@export var recovery_time: float = 1.0
@export var attack_active_time: float = 0.2
@export var attack_cone_dot: float = 0.25
@export var ranged: bool = false
@export var radial_attack: bool = false
@export var projectile_speed: float = 11.0
@export var projectile_lifetime: float = 2.0
@export var hit_recovery: float = 0.2
@export var stagger_resistance: float = 0.0
@export var collision_radius: float = 0.4
@export var collision_height: float = 1.9
@export var label_height: float = 2.5
@export var accent_color: Color = Color(0.86, 0.72, 0.46)
