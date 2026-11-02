extends Node3D
## Harmless native floor seal. No physics, target, telegraph, clock or source authority.
const Kit = preload("res://scripts/visual/encounter_visual_kit.gd")
var _configured := false
var _retired := false
var _materials: Dictionary = {}

func configure(shared: Dictionary) -> bool:
	if is_inside_tree() or _configured: return false
	if not shared.get("stone_light") is Material or not shared.get("metal_trim") is Material: return false
	_materials = {"stone": shared.stone_light, "trim": shared.metal_trim}
	_configured = true
	return true

func _ready() -> void:
	if not _configured: return
	Kit.piece(self, "DormantSeal", Kit.cylinder(0.35, 0.33, 0.04, 12), _materials.stone, Vector3(0, 0.02, 0))
	for angle: float in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var bar := BoxMesh.new()
		bar.size = Vector3(0.035, 0.02, 0.19)
		var piece := Kit.piece(self, "ColdSealStroke", bar, _materials.trim, Vector3(sin(angle) * 0.14, 0.055, cos(angle) * 0.14))
		piece.rotation.y = angle

func retire() -> void:
	_retired = true
	visible = false

func snapshot() -> Dictionary:
	return {"configured": _configured, "retired": _retired, "radius": 0.35, "height": 0.08}
