extends Node3D
## Personal display chamber. Saved UIDs select visuals; the scene never mutates
## inventory ownership. One shared palette and one sun bound mobile lighting work.

const Architecture = preload("res://scripts/world/architecture.gd")
const Portal = preload("res://scenes/world/portal.tscn")
const Stand = preload("res://scripts/world/collection_stand.gd")
const Journal = preload("res://scripts/world/collection_journal.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
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

func _ready() -> void:
	add_to_group("collection_halls")
	var kit := Architecture.new(self)
	_build_architecture(kit)
	_build_hall_ornament(kit)
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
	portal.destination = &"sanctuary"
	portal.entry_id = &"from_hall"
	portal.title = "RETURN TO SANCTUARY"
	add_child(portal)
	_keep_static_collision(self)
	_session = get_node_or_null("/root/ExpeditionSession")
	if is_instance_valid(_session):
		_session.changed.connect(_on_profile_changed)
	refresh_displays(true)
	preload("res://scripts/visual/static_visual_batcher.gd").bake(self)

func _build_architecture(kit: Architecture) -> void:
	kit.environment(true)
	for child: Node in get_children():
		if child is WorldEnvironment:
			child.environment = VisualStyle.environment_preset(&"hall")
		elif child is DirectionalLight3D:
			child.light_color = Color("f3d5a2")
			child.light_energy = 0.82
			child.rotation_degrees = Vector3(-58, -24, 0)
	kit.box(Vector3(0, -0.4, 0), Vector3(29, 0.8, 32), "dark_stone", true)
	kit.paving(14, 16, true)
	kit.box(Vector3(0, 2.4, -15.5), Vector3(29, 4.8, 0.65), "stone", true)
	kit.box(Vector3(0, 4.9, -15.5), Vector3(29.2, 0.2, 0.9), "gold")
	kit.box(Vector3(0, 0.65, 15.5), Vector3(29, 1.3, 0.65), "stone", true)
	kit.box(Vector3(0, 1.36, 15.5), Vector3(29.2, 0.13, 0.85), "gold")
	for side in [-1.0, 1.0]:
		kit.box(Vector3(side * 14.1, 1.65, 0), Vector3(0.7, 3.3, 31), "stone", true)
		kit.box(Vector3(side * 14.1, 3.4, 0), Vector3(0.9, 0.17, 31), "gold")
		kit.box(Vector3(side * 13.65, 0.35, 0), Vector3(0.12, 0.3, 30.5), "gold")
		for z in [-11.8, -5.4, 1.0, 7.4]:
			kit.column(Vector3(side * 11.8, 0, z), 4.0)
			# Open ribs suggest a vaulted castle ceiling without covering the tactical view.
			var rib := kit.box(Vector3(side * 9.95, 5.15, z), Vector3(4.1, 0.22, 0.5), "stone")
			rib.rotation.z = side * 0.35
			kit.box(Vector3(side * 11.8, 4.72, z), Vector3(1.4, 0.15, 1.0), "gold")
		for z in [-10.0, -2.0, 6.0, 12.0]:
			_lantern(kit, Vector3(side * 13.2, 2.35, z))
		kit.crystal_cluster(Vector3(side * 11.8, 0, 12.4), 0.85)
		kit.crystal_cluster(Vector3(side * 11.8, 0, -14.0), 0.75)
		kit.banner(Vector3(side * 5.4, 0, -14.65), 0 if side < 0 else PI)
	for z in range(-12, 12, 2):
		kit.box(Vector3(0, 0.04, z), Vector3(3.6, 0.03, 1.85), "path")
		for side in [-1.0, 1.0]:
			kit.box(Vector3(side * 1.86, 0.065, z), Vector3(0.055, 0.02, 1.85), "gold")
	kit.ring(Vector3(0, 0.09, 0), 2.7, 2.76, "gold")
	kit.ring(Vector3(0, 0.091, 0), 1.1, 1.15, "glow")
	var welcome := kit.label("THE HALL OF REMEMBERED DEPTHS", Vector3(0, 5.2, -13.5), 38, Color("e7c995"))
	welcome.pixel_size = 0.005

func _build_hall_ornament(kit: Architecture) -> void:
	var art := Dressing.new(self, kit.palette)
	# Wall-mounted reliefs occupy the existing boundary; the exhibition aisles stay open.
	for side in [-1.0, 1.0]:
		for z in [-8.5, -3.5, 1.5, 6.5]:
			art.box(Vector3(side * 13.67, 1.75, z), Vector3(0.05, 2.5, 2.7), "dark_stone")
			for offset in [-1.42, 1.42]:
				art.box(Vector3(side * 13.60, 1.75, z + offset), Vector3(0.06, 2.6, 0.065), "bronze")
			for height in [0.42, 3.08]:
				art.box(Vector3(side * 13.60, height, z), Vector3(0.06, 0.065, 2.9), "gold")
			art.facet(Vector3(side * 13.53, 2.25, z), Vector3(0.12, 0.48, 0.42), "crystal")
			art.box(Vector3(side * 13.48, 1.0, z), Vector3(0.18, 0.11, 1.35), "gold")
			# Repeated brass wedges visually link each stand with its carved wall niche.
			for offset in [-0.65, 0.0, 0.65]:
				art.box(Vector3(side * 9.8, 0.055, z + offset), Vector3(0.5, 0.015, 0.04), "bronze")
		for z in [-13.8, 10.8]:
			art.fern(Vector3(side * 12.9, 0.12, z), 0.85, z)
			art.blossom(Vector3(side * 12.65, 0.38, z + 0.2), 0.8)
		for z in range(-12, 12, 2):
			art.box(Vector3(side * 2.2, 0.055, z + 0.9), Vector3(0.27, 0.02, 0.27), "bronze", Basis(Vector3.UP, PI / 4.0))
		for x in [4.0, 7.0, 10.0, 12.5]:
			art.box(Vector3(side * x, 3.8, -15.07), Vector3(0.16, 1.4, 0.12), "gold")
			art.box(Vector3(side * x, 3.1, -15.03), Vector3(0.62, 0.14, 0.18), "bronze")
	for index in range(16):
		var angle := index * TAU / 16.0
		art.box(Vector3(sin(angle) * 2.1, 0.1, cos(angle) * 2.1), Vector3(0.06, 0.02, 0.4), "bronze", Basis(Vector3.UP, angle))
	art.flush("HallRelief")
	VisualStyle.add_ambience(self, &"hall", Vector3(22, 4, 24), 55)

func _lantern(kit: Architecture, at: Vector3) -> void:
	kit.box(at + Vector3(0, 0.45, 0), Vector3(0.36, 0.1, 0.36), "gold")
	kit.box(at, Vector3(0.25, 0.65, 0.25), "flame")
	kit.box(at + Vector3(0, -0.4, 0), Vector3(0.36, 0.12, 0.36), "gold")
	for x in [-0.16, 0.16]:
		kit.box(at + Vector3(x, 0, 0), Vector3(0.035, 0.85, 0.32), "dark_stone")

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
	kit.box(Vector3(0, 2.1, -15.05), Vector3(5.7, 3.7, 0.18), "dark_stone")
	for side in [-1.0, 1.0]:
		kit.box(Vector3(side * 2.95, 2.1, -14.9), Vector3(0.12, 4.0, 0.22), "gold")
	kit.box(Vector3(0, 4.1, -14.9), Vector3(6.0, 0.12, 0.22), "gold")
	kit.box(Vector3(0, 0.18, -14.9), Vector3(6.0, 0.12, 0.22), "gold")
	_trophy = Node3D.new()
	_trophy.name = "RootwardenTrophy"
	_trophy.position = Vector3(0, 1.5, -14.55)
	add_child(_trophy)
	kit.box(Vector3(0, 0.25, 0), Vector3(1.2, 1.3, 0.35), "wood", false, _trophy)
	kit.box(Vector3(0, 0.25, 0.25), Vector3(0.6, 0.5, 0.12), "gold", false, _trophy)
	for side in [-1.0, 1.0]:
		var branch := kit.box(Vector3(side * 0.9, 0.85, 0), Vector3(0.26, 1.55, 0.3), "wood", false, _trophy)
		branch.rotation.z = -side * 0.65
		var twig := kit.box(Vector3(side * 1.25, 1.2, 0), Vector3(0.15, 0.85, 0.2), "gold", false, _trophy)
		twig.rotation.z = -side * 0.9
		kit.box(Vector3(side * 0.25, 0.55, 0.26), Vector3(0.18, 0.1, 0.08), "glow", false, _trophy)
	var heart := kit.cone(Vector3(0, -0.1, 0.3), 0.28, 0.65, "crystal", _trophy)
	heart.rotation.z = PI
	var carving := Dressing.new(_trophy, kit.palette)
	for side in [-1.0, 1.0]:
		carving.facet(Vector3(side * 0.48, 0.35, 0.25), Vector3(0.35, 1.1, 0.3), "wood", side * 0.3)
		carving.facet(Vector3(side * 0.18, 0.94, 0.12), Vector3(0.22, 0.6, 0.18), "gold", side * 0.25)
		carving.beam(Vector3(side * 0.65, 0.65, 0.06), Vector3(side * 1.35, 0.74, 0.12), 0.14, 0.16, "wood")
		carving.beam(Vector3(side * 1.1, 0.7, 0.1), Vector3(side * 1.45, 1.0, 0.1), 0.08, 0.1, "bronze")
	carving.flush("RootwardenCarving")
	_trophy_label = kit.label("ROOTWARDEN · TROPHY UNCLAIMED", Vector3(0, 0.7, -14.1), 28, Color("d0bc96"))
	_trophy_label.pixel_size = 0.0045

func _on_profile_changed(_snapshot: Dictionary) -> void:
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
	_trophy_label.text = "ROOTWARDEN · GUARDIAN OF THE ABYSS" if trophy_unlocked else "ROOTWARDEN · TROPHY UNCLAIMED"

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
