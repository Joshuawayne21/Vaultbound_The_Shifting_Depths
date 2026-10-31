extends Node3D
## Interaction only exists while this party member can still be revived.
var party: Node
var member: Node3D
var interaction_radius := 2.4

func _process(_delta: float) -> void:
	var available: bool = is_instance_valid(party) and is_instance_valid(member) and party.is_downed(member)
	if available and not is_in_group("interactables"):
		add_to_group("interactables")
	elif not available and is_in_group("interactables"):
		remove_from_group("interactables")

func get_prompt() -> String:
	return "REVIVE TEAMMATE · Hold still while channeling"

func interact(actor: Node3D) -> void:
	if is_instance_valid(party):
		party.request_revive(actor, member)
