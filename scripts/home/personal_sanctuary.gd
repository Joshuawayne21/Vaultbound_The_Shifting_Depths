extends Node3D
## Two-level single-height-field foyer. Progression owns every unlock/change;
## this scene reads committed appearance and retains existing travel contracts.

const Architecture = preload("res://scripts/world/architecture.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
const Style = preload("res://scripts/visual/visual_style.gd")
const Batcher = preload("res://scripts/visual/static_visual_batcher.gd")
const Portal = preload("res://scenes/world/portal.tscn")
const IVORY = preload("res://resources/materials/home_ivory.tres")
const FLOOR = preload("res://resources/materials/home_floor.tres")
const ROYAL_BLUE = preload("res://resources/materials/home_royal_blue.tres")
const WINDOW = preload("res://resources/materials/home_window.tres")
const Layout = preload("res://scripts/home/home_foyer_layout.gd")
const Builder = preload("res://scripts/home/home_foyer_builder.gd")
const HomeStyle = preload("res://scripts/home/home_visual_style.gd")
const Station = preload("res://scripts/home/home_management_station.gd")
const ENTRY_IDS := [&"default", &"from_sanctuary", &"from_trophy_hall", &"from_conservatory"]
# Match the existing player/companion scene capsules and VaultParty formation.
# Arrival tests independently compare these checks with the actual actor shapes.
const ACTOR_RADIUS := 0.34
const ACTOR_HEIGHT := 1.7
const FORMATION_SIDE := 1.6
const FORMATION_TRAIL := 2.2

var display_name := "PERSONAL SANCTUARY"
var objective := "Welcome home · Trophy Hall, Pet Conservatory and Home Management"
var _floor_body: StaticBody3D
var _management_station: Node3D
var _session: Node
var _palette: Dictionary = {}
var _sigil_holder: Node3D
var _sigil_forms: Dictionary = {}
var _sigil_material: StandardMaterial3D
var _chandelier: Node3D
var _motion_scale := 1.0
var _animation_time := 0.0
var _last_theme := ""
var _last_sigil := ""

func _ready() -> void:
	add_to_group("visual_quality")
	var kit := Architecture.new(self)
	# Mutable themes never tint shared cached world/item materials.
	kit.palette["gold"] = kit.palette.gold.duplicate()
	kit.palette["light_stone"] = IVORY.duplicate()
	kit.palette["stone"] = FLOOR.duplicate()
	kit.palette["cloth"] = ROYAL_BLUE.duplicate()
	kit.palette["path"] = kit.palette.cloth
	kit.palette["window"] = WINDOW.duplicate()
	_palette = kit.palette
	_build_environment()
	_floor_body = Builder.build(self, kit)
	_build_floor_sigil(kit)
	_build_floating_sigil()
	_build_chandelier(kit)
	_build_management_station(kit)
	_build_portals()
	Style.add_ambience(self, &"hall", Vector3(20, 5, 20), 621)
	_session = get_node_or_null("/root/ExpeditionSession")
	if is_instance_valid(_session):
		_session.changed.connect(_on_profile_changed)
	_refresh_saved_appearance()
	# The enclosed foyer benefits from slightly larger static batches.
	# Keep cells local to each wing; collision and animated art stay independent.
	Batcher.bake(self, 12.0)
	var settings := get_node_or_null("/root/VisualSettings")
	if settings != null: apply_visual_settings(settings.snapshot())

func _build_environment() -> void:
	var environment := Style.apply_environment(self, &"hall")
	# The preset is duplicated by Style: these adjustments are home-local.
	environment.environment.ambient_light_color = Color("b6c7d5")
	environment.environment.ambient_light_energy = 0.82
	environment.environment.fog_depth_begin = 24.0
	environment.environment.fog_depth_end = 58.0
	var key := get_node("WarmKey") as DirectionalLight3D
	key.light_color = Color("ffe2b4")
	key.light_energy = 0.95
	key.rotation_degrees = Vector3(-56, -28, 0)

func _build_floor_sigil(kit: Architecture) -> void:
	kit.cylinder(Vector3(0, 0.035, 0), 3.2, 0.025, "dark_stone", false, 48)
	kit.ring(Vector3(0, 0.055, 0), 3.05, 3.12, "gold")
	kit.ring(Vector3(0, 0.056, 0), 2.4, 2.44, "crystal")
	kit.ring(Vector3(0, 0.057, 0), 1.05, 1.1, "gold")
	var art := Dressing.new(self, kit.palette)
	for index in range(12):
		var angle := float(index) * TAU / 12.0
		art.box(Vector3(sin(angle) * 2.73, 0.06, cos(angle) * 2.73), Vector3(0.07, 0.015, 0.33), "gold", Basis(Vector3.UP, angle))
	art.box(Vector3(0, 0.062, 0), Vector3(1.42, 0.012, 1.42), "gold", Basis(Vector3.UP, PI / 4.0))
	art.box(Vector3(0, 0.077, 0), Vector3(1.14, 0.012, 1.14), "crystal", Basis(Vector3.UP, PI / 4.0))
	art.flush("FoyerSigil")

func _build_management_station(kit: Architecture) -> void:
	var station := Station.new()
	station.name = "HomeManagementStation"
	station.position = Vector3(-3.1, 0, 1.2)
	station.rotation.y = PI / 2.0
	if not station.configure(self):
		station.free()
		return
	_management_station = station
	add_child(station)
	kit.cylinder(Vector3(0, 0.1, 0), 0.58, 0.2, "dark_stone", true, 10, station)
	kit.cylinder(Vector3(0, 0.6, 0), 0.28, 1.0, "light_stone", true, 10, station)
	kit.box(Vector3(0, 1.13, 0), Vector3(1.0, 0.12, 0.7), "gold", true, station)
	kit.box(Vector3(0, 1.21, 0), Vector3(0.86, 0.05, 0.57), "window", false, station)

func home_management_station() -> Node3D:
	return _management_station if is_instance_valid(_management_station) else null

func get_companion_navigation_profile() -> Dictionary:
	# This world uses an identity root. There is no traversable lower floor under
	# a gallery: solid plinths retain the existing single-height-field contract.
	return {"mode": &"terraced_city", "floor_min": global_position.y, "floor_max": global_position.y + Layout.UPPER_HEIGHT}

func get_companion_navigation_graph() -> Dictionary:
	var graph := Layout.navigation_graph()
	var points: PackedVector3Array = graph.points
	for index in range(points.size()): points[index] = to_global(points[index])
	graph.points = points
	return graph

func _build_floating_sigil() -> void:
	_sigil_holder = Node3D.new()
	_sigil_holder.name = "CentralHouseSigil"
	_sigil_holder.position = Vector3(0, 6.8, 0)
	_sigil_holder.rotation.y = PI / 4.0
	_sigil_holder.set_meta("dynamic_visual", true)
	add_child(_sigil_holder)
	_sigil_material = StandardMaterial3D.new()
	_sigil_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sigil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sigil_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sigil_material.albedo_color = Color(0.5, 0.9, 1.0, 0.43)
	# This is a translucent hologram, not opaque structure: no body or light.
	for id: String in HomeStyle.SIGILS:
		var node := MeshInstance3D.new()
		node.name = String(id).to_pascal_case()
		node.mesh = _motif_mesh(HomeStyle.sigil_outline(id))
		node.material_override = _sigil_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		_sigil_holder.add_child(node)
		_sigil_forms[id] = node
	var ring := TorusMesh.new()
	ring.inner_radius = 1.65
	ring.outer_radius = 1.72
	ring.rings = 24
	ring.ring_segments = 4
	for index in range(2):
		var node := MeshInstance3D.new()
		node.name = "HologramOrbit%d" % index
		node.mesh = ring
		node.material_override = _sigil_material
		node.rotation_degrees = Vector3(28 if index == 0 else -28, 0, 18 if index == 0 else -18)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sigil_holder.add_child(node)

func _motif_mesh(outline: PackedVector2Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(outline.size() - 1):
		var a := outline[index] * 1.3
		var b := outline[index + 1] * 1.3
		var normal := Vector2(-(b - a).y, (b - a).x).normalized() * 0.045
		var corners := [a - normal, b - normal, b + normal, a + normal]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			var point: Vector2 = corners[corner]
			surface.set_normal(Vector3.FORWARD)
			surface.add_vertex(Vector3(point.x, point.y, 0))
	return surface.commit()

func _build_chandelier(kit: Architecture) -> void:
	_chandelier = Node3D.new()
	_chandelier.name = "FoyerChandelier"
	_chandelier.position = Vector3(0, 20.5, 0)
	_chandelier.set_meta("dynamic_visual", true)
	add_child(_chandelier)
	kit.ring(Vector3.ZERO, 1.9, 2.05, "gold", _chandelier)
	kit.ring(Vector3(0, 1.1, 0), 0.65, 0.74, "gold", _chandelier)
	for index in range(8):
		var angle := float(index) * TAU / 8.0
		var at := Vector3(sin(angle) * 1.95, -0.35, cos(angle) * 1.95)
		kit.cylinder(at, 0.045, 0.7, "gold", false, 6, _chandelier)
		kit.cone(at + Vector3.DOWN * 0.55, 0.18, 0.65, "crystal", _chandelier)
	var blocker := StaticBody3D.new()
	blocker.name = "ChandelierCameraOccluder"
	blocker.position = Vector3(0, 20.5, 0)
	blocker.collision_layer = 8
	blocker.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.5, 3.4, 4.5)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	blocker.add_child(collider)
	add_child(blocker)

func apply_visual_settings(settings: Dictionary) -> void:
	_motion_scale = clampf(float(settings.get("decorative_motion_scale", 0.0 if settings.get("reduced_motion", false) else 1.0)), 0.0, 1.0)
	if is_instance_valid(_sigil_material):
		var color := _sigil_material.albedo_color
		color.a = 0.25 if bool(settings.get("reduced_effects", false)) else 0.43
		_sigil_material.albedo_color = color

func _process(delta: float) -> void:
	if _motion_scale <= 0.0 or not is_visible_in_tree(): return
	_animation_time += minf(maxf(delta, 0.0), 0.1) * _motion_scale
	if is_instance_valid(_sigil_holder):
		_sigil_holder.position.y = 6.8 + sin(_animation_time * 0.8) * 0.12
		_sigil_holder.rotation.y = PI / 4.0 + sin(_animation_time * 0.25) * 0.16
	if is_instance_valid(_chandelier):
		_chandelier.position.y = 20.5 + sin(_animation_time * 0.4) * 0.045
		_chandelier.rotation.y = sin(_animation_time * 0.18) * 0.035

func _on_profile_changed(_data: Dictionary) -> void:
	_refresh_saved_appearance()

func _refresh_saved_appearance() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	if is_instance_valid(_session) and _session.has_method("home_snapshot"):
		apply_home_presentation(_session.home_snapshot())
		_refresh_room_plaques()
	else:
		apply_home_presentation({"theme_id": "royal_azure", "sigil_id": "vault_diamond"})

func _refresh_room_plaques() -> void:
	# Read-only progress display. The catalog and Session alone own eligibility;
	# a claimed milestone never turns an unfinished door into a destination.
	if not is_instance_valid(_session) or not _session.has_method("home_management_snapshot"): return
	var snapshot: Dictionary = _session.home_management_snapshot()
	for row: Dictionary in snapshot.get("rooms", []):
		var frame := get_node_or_null("FutureDoor_" + String(row.get("id", "")))
		if frame == null: continue
		var plaque := frame.get_node_or_null("RequirementPlaque") as Label3D
		if plaque == null: continue
		var status := "MILESTONE EARNED" if bool(row.get("unlocked", false)) else "MILESTONE READY" if bool(row.get("eligible", false)) else "LOCKED"
		var implemented := String(row.get("id", "")) == "pet_conservatory"
		var availability := "ENTER · USE" if bool(row.get("available", false)) else "RECORD AT HOME MANAGEMENT" if implemented and bool(row.get("eligible", false)) else "LOCKED" if implemented else "NOT YET OPEN"
		frame.set_meta("room_available", bool(row.get("available", false)))
		plaque.text = "%s\n%s · %s\n%s · %s" % [String(row.get("label", "Room")).to_upper(), String(row.get("requirement", "")), String(row.get("progress", "")), status, availability]

func apply_home_presentation(snapshot: Dictionary) -> void:
	var theme := String(snapshot.get("theme_id", "royal_azure"))
	var sigil := String(snapshot.get("sigil_id", "vault_diamond"))
	if not HomeStyle.THEMES.has(theme): theme = "royal_azure"
	if sigil not in HomeStyle.SIGILS: sigil = "vault_diamond"
	if theme != _last_theme:
		var colors := HomeStyle.theme_colors(theme)
		for key: String in {"light_stone": "ivory", "stone": "floor", "cloth": "cloth", "window": "window", "gold": "gold"}:
			var source: String = {"light_stone": "ivory", "stone": "floor", "cloth": "cloth", "window": "window", "gold": "gold"}[key]
			var material := _palette[key] as StandardMaterial3D
			material.albedo_color = colors[source]
			if material.emission_enabled: material.emission = colors[source]
		if is_instance_valid(_sigil_material):
			var color: Color = colors.hologram
			color.a = _sigil_material.albedo_color.a
			_sigil_material.albedo_color = color
		_last_theme = theme
	if sigil != _last_sigil:
		for id: String in _sigil_forms: _sigil_forms[id].visible = id == sigil
		_last_sigil = sigil

func _build_portals() -> void:
	var return_portal := Portal.instantiate()
	return_portal.name = "SanctuaryReturn"
	return_portal.position = Vector3(0, 0, 12)
	return_portal.rotation.y = PI
	return_portal.destination = &"sanctuary"
	return_portal.entry_id = &"from_hall"
	return_portal.title = "RETURN TO SANCTUARY"
	add_child(return_portal)
	var trophy_portal := Portal.instantiate()
	trophy_portal.name = "TrophyHallDoor"
	trophy_portal.position = Vector3(0, 0, -10)
	trophy_portal.destination = &"collection_hall"
	trophy_portal.entry_id = &"from_home"
	trophy_portal.title = "TROPHY HALL · YOUR COLLECTION"
	add_child(trophy_portal)

func get_spawn_transform(entry_id: StringName) -> Transform3D:
	if entry_id == &"from_conservatory":
		return global_transform * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(4.2, 0.15, 4))
	if entry_id == &"from_trophy_hall":
		return global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.15, -6.5))
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 8))

func validate_home_arrival(entry_id: StringName) -> bool:
	# Run only at travel boundaries, after physics registration. Retained sibling
	# levels are excluded so their old floors cannot admit or obstruct this room.
	if entry_id not in ENTRY_IDS or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(_floor_body):
		return false
	if not _floor_body.is_inside_tree() or not is_ancestor_of(_floor_body):
		return false
	var spawn := get_spawn_transform(entry_id)
	if not spawn.is_finite() or not spawn.basis.is_conformal() or not is_equal_approx(spawn.basis.determinant(), 1.0):
		return false
	var excluded: Array[RID] = []
	for sibling: Node in get_parent().get_children():
		if sibling == self or not sibling is Node3D or not sibling.has_method("get_spawn_transform"):
			continue
		for body: Node in sibling.find_children("*", "CollisionObject3D", true, false):
			excluded.append((body as CollisionObject3D).get_rid())
	var facing := -spawn.basis.z.normalized()
	var side := Vector3(-facing.z, 0, facing.x)
	var positions: Array[Vector3] = [spawn.origin,
		spawn.origin - facing * FORMATION_TRAIL - side * FORMATION_SIDE,
		spawn.origin - facing * FORMATION_TRAIL + side * FORMATION_SIDE]
	var capsule := CapsuleShape3D.new()
	capsule.radius = ACTOR_RADIUS
	capsule.height = ACTOR_HEIGHT
	var space := get_world_3d().direct_space_state
	for point: Vector3 in positions:
		for offset: Vector3 in [Vector3.ZERO, Vector3(ACTOR_RADIUS, 0, 0), Vector3(-ACTOR_RADIUS, 0, 0), Vector3(0, 0, ACTOR_RADIUS), Vector3(0, 0, -ACTOR_RADIUS)]:
			var ray := PhysicsRayQueryParameters3D.create(point + offset + Vector3.UP * 0.5, point + offset - Vector3.UP * 0.5, 1)
			ray.exclude = excluded
			ray.collide_with_areas = false
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.collider != _floor_body or Vector3(hit.normal).dot(Vector3.UP) < 0.98:
				return false
			if absf(Vector3(hit.position).y - (spawn.origin.y - 0.15)) > 0.025:
				return false
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(spawn.basis, point + Vector3.UP * ACTOR_HEIGHT * 0.5)
		query.collision_mask = 1 | 16
		query.exclude = excluded
		query.margin = 0.005
		query.collide_with_areas = false
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true
