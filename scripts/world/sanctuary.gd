extends Node3D
## The connected Sanctuary city reuses the original world and service contracts.

const Architecture = preload("res://scripts/world/architecture.gd")
const Portal = preload("res://scenes/world/portal.tscn")
const TrainingTarget = preload("res://scenes/world/training_target.tscn")
const Tavern = preload("res://scenes/party/tavern.tscn")
const Shop = preload("res://scenes/world/npc_shop.tscn")
const Terminal = preload("res://scripts/sanctuary/city_terminal.gd")
const CityBuilder = preload("res://scripts/sanctuary/sanctuary_city_builder.gd")
const DistrictArt = preload("res://scripts/sanctuary/sanctuary_district_art.gd")
const Landscape = preload("res://scripts/sanctuary/sanctuary_landscape.gd")
const Ambience = preload("res://scripts/sanctuary/sanctuary_ambience.gd")
const Fauna = preload("res://scripts/visual/ambient_fauna.gd")
const VisualStyle = preload("res://scripts/visual/visual_style.gd")
const CITY_LAYOUT = preload("res://resources/sanctuary/city_layout.tres")

var display_name := "THE SANCTUARY"
var objective := "Explore the eight districts · Find the city guide at the Ring Exchange"

func _ready() -> void:
	CityBuilder.build(self, CITY_LAYOUT)
	DistrictArt.build(self, CITY_LAYOUT)
	_build_portals()
	_build_market()
	_build_tavern()
	_build_training_court()
	_build_terminals()
	_build_scenery()
	VisualStyle.add_ambience(self, &"sanctuary", Vector3(23, 4, 24), 1055)
	preload("res://scripts/visual/static_visual_batcher.gd").bake(self, 8.0)

func _build_scenery() -> void:
	Landscape.new().build(self, CITY_LAYOUT, bool(get_tree().get_meta("capture_city_scenery_geometry", false)))
	var ambience := Ambience.new()
	ambience.configure(self, CITY_LAYOUT)
	add_child(ambience)
	for index in range(4):
		var angle := (float(index * 2) + 0.5) * TAU / 8.0
		var fauna := Fauna.new()
		fauna.position = Vector3(sin(angle), 0, -cos(angle)) * 30.9
		fauna.rotation.y = -angle
		fauna.configure(PackedVector3Array([Vector3(-0.45, 1.0, -0.25), Vector3(0.45, 1.15, 0.25), Vector3(-0.35, 0.9, 0.3), Vector3(0.35, 1.05, -0.3)]), 1071 + index, 4, self)
		add_child(fauna)

func _build_portals() -> void:
	for id: StringName in [&"dungeon", &"rootbound_abyss", &"combat_arena", &"collection_hall"]:
		var data: Dictionary = CITY_LAYOUT.get_poi(id)
		var portal := Portal.instantiate()
		portal.name = {&"dungeon": "PracticeGate", &"rootbound_abyss": "RootboundExpeditionGate", &"combat_arena": "ProvingGroundsGate", &"collection_hall": "CollectionHallGate"}[id]
		portal.position = data.position
		portal.rotation.y = data.rotation
		portal.destination = id
		portal.entry_id = &"from_sanctuary" if id == &"dungeon" else &"default"
		portal.title = String(data.label).to_upper()
		portal.require_entry_card = true
		portal.set_meta("sanctuary_poi", id)
		portal.set_meta("approach_position", data.approach)
		add_child(portal)

func _build_market() -> void:
	var counters := [
		{"id": &"merchant_appraiser", "kind": &"merchant", "vendor": "appraiser", "label": "Iris · Relic Appraiser", "color": Color("7c6f99")},
		{"id": &"merchant_general", "kind": &"merchant", "vendor": "general", "label": "Mara · General Merchant", "color": Color("668971")},
		{"id": &"merchant_equipment", "kind": &"merchant", "vendor": "equipment", "label": "Dain · Equipment Trader", "color": Color("577f91")},
		{"id": &"blacksmith", "kind": &"blacksmith", "vendor": "", "label": "Brann · Blacksmith", "color": Color("a47150")},
	]
	for counter: Dictionary in counters:
		var data: Dictionary = CITY_LAYOUT.get_poi(counter.id)
		var shop := Shop.instantiate()
		shop.name = "Blacksmith" if counter.kind == &"blacksmith" else String(counter.vendor).capitalize() + "Merchant"
		shop.position = data.position
		shop.rotation.y = data.rotation
		shop.service_kind = counter.kind
		shop.vendor = counter.vendor
		shop.display_name = counter.label
		shop.accent = counter.color
		shop.set_meta("sanctuary_poi", counter.id)
		shop.set_meta("approach_position", data.approach)
		add_child(shop)

func _build_tavern() -> void:
	var data: Dictionary = CITY_LAYOUT.get_poi(&"tavern")
	var tavern := Tavern.instantiate()
	tavern.name = "LanternAndRootTavern"
	tavern.position = data.position
	tavern.rotation.y = data.rotation
	tavern.set_meta("sanctuary_poi", &"tavern")
	tavern.set_meta("approach_position", data.approach)
	add_child(tavern)

func _build_training_court() -> void:
	var data: Dictionary = CITY_LAYOUT.get_poi(&"training_target")
	var target := TrainingTarget.instantiate()
	target.position = data.position
	target.rotation.y = data.rotation
	target.set_meta("sanctuary_poi", &"training_target")
	target.set_meta("approach_position", data.approach)
	add_child(target)
	var kit := Architecture.new(self)
	kit.ring(data.position + Vector3.UP * 0.055, 1.65, 1.7, "gold")
	var title := kit.label("PRACTICE COURT", data.position + Vector3.UP * 3.3, 24, Color("b8c9bd"))
	title.pixel_size = 0.004

func _build_terminals() -> void:
	var descriptions := {
		&"map": "The Ring Exchange connects eight Sanctuary districts. Choose a destination and follow its waypoint. Services are available when you reach them. The city is an offline local sanctuary; player trading is not available here.",
		&"equipment": "Preview your owned equipment and appearance using the existing equipment viewer. Cosmetic purchases and a separate cosmetic catalog are not available in this build.",
		&"conservatory": "Explore your secured collection and discoveries. The conservatory is a local guide; pet acquisition and an active pet companion are not available in this build.",
	}
	for id: StringName in [&"map", &"equipment", &"conservatory"]:
		var data: Dictionary = CITY_LAYOUT.get_poi(id)
		var terminal := Terminal.new()
		terminal.name = String(id).capitalize() + "CityTerminal"
		terminal.position = data.position
		terminal.rotation.y = data.rotation
		terminal.terminal_id = id
		terminal.title = data.label
		terminal.kind = data.kind
		terminal.description = descriptions[id]
		terminal.set_meta("sanctuary_poi", id)
		terminal.set_meta("approach_position", data.approach)
		add_child(terminal)
		var kit := Architecture.new(terminal)
		kit.cylinder(Vector3(0, 0.09, 0), 0.7, 0.18, "dark_stone", false, 8)
		kit.cylinder(Vector3(0, 0.48, 0), 0.35, 0.78, "stone", true, 8)
		kit.cylinder(Vector3(0, 0.88, 0), 0.72, 0.12, "gold", false, 8)
		var tablet := kit.box(Vector3(0, 1.02, 0), Vector3(1.05, 0.12, 0.72), "crystal" if id != &"map" else "paving_a")
		tablet.rotation.x = -0.22
		kit.ring(Vector3(0, 1.15, 0), 0.19, 0.23, "gold")
		var label := kit.label(String(data.label), Vector3(0, 1.8, 0), 25)
		label.pixel_size = 0.004

func get_city_layout() -> Dictionary:
	return CITY_LAYOUT.describe()

func get_service_approach_position(service: StringName) -> Vector3:
	var data: Dictionary = CITY_LAYOUT.get_service_poi(service)
	return to_global(data.get("approach", Vector3.ZERO))

func get_poi_approach_position(id: StringName) -> Vector3:
	var data: Dictionary = CITY_LAYOUT.get_poi(id)
	return to_global(data.get("approach", Vector3.ZERO))

func get_companion_navigation_profile() -> Dictionary:
	return {"mode": &"terraced_city", "floor_min": 0.0, "floor_max": 0.8}

func get_companion_navigation_graph() -> Dictionary:
	var graph: Dictionary = CITY_LAYOUT.navigation_graph()
	var points: PackedVector3Array = graph.points
	for index in range(points.size()):
		points[index] = to_global(points[index])
	graph.points = points
	return graph

func get_spawn_transform(entry_id: StringName) -> Transform3D:
	# These four original transforms are persistent transition contracts.
	var spawn_position := Vector3(0, 0.15, 8.0)
	if entry_id == &"from_dungeon":
		spawn_position = Vector3(0, 0.15, -5.4)
	if entry_id == &"from_abyss":
		return Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(3.5, 0.15, -5.5))
	if entry_id == &"from_hall":
		return Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-3.5, 0.15, -6.5))
	return Transform3D(Basis.IDENTITY, spawn_position)
