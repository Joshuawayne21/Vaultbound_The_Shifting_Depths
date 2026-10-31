extends Node3D
## Explicit training reset. Travel guard owns the reload and removes old projectiles.
signal travel_requested(destination: StringName, entry_id: StringName)
var interaction_radius := 2.6

func _ready() -> void:
	add_to_group("interactables")
	var kit := preload("res://scripts/world/architecture.gd").new(self)
	kit.cylinder(Vector3(0, 0.18, 0), 0.8, 0.36, "dark_stone", true, 8)
	kit.cylinder(Vector3(0, 0.55, 0), 0.5, 0.65, "light_stone", true, 8)
	kit.ring(Vector3(0, 0.9, 0), 0.45, 0.5, "gold")
	kit.cone(Vector3(0, 1.3, 0), 0.25, 0.8, "glow")
	kit.label("REST & RESET", Vector3(0, 2.3, 0), 23, Color("9edcca"))
	kit.label("Restore health • Renew encounters", Vector3(0, 1.9, 0), 12)

func get_prompt() -> String:
	return "Rest & reset all encounters"

func interact(player: Node3D) -> void:
	if player.has_method("heal"):
		player.heal(player.max_health)
	if player.has_method("restore_stamina"):
		player.restore_stamina(player.max_stamina)
	travel_requested.emit(&"combat_arena", &"default")
