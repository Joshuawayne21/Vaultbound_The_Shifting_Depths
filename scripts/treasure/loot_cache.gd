class_name VaultLootCache
extends Node3D
## Reusable visual/search handle. All rewards stay in Session's ledger when a
## view is culled, recycled, hidden or inspected. No collision can block a path.

@export var interaction_radius := 2.8
var cache_id := ""
var binding_generation := 0
var owner_id := ""
var _record: Dictionary = {}
var _session: WeakRef
var _room: WeakRef
var _trim_material: StandardMaterial3D
var _lid_tween: Tween
var _opened := false
var _settings: Node

@onready var model: Node3D = $Model
@onready var lid: Node3D = $Model/Lid
@onready var title: Label3D = $Title

func _ready() -> void:
	visible = false
	set_process(false)
	_trim_material = ($Model/Seal as MeshInstance3D).material_override.duplicate() as StandardMaterial3D
	$Model/Seal.material_override = _trim_material
	$FloorRing.material_override = _trim_material
	_settings = get_node_or_null("/root/VisualSettings")
	if _settings != null and _settings.has_signal("settings_changed"):
		_settings.settings_changed.connect(_apply_settings)
	_apply_settings({})

func bind_cache(record: Dictionary, authority: Node, room: Node3D, at: Vector3) -> void:
	if record.is_empty() or record.get("empty", true) or not is_instance_valid(authority) \
			or not is_instance_valid(room) or not room.is_visible_in_tree() or not at.is_finite():
		unbind()
		return
	var new_binding: bool = cache_id != String(record.id) or _room == null or _room.get_ref() != room \
		or int(_record.get("run_generation", -1)) != int(record.get("run_generation", -1))
	if new_binding:
		unbind()
		binding_generation += 1
		cache_id = String(record.id)
		_session = weakref(authority)
		_room = weakref(room)
		room.visibility_changed.connect(_on_room_visibility_changed)
		_opened = false
		lid.rotation.x = 0.0
	var changed: bool = new_binding or int(_record.get("revision", -1)) != int(record.revision)
	owner_id = String(record.owner_id)
	_record = record.duplicate(true)
	global_position = at
	visible = true
	add_to_group("searchable_loot_caches")
	add_to_group("interactables")
	if changed:
		_apply_appearance()
	if bool(record.get("opened", false)) and not _opened:
		_opened = true
		if is_instance_valid(_lid_tween):
			_lid_tween.kill()
		if _reduced_motion():
			lid.rotation.x = 0.9
		else:
			_lid_tween = create_tween()
			_lid_tween.tween_property(lid, "rotation:x", 0.9, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func unbind() -> void:
	if _room != null:
		var room := _room.get_ref() as Node3D
		if is_instance_valid(room) and room.visibility_changed.is_connected(_on_room_visibility_changed):
			room.visibility_changed.disconnect(_on_room_visibility_changed)
	if is_instance_valid(_lid_tween):
		_lid_tween.kill()
	if not cache_id.is_empty():
		binding_generation += 1
	cache_id = ""
	owner_id = ""
	_record.clear()
	_session = null
	_room = null
	visible = false
	remove_from_group("interactables")
	remove_from_group("searchable_loot_caches")

func binding_valid(id: String, generation: int) -> bool:
	var room := _room.get_ref() as Node3D if _room != null else null
	return is_inside_tree() and not cache_id.is_empty() and id == cache_id \
		and generation == binding_generation and owner_id == "local_player" \
		and is_visible_in_tree() and is_instance_valid(room) and room.is_visible_in_tree() \
		and is_in_group("searchable_loot_caches") and not bool(_record.get("empty", true))

func can_search(actor: Node3D) -> bool:
	return is_instance_valid(actor) and actor.is_inside_tree() \
		and binding_valid(cache_id, binding_generation) \
		and actor.global_position.distance_to(global_position) <= interaction_radius \
		and CombatRules.visible_from(self, actor.global_position + Vector3.UP, global_position + Vector3.UP * 0.5)

func bound_to(authority: Node) -> bool:
	return _session != null and _session.get_ref() == authority

func get_prompt() -> String:
	return "Search " + String(_record.get("label", "Loot Cache")) if binding_valid(cache_id, binding_generation) else ""

func interact(actor: Node3D) -> void:
	var authority := _session.get_ref() as Node if _session != null else null
	if can_search(actor) and is_instance_valid(authority) and authority.has_method("open_loot"):
		authority.open_loot(self, actor)

func cache_snapshot() -> Dictionary:
	return _record.duplicate(true)

func _on_room_visibility_changed() -> void:
	var room := _room.get_ref() as Node3D if _room != null else null
	if not is_instance_valid(room) or not room.is_visible_in_tree():
		unbind()

func _apply_appearance() -> void:
	var kind := String(_record.get("kind", "regular"))
	var factor := 0.65 if kind == "regular" else (0.9 if kind == "elite" else 1.22)
	model.scale = Vector3.ONE * factor
	$Model/Reinforcement.visible = kind != "regular"
	$Model/Crown.visible = kind == "boss"
	var rarity := "common"
	var highest := 0
	for item_id: String in _record.get("items", {}):
		var definition := VaultLootTable.item_for(item_id)
		if definition != null:
			var index := VaultItemDefinition.RARITIES.find(definition.rarity)
			if index > highest:
				highest = index
				rarity = definition.rarity
	var colors := {"common": Color("a9b6c0"), "uncommon": Color("6ace8e"), "rare": Color("6bbdf2"),
		"epic": Color("bc82ef"), "legendary": Color("f2c66d"), "mythic": Color("ed647d"), "ancient_relic": Color("73e5d3")}
	_trim_material.albedo_color = colors[rarity]
	title.modulate = colors[rarity]
	title.text = String(_record.get("label", "Loot Cache")).to_upper()
	if highest > 0:
		title.text += "\n" + rarity.replace("_", " ").to_upper()
	title.position.y = factor * 1.18
	$FloorRing.scale = Vector3.ONE * factor
	_apply_settings({})

func _apply_settings(_value: Dictionary) -> void:
	$FloorRing.visible = not (is_instance_valid(_settings) and bool(_settings.get("reduced_effects")))
	if _reduced_motion() and is_instance_valid(_lid_tween):
		_lid_tween.kill()
		lid.rotation.x = 0.9 if _opened else 0.0

func _reduced_motion() -> bool:
	return is_instance_valid(_settings) and bool(_settings.get("reduced_motion"))
