extends Node3D
## Compact handcrafted layout; reusable primitives keep the repository self-contained.

const Architecture = preload("res://scripts/world/architecture.gd")
const Portal = preload("res://scenes/world/portal.tscn")
const TrainingTarget = preload("res://scenes/world/training_target.tscn")
const Tavern = preload("res://scenes/party/tavern.tscn")
const Shop = preload("res://scenes/world/npc_shop.tscn")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
const VisualStyle = preload("res://scripts/visual/visual_style.gd")

var display_name := "THE SANCTUARY"
var objective := "West: Tavern & Hall · South: merchants & forge · East: expedition"

func _ready() -> void:
	var kit := Architecture.new(self)
	kit.environment(false)
	kit.box(Vector3(0, -0.45, 0), Vector3(27, 0.9, 29), "dark_stone", true)
	kit.paving(13, 14)
	_build_border(kit)
	_build_heart(kit)
	_build_garden(kit)
	_build_visual_pass(kit)
	var tavern := Tavern.instantiate()
	tavern.position = Vector3(-6.8, 0, 0)
	add_child(tavern)
	var portal := Portal.instantiate()
	portal.position = Vector3(0, 0, -10.0)
	portal.destination = &"dungeon"
	portal.entry_id = &"from_sanctuary"
	portal.title = "THE SHIFTING DEPTHS"
	add_child(portal)
	var expedition_gate := Portal.instantiate()
	expedition_gate.name = "RootboundExpeditionGate"
	expedition_gate.position = Vector3(7.0, 0, -5.5)
	expedition_gate.rotation.y = -PI / 2.0
	expedition_gate.destination = &"rootbound_abyss"
	expedition_gate.entry_id = &"default"
	expedition_gate.title = "ROOTBOUND ABYSS · EXPEDITION"
	add_child(expedition_gate)
	var hall_gate := Portal.instantiate()
	hall_gate.name = "CollectionHallGate"
	hall_gate.position = Vector3(-7.0, 0, -6.5)
	hall_gate.rotation.y = PI / 2.0
	hall_gate.destination = &"collection_hall"
	hall_gate.entry_id = &"default"
	hall_gate.title = "COLLECTION HALL · YOUR LEGACY"
	add_child(hall_gate)
	_build_market()
	var target := TrainingTarget.instantiate()
	target.position = Vector3(5.0, 0, 0.2)
	add_child(target)
	kit.ring(Vector3(5.0, 0.055, 0.2), 1.65, 1.7, "gold")
	kit.label("TRAINING COURT", Vector3(5.0, 0.18, 2.5), 23, Color("b8c9bd"))
	preload("res://scripts/visual/static_visual_batcher.gd").bake(self)

func _build_market() -> void:
	var counters := [
		{"x": -8.0, "kind": &"merchant", "vendor": "appraiser", "label": "Iris · Relic Appraiser", "color": Color("7c6f99")},
		{"x": -3.8, "kind": &"merchant", "vendor": "general", "label": "Mara · General Merchant", "color": Color("668971")},
		{"x": 3.8, "kind": &"merchant", "vendor": "equipment", "label": "Dain · Equipment Trader", "color": Color("577f91")},
		{"x": 8.0, "kind": &"blacksmith", "vendor": "", "label": "Brann · Blacksmith", "color": Color("a47150")},
	]
	for counter: Dictionary in counters:
		var shop := Shop.instantiate()
		shop.name = "Blacksmith" if counter.kind == &"blacksmith" else String(counter.vendor).capitalize() + "Merchant"
		shop.position = Vector3(counter.x, 0, 10.6)
		shop.rotation.y = PI
		shop.service_kind = counter.kind
		shop.vendor = counter.vendor
		shop.display_name = counter.label
		shop.accent = counter.color
		add_child(shop)

func _build_border(kit: Architecture) -> void:
	# Low camera-friendly boundaries, with a taller silhouette at the rear.
	kit.box(Vector3(0, 1.35, -14), Vector3(27, 2.7, 0.8), "stone", true)
	kit.box(Vector3(0, 2.8, -14), Vector3(27.3, 0.24, 1.0), "light_stone")
	for side in [-1.0, 1.0]:
		kit.box(Vector3(side * 13.25, 0.75, 0), Vector3(0.65, 1.5, 28), "stone", true)
		kit.box(Vector3(side * 13.25, 1.56, 0), Vector3(0.85, 0.18, 28), "light_stone")
		for z in [-11.5, -4.5, 3.0, 10.5]:
			kit.column(Vector3(side * 11.9, 0, z), 3.7 if z < -10.0 else 2.9)
		kit.box(Vector3(side * 9.0, 0.55, 14), Vector3(8.5, 1.1, 0.7), "stone", true)
		kit.box(Vector3(side * 9.0, 1.16, 14), Vector3(8.6, 0.16, 0.9), "light_stone")
		kit.column(Vector3(side * 4.2, 0, 13.6), 2.0)
	# A continuous low outer collision boundary closes the entrance view.
	kit.box(Vector3(0, 0.35, 14.1), Vector3(8.0, 0.7, 0.5), "dark_stone", true)

func _build_heart(kit: Architecture) -> void:
	kit.cylinder(Vector3(0, 0.04, 0), 3.2, 0.07, "dark_stone", false, 48)
	kit.ring(Vector3(0, 0.085, 0), 2.8, 2.85, "gold")
	kit.ring(Vector3(0, 0.086, 0), 1.2, 1.24, "gold")
	for i in range(8):
		var angle := i * TAU / 8.0
		var rune := kit.box(Vector3(sin(angle) * 2.1, 0.09, cos(angle) * 2.1), Vector3(0.13, 0.025, 0.42), "gold")
		rune.rotation.y = angle
	var diamond := kit.box(Vector3(0, 0.09, 0), Vector3(0.66, 0.025, 0.66), "glow")
	diamond.rotation.y = PI / 4.0
	for z in [-7.5, -5.5, 5.5, 7.5, 9.5, 11.5]:
		kit.box(Vector3(0, 0.04, z), Vector3(2.9, 0.03, 1.85), "path")
		for side in [-1.0, 1.0]:
			kit.box(Vector3(side * 1.55, 0.065, z), Vector3(0.055, 0.02, 1.8), "gold")
	for side in [-1.0, 1.0]:
		kit.brazier(Vector3(side * 3.7, 0, -7.8))
		kit.banner(Vector3(side * 5.0, 0, -9.7), 0 if side < 0.0 else PI)
		kit.column(Vector3(side * 5.0, 0, -12.6), 4.4)
		kit.box(Vector3(side * 5.0, 4.95, -12.6), Vector3(3.5, 0.3, 1.4), "stone")

func _build_garden(kit: Architecture) -> void:
	for pos in [Vector3(-9.1, 0, -9.2), Vector3(9.1, 0, -9.2), Vector3(-9.1, 0, 8.1), Vector3(9.1, 0, 8.1)]:
		kit.planter(pos, true)
	for pos in [Vector3(-9.5, 0, -2.0), Vector3(9.5, 0, -2.0), Vector3(-9.5, 0, 2.0), Vector3(9.5, 0, 2.0)]:
		kit.planter(pos)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(side * 8.6, 0.45, 5.0), Vector3(3.0, 0.35, 0.9), "light_stone", true)
		for dx in [-1.0, 1.0]:
			kit.box(Vector3(side * 8.6 + dx, 0.22, 5.0), Vector3(0.3, 0.44, 0.7), "dark_stone")
		kit.crystal_cluster(Vector3(side * 7.5, 0, -11.5), 0.6)

func _build_visual_pass(kit: Architecture) -> void:
	# The suspended heart leaves the original plaza, aim lines and formation space open.
	var art := Dressing.new(self, kit.palette)
	art.facet(Vector3(0, 4.9, 0), Vector3(1.0, 1.65, 1.0), "crystal", PI / 6.0)
	art.facet(Vector3(0, 4.9, 0.01), Vector3(0.48, 1.85, 0.48), "glow", PI / 6.0)
	for index in range(4):
		var angle := PI / 4.0 + index * TAU / 4.0
		art.facet(Vector3(sin(angle) * 0.88, 4.2, cos(angle) * 0.88), Vector3(0.24, 0.48, 0.24), "gold", angle)
	kit.ring(Vector3(0, 3.88, 0), 1.02, 1.065, "gold")
	_camera_only_box(Vector3(0, 4.9, 0), Vector3(1.05, 2.45, 1.05))
	for index in range(12):
		var angle := index * TAU / 12.0
		var radial := Vector3(sin(angle), 0, cos(angle))
		art.box(radial * 2.5 + Vector3.UP * 0.105, Vector3(0.045, 0.02, 0.42), "gold", Basis(Vector3.UP, angle))
		art.box(radial * 3.0 + Vector3.UP * 0.075, Vector3(0.18, 0.025, 0.18), "glow", Basis(Vector3.UP, angle + PI / 4.0))
	# Pale stone courses and bronze panels articulate the existing wall silhouette.
	for side in [-1.0, 1.0]:
		for x in [3.3, 7.1, 10.6]:
			art.box(Vector3(side * x, 1.5, -13.53), Vector3(0.3, 2.5, 0.12), "dark_stone")
			art.box(Vector3(side * x, 2.78, -13.48), Vector3(0.55, 0.12, 0.2), "gold")
		for x in [3.95, 6.4, 8.1, 11.8]:
			art.inset(Vector3(side * x, 0.9, -13.48), Vector2(0.65, 1.35))
			art.facet(Vector3(side * x, 1.6, -13.4), Vector3(0.18, 0.3, 0.07), "glow")
		for z in [-10.0, -6.3, -0.7, 4.8, 9.7]:
			art.box(Vector3(side * 12.87, 0.86, z), Vector3(0.045, 0.48, 1.45), "dark_stone")
			art.box(Vector3(side * 12.82, 0.6, z), Vector3(0.055, 0.055, 1.5), "gold")
		# The water runs against an existing solid boundary. Shallow pools stay flat.
		_build_wall_spring(kit, side)
		for z in [-11.8, -7.0, -0.8, 4.0, 11.8]:
			var at := Vector3(side * 12.5, 0.05, z)
			art.fern(at, 0.85, z)
			art.blossom(at + Vector3(-side * 0.25, 0.35, 0.12), 0.8)
		for pos in [Vector3(side * 9.1, 0.57, -9.2), Vector3(side * 9.1, 0.57, 8.1), Vector3(side * 9.5, 0.57, 2.0)]:
			art.fern(pos + Vector3(-0.35, 0, 0.1), 0.7, pos.z)
			art.blossom(pos + Vector3(0.3, 0.25, 0.15), 1.05)
		# Decorative risers belong to the wall apron, not the playable route.
		for step in range(3):
			art.box(Vector3(side * 11.75, 0.02 + step * 0.02, -12.4 - step * 0.35), Vector3(2.1, 0.025, 0.28), "light_stone")
	art.flush("SanctuaryOrnament")
	VisualStyle.add_ambience(self, &"sanctuary", Vector3(23, 4, 24), 1055)

func _build_wall_spring(kit: Architecture, side: float) -> void:
	var x := side * 10.0
	kit.box(Vector3(x, 1.35, -13.55), Vector3(1.5, 2.3, 0.09), "dark_stone")
	kit.box(Vector3(x, 2.52, -13.44), Vector3(1.8, 0.12, 0.32), "gold")
	var water := kit.box(Vector3(x, 1.25, -13.46), Vector3(0.75, 2.3, 0.025), "glow")
	water.material_override = load("res://resources/materials/abyss_water.tres")
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pool := kit.cylinder(Vector3(x, 0.06, -12.9), 0.9, 0.025, "glow", false, 20)
	pool.scale.z = 0.62
	pool.material_override = load("res://resources/materials/abyss_water.tres")
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shore := kit.ring(Vector3(x, 0.075, -12.9), 0.88, 0.92, "gold")
	shore.scale.z = 0.62

func _camera_only_box(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "HeartCameraOccluder"
	body.collision_layer = 8
	body.collision_mask = 0
	body.position = at
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	shape.shape = bounds
	body.add_child(shape)
	add_child(body)

func get_spawn_transform(entry_id: StringName) -> Transform3D:
	var position := Vector3(0, 0.15, 8.0)
	if entry_id == &"from_dungeon":
		position = Vector3(0, 0.15, -5.4)
	if entry_id == &"from_abyss":
		return Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(3.5, 0.15, -5.5))
	if entry_id == &"from_hall":
		return Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-3.5, 0.15, -6.5))
	return Transform3D(Basis.IDENTITY, position)
