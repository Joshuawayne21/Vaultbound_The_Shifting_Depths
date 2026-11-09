extends Node3D
## Personal display chamber. Saved UIDs select visuals; the scene never mutates
## inventory ownership. One shared palette and one sun bound mobile lighting work.

const Architecture = preload("res://scripts/world/architecture.gd")
const Portal = preload("res://scenes/world/portal.tscn")
const Stand = preload("res://scripts/world/collection_stand.gd")
const Journal = preload("res://scripts/world/collection_journal.gd")
const Mount = preload("res://scripts/home/trophy_mount_visual.gd")
const Builder = preload("res://scripts/home/trophy_hall_builder.gd")
const HomeStyle = preload("res://scripts/home/home_visual_style.gd")
const IVORY = preload("res://resources/materials/home_ivory.tres")
const FLOOR = preload("res://resources/materials/home_floor.tres")
const BLUE = preload("res://resources/materials/home_royal_blue.tres")
const WINDOW = preload("res://resources/materials/home_window.tres")
const VisualStyle = preload("res://scripts/visual/visual_style.gd")

var display_name := "THE COLLECTION HALL"
var objective := "Your legacy in stone · Display owned equipment and study discoveries"
var stands: Dictionary = {}
var journals: Dictionary = {}
var trophy_unlocked := false
var _session: Node
var _last_revision := -1
var _trophy: Node3D
var _trophy_label: Label3D
var _completion_label: Label3D
var collection_completion: Dictionary = {}
var _home_origin_visit := false
var _palette: Dictionary = {}
var _record_label: Label3D

func configure_return_route(destination: StringName, entry_id: StringName) -> bool:
	# This visit's route is configured before attachment, never written to the
	# inventory or reused by a later direct Hall visit.
	if is_inside_tree() or _home_origin_visit or destination != &"personal_sanctuary" or entry_id != &"from_trophy_hall":
		return false
	_home_origin_visit = true
	return true

func is_home_origin_visit() -> bool:
	return _home_origin_visit

func _ready() -> void:
	add_to_group("collection_halls")
	_session = get_node_or_null("/root/ExpeditionSession")
	var kit := Architecture.new(self)
	_prepare_palette(kit)
	_build_architecture(kit)
	_build_displays(kit)
	_build_journals(kit)
	_build_trophy_wall(kit)
	_completion_label = kit.label("COLLECTION DISCOVERIES", Vector3(0, 2.9, 10.7), 25, Color("9ce3d8"))
	_completion_label.name = "CollectionCompletion"
	_completion_label.pixel_size = 0.004
	var portal := Portal.instantiate()
	portal.name = "SanctuaryReturn"
	portal.position = Vector3(0, 0, 13)
	portal.rotation.y = PI
	portal.destination = &"personal_sanctuary" if _home_origin_visit else &"sanctuary"
	portal.entry_id = &"from_trophy_hall" if _home_origin_visit else &"from_hall"
	portal.title = "RETURN TO PERSONAL SANCTUARY" if _home_origin_visit else "RETURN TO SANCTUARY"
	add_child(portal)
	_keep_static_collision(self)
	if is_instance_valid(_session):
		_session.changed.connect(_on_profile_changed)
	refresh_displays(true)
	preload("res://scripts/visual/static_visual_batcher.gd").bake(self, 12.0)

func _prepare_palette(kit: Architecture) -> void:
	# The Hall follows the saved home palette without modifying cached materials
	# used by the city, dungeon or inventory models.
	kit.palette["light_stone"] = IVORY.duplicate()
	kit.palette["stone"] = FLOOR.duplicate()
	kit.palette["cloth"] = BLUE.duplicate()
	kit.palette["window"] = WINDOW.duplicate()
	kit.palette["gold"] = kit.palette.gold.duplicate()
	_palette = kit.palette
	_refresh_palette()

func _refresh_palette() -> void:
	var theme := "royal_azure"
	if is_instance_valid(_session) and _session.has_method("home_snapshot"):
		theme = String(_session.home_snapshot().get("theme_id", "royal_azure"))
	var colors := HomeStyle.theme_colors(theme)
	for key: String in {"light_stone": "ivory", "stone": "floor", "cloth": "cloth", "window": "window", "gold": "gold"}:
		if not _palette.has(key): continue
		var source: String = {"light_stone": "ivory", "stone": "floor", "cloth": "cloth", "window": "window", "gold": "gold"}[key]
		var material := _palette[key] as StandardMaterial3D
		material.albedo_color = colors[source]
		if material.emission_enabled: material.emission = colors[source]

func _build_architecture(kit: Architecture) -> void:
	var environment := VisualStyle.apply_environment(self, &"hall")
	environment.environment.ambient_light_color = Color("b6c7d5")
	environment.environment.ambient_light_energy = 0.82
	environment.environment.fog_depth_begin = 26.0
	environment.environment.fog_depth_end = 62.0
	var key := get_node("WarmKey") as DirectionalLight3D
	key.light_color = Color("ffe2b4")
	key.light_energy = 0.95
	key.rotation_degrees = Vector3(-56, -28, 0)
	Builder.build(self, kit)
	VisualStyle.add_ambience(self, &"hall", Vector3(22, 5, 24), 55)

func _build_displays(kit: Architecture) -> void:
	for index in range(8):
		var stand := Stand.new()
		stand.stand_id = "equipment_%d" % index
		stand.name = "EquipmentDisplay_%02d" % (index + 1)
		stand.display_kind = "equipment"
		stand.shared_palette = kit.palette
		stand.position = Vector3(-8 if index < 4 else 8, 0, -8.5 + (index % 4) * 5.0)
		add_child(stand)
		stands[stand.stand_id] = stand
	for index in range(4):
		var stand := Stand.new()
		stand.stand_id = "relic_%d" % index
		stand.name = "RelicPedestal_%02d" % (index + 1)
		stand.display_kind = "relic"
		stand.shared_palette = kit.palette
		stand.position = Vector3(-3.8 if index < 2 else 3.8, 0, -9.5 + (index % 2) * 5.0)
		add_child(stand)
		stands[stand.stand_id] = stand

func _build_journals(kit: Architecture) -> void:
	for tab: String in ["items", "monsters"]:
		var journal := Journal.new()
		journal.name = "ItemJournal" if tab == "items" else "MonsterJournal"
		journal.tab = tab
		journal.position = Vector3(-4.5 if tab == "items" else 4.5, 0, 9.3)
		journal.shared_palette = kit.palette
		add_child(journal)
		journals[tab] = journal

func _build_trophy_wall(kit: Architecture) -> void:
	_trophy = Mount.build(self, kit.palette)
	_trophy_label = kit.label("ROOTWARDEN · TROPHY UNCLAIMED", Vector3(0, 1.8, -13.95), 28, Color("d0bc96"))
	_trophy_label.pixel_size = 0.005
	_record_label = kit.label("Discover the guardian to record its legacy", Vector3(0, 1.1, -13.9), 21, Color("b8c8c9"))
	_record_label.name = "RootwardenRecord"
	_record_label.pixel_size = 0.004

func _on_profile_changed(_snapshot: Dictionary) -> void:
	_refresh_palette()
	refresh_displays(false)

func refresh_displays(force: bool = true) -> void:
	if not is_instance_valid(_session):
		return
	var profile: Dictionary = _session.profile
	var revision := int(profile.get("revision", 0))
	if not force and revision == _last_revision:
		return
	_last_revision = revision
	var entries := {}
	for entry: Dictionary in profile.get("inventory", []):
		entries[String(entry.get("uid", ""))] = entry
	var displays: Dictionary = profile.get("displays", {})
	for id: String in stands:
		var uid := String(displays.get(id, ""))
		var entry: Dictionary = entries.get(uid, {})
		var definition := VaultLootTable.item_for(String(entry.get("item_id", "")))
		stands[id].set_display(entry, definition)
	trophy_unlocked = profile.get("discoveries", []).has("rootwarden_heart") or profile.get("monster_discoveries", []).has("rootwarden")
	collection_completion = completion_snapshot(profile, VaultLootTable.catalog())
	_completion_label.text = "DISCOVERIES %d / %d · TROPHIES %d / %d\nAvailable catalog discoveries" % [collection_completion.discovered, collection_completion.total, collection_completion.trophies, collection_completion.trophy_total]
	_trophy.visible = trophy_unlocked
	_trophy.get_node("CameraCollision/Shape").set_deferred("disabled", not trophy_unlocked)
	_record_label.text = rootwarden_record_text(profile, trophy_unlocked)
	_trophy_label.text = "ROOTWARDEN · GUARDIAN OF THE ABYSS" if trophy_unlocked else "ROOTWARDEN · TROPHY UNCLAIMED"

static func rootwarden_record_text(profile: Dictionary, unlocked: bool) -> String:
	# Read secured encounter evidence only. Older discoveries retain their
	# ownership, but no fictional historic date, depth or kill count is invented.
	if not unlocked: return "Discover the guardian to record its legacy"
	var records: Dictionary = profile.get("encounter_records", {}).get("entries", {})
	var entry: Dictionary = records.get("rootwarden", {})
	if entry.is_empty() or int(entry.get("secured_defeats", 0)) == 0:
		return "ROOTBOUND ABYSS · Discovery preserved\nDetailed records began after this discovery"
	var stamp := int(entry.get("first_recorded_utc", 0))
	var date := Time.get_date_string_from_unix_time(stamp) + " UTC" if stamp > 0 else "date unavailable"
	return "ROOTBOUND ABYSS · %d secured defeats · Depth %d\nFirst recorded: %s" % [int(entry.secured_defeats), int(entry.highest_recorded_depth), date]

static func completion_snapshot(profile: Dictionary, catalog: Dictionary) -> Dictionary:
	# Read-only discovery ledger, not an item grant. Future content is excluded.
	var result := {"discovered": 0, "total": 0, "trophies": 0, "trophy_total": 0}
	var discovered: Array = profile.get("discoveries", [])
	for definition: VaultItemDefinition in catalog.values():
		if not definition.obtainable or definition.catalog_group == "currency":
			continue
		result.total += 1
		var known := discovered.has(String(definition.id))
		if known:
			result.discovered += 1
		if definition.catalog_group == "trophy":
			result.trophy_total += 1
			if known:
				result.trophies += 1
	return result

func _keep_static_collision(node: Node) -> void:
	if node is StaticBody3D:
		node.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	for child: Node in node.get_children():
		_keep_static_collision(child)

func get_spawn_transform(_entry_id: StringName) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 9.5))
