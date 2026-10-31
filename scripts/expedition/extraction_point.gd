extends Node3D
## A save-before-travel boundary. Failed writes leave the bag and exit retryable.
signal travel_requested(destination: StringName, entry_id: StringName)

var level: Node3D
var interaction_radius := 3.0
var _crystal: MeshInstance3D
var _label: Label3D
var _material: StandardMaterial3D
var _committed := false

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("extraction_points")
	var kit := preload("res://scripts/world/architecture.gd").new(self)
	kit.cylinder(Vector3(0, 0.12, 0), 1.3, 0.24, "dark_stone", false, 16)
	kit.ring(Vector3(0, 0.26, 0), 1.0, 1.06, "gold")
	_material = kit.material(Color("405b65"), 0.0, true)
	var crystal := PrismMesh.new()
	crystal.size = Vector3(0.9, 1.8, 0.9)
	_crystal = kit.mesh_instance(crystal, Vector3(0, 1.4, 0), _material)
	_label = kit.label("EXTRACTION SEALED", Vector3(0, 3.0, 0), 22)

func _process(delta: float) -> void:
	_crystal.rotation.y += delta * 0.45
	var ready: bool = ExpeditionSession.active and ExpeditionSession.boss_defeated
	_material.albedo_color = Color("8ee8b9") if ready else Color("405b65")
	_material.emission = _material.albedo_color
	_label.text = "EXTRACT & SECURE LOOT" if ready else "DEFEAT THE ROOTWARDEN"

func get_prompt() -> String:
	return "Extract & secure expedition rewards" if ExpeditionSession.boss_defeated else "Extraction sealed · defeat the Rootwarden"

func interact(_player: Node3D) -> void:
	if _committed or not ExpeditionSession.active:
		return
	if not ExpeditionSession.boss_defeated:
		ExpeditionSession.notice.emit("The Rootwarden binds this exit. Defeat it to extract.")
		return
	if ExpeditionSession.extract():
		_committed = true
		travel_requested.emit(&"sanctuary", &"from_abyss")
