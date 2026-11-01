extends Node3D
## Presentation and interaction only. The shared loot table selects contents,
## and ExpeditionSession owns receipts, inventory mutation and extraction.

signal opened(reward: Dictionary)

@export var category: StringName = &"common"
@export var interaction_radius := 2.8
var seed_value := 0
var chest_id := ""
var is_open := false
var _table: VaultLootTable
var _session: Node
var _level: WeakRef
var _generation := -1
var _claiming := false

@onready var lid: Node3D = $Lid
@onready var title: Label3D = $Title
@onready var trim: MeshInstance3D = $FrontSeal

func configure(chest_category: StringName, expedition_seed: int, identity: String) -> void:
	category = chest_category
	seed_value = expedition_seed
	chest_id = identity
	if is_node_ready():
		_apply_configuration()

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("treasure_chests")
	_session = get_node_or_null("/root/ExpeditionSession")
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("can_use_run_source"):
			_level = weakref(ancestor)
			_generation = int(ancestor.run_generation)
			break
		ancestor = ancestor.get_parent()
	_apply_configuration()

func _apply_configuration() -> void:
	_table = VaultLootTable.table_for(category)
	if _table == null:
		title.text = "SEALED RELIQUARY"
		return
	title.text = _table.label.to_upper()
	var color := Color("d1aa6e")
	match category:
		&"reinforced": color = Color("a4ccce")
		&"ancient": color = Color("e3bf70")
		&"cursed": color = Color("bd78cf")
		&"boss": color = Color("91f0ae")
	title.modulate = color
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trim.material_override = material
	if _session != null and _session.has_claimed(chest_id):
		is_open = true
		lid.rotation.x = 1.25
		title.text = "CLAIMED"

func get_prompt() -> String:
	if is_open:
		return "Chest already claimed"
	if _table == null:
		return "Sealed reliquary"
	return "Open %s%s" % [_table.label, " · raises Awareness" if category == &"cursed" else ""]

func can_interact(player: Node3D) -> bool:
	var level := _level.get_ref() as Node3D if _level != null else null
	return not is_open and not _claiming and _table != null and is_instance_valid(_session) \
		and is_instance_valid(level) and int(level.run_generation) == _generation \
		and bool(level.can_use_run_source(self, player, interaction_radius))

func interact(player: Node3D) -> void:
	if not can_interact(player): return
	var level := _level.get_ref() as Node3D
	var reward := _table.roll(seed_value, chest_id)
	_claiming = true
	var accepted: bool = _session.collect_reward(reward)
	_claiming = false
	if not accepted or not is_instance_valid(level) or not level.run_source_context_valid() \
			or int(level.run_generation) != _generation:
		return
	is_open = true
	var tween := create_tween()
	tween.tween_property(lid, "rotation:x", 1.25, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	title.text = "CLAIMED · UNSECURED"
	opened.emit(reward)
	if level.run_source_context_valid():
		CombatRules.effect(global_position + Vector3.UP * 0.9, title.modulate, 0.8, 0.45, get_parent())
