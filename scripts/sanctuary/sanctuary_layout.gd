class_name SanctuaryLayout
extends Resource
## One authored source for city geometry, map destinations and grounded AI routes.

@export var radius := 45.0
@export var exchange_radius := 16.0
@export var ring_radius := 19.0
@export var ring_width := 6.0
@export var district_radius := 33.0
@export var path_width := 8.0
@export var terrace_height := 0.8
@export var ramp_length := 8.0

const CAPITAL = preload("res://resources/sanctuary/prismheart_capital.tres")
const COURTYARD = preload("res://resources/sanctuary/exchange_courtyard.tres")

const DISTRICT_NAMES := ["Portal Promenade", "Combat Coliseum", "Merchant Terraces", "Personal Sanctuary & Trophy Hall", "Master Forge", "Cosmetic Pavilion", "Spiritweaving Conservatory", "Tavern & Recruitment"]
const DISTRICT_POIS := [&"rootbound_abyss", &"combat_arena", &"merchant_general", &"collection_hall", &"blacksmith", &"equipment", &"conservatory", &"tavern"]

func district_transform(id: StringName) -> Transform3D:
	var index := clampi(String(id).unicode_at(0) - 65, 0, 7) if not String(id).is_empty() else 0
	var angle := index * TAU / 8.0
	var height := terrace_height if index in [4, 7] else 0.0
	return Transform3D(Basis(Vector3.UP, -angle), Vector3(sin(angle) * district_radius, height, -cos(angle) * district_radius))

func get_districts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(8):
		var id := StringName(String.chr(65 + index))
		var transform := district_transform(id)
		var approach := transform * Vector3(0, 0, 0 if index in [4, 7] else 2.5)
		result.append({"id": id, "name": DISTRICT_NAMES[index], "label": "%s · %s" % [id, DISTRICT_NAMES[index]], "center": transform.origin, "approach": approach, "angle": index * TAU / 8.0, "height": transform.origin.y, "poi_id": DISTRICT_POIS[index]})
	return result

func get_pois() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append(_poi(&"rootbound_abyss", "Rootbound Abyss", &"A", Vector3(-3.5, 0, -2), 2.1, &"portal"))
	result.append(_poi(&"dungeon", "Sunken Vault · Practice", &"A", Vector3(3.5, 0, -2), 2.1, &"portal"))
	result.append(_poi(&"combat_arena", "Proving Grounds", &"B", Vector3(-2.1, 0, -2), 2.1, &"portal"))
	result.append(_poi(&"training_target", "Practice Sentinel", &"B", Vector3(3.0, 0, 0.3), 2.0, &"training"))
	result.append(_poi(&"merchant_appraiser", "Iris · Relic Appraiser", &"C", Vector3(-4.2, 0, -2), 1.6, &"merchant"))
	result.append(_poi(&"merchant_general", "Mara · General Merchant", &"C", Vector3(0, 0, -2), 1.6, &"merchant"))
	result.append(_poi(&"merchant_equipment", "Dain · Equipment Trader", &"C", Vector3(4.2, 0, -2), 1.6, &"merchant"))
	result.append(_poi(&"collection_hall", "Personal Sanctuary · Your Home", &"D", Vector3(0, 0, -2), 2.1, &"portal"))
	result.append(_poi(&"blacksmith", "Brann · Master Forge", &"E", Vector3(0, 0, -1.4), 1.6, &"blacksmith"))
	result.append(_poi(&"equipment", "Equipment & Appearance Preview", &"F", Vector3.ZERO, 1.8, &"equipment"))
	result.append(_poi(&"conservatory", "Conservatory & Collection Guide", &"G", Vector3.ZERO, 1.8, &"conservatory"))
	result.append(_poi(&"tavern", "The Lantern & Root · Recruitment", &"H", Vector3(0, 0, -1), 1.8, &"recruitment"))
	result.append({"id": &"map", "label": "Ring Exchange · City Guide", "district": &"exchange", "position": Vector3(-10, 0, 8), "approach": Vector3(-8.5, 0, 8), "kind": &"map", "rotation": PI / 2.0})
	return result

func get_exchange_booths() -> Array[Dictionary]:
	# Independent authored interaction anchors, all bound by Sanctuary to one
	# shared DEMO exchange adapter. The legacy map terminal stays where it is.
	var result: Array[Dictionary] = []
	for index in range(6):
		var angle := deg_to_rad(90.0 + 60.0 * float(index))
		var basis := Basis(Vector3.UP, -angle)
		var at := Vector3(sin(angle), 0, -cos(angle)) * float(CAPITAL.booth_radius)
		result.append({"id": StringName("exchange_%02d" % (index + 1)), "number": index + 1,
			"label": "Ring Exchange %02d · DEMO" % (index + 1), "district": &"exchange",
			"position": at, "approach": at + basis * Vector3(0, 0, 2.2),
			"kind": &"map", "rotation": -angle})
	return result

func _poi(id: StringName, label: String, district: StringName, local_position: Vector3, approach_distance: float, kind: StringName) -> Dictionary:
	var transform := district_transform(district)
	return {"id": id, "label": label, "district": district, "position": transform * local_position, "approach": transform * (local_position + Vector3(0, 0, approach_distance)), "kind": kind, "rotation": transform.basis.get_euler().y}

func get_poi(id: StringName) -> Dictionary:
	for poi: Dictionary in get_pois():
		if poi.id == id:
			return poi
	for booth: Dictionary in get_exchange_booths():
		if booth.id == id:
			return booth
	for district: Dictionary in get_districts():
		if district.id == id:
			return {"id": id, "label": district.label, "district": id, "position": district.center, "approach": district.approach, "kind": &"district"}
	return {}

func get_exchange_connections() -> Array[Dictionary]:
	# Existing graph, arrival and service coordinates stay unchanged. E/H reuse
	# their authored ramp rather than adding a second conflicting floor.
	var result: Array[Dictionary] = []
	for district: Dictionary in get_districts():
		var angle: float = district.angle
		var outward := Vector3(sin(angle), 0, -cos(angle))
		var terrace: bool = district.id in [&"E", &"H"]
		result.append({"id": district.id, "district": district.id, "label": district.label,
			"angle": angle, "reuses_terrace": terrace, "walking_width": float(COURTYARD.bridge_width),
			"arch_transform": Transform3D(Basis(Vector3.UP, -angle), outward * float(COURTYARD.wall_radius)),
			"arch_clear_width": float(COURTYARD.gate_post_center) * 2.0 - float(COURTYARD.gate_post_width),
			"bridge_start": outward * float(COURTYARD.bridge_start_radius),
			"deck_start": outward * float(COURTYARD.deck_start_radius) + Vector3.UP * COURTYARD.floor_height(float(COURTYARD.deck_start_radius), terrace),
			"deck_end": outward * float(COURTYARD.deck_end_radius) + Vector3.UP * COURTYARD.floor_height(float(COURTYARD.deck_end_radius), terrace),
			"bridge_end": outward * float(COURTYARD.bridge_end_radius) + Vector3.UP * COURTYARD.floor_height(float(COURTYARD.bridge_end_radius), terrace)})
	return result

func get_service_poi(service: StringName) -> Dictionary:
	var aliases := {&"general": &"merchant_general", &"merchant": &"merchant_general", &"equipment": &"merchant_equipment", &"appraiser": &"merchant_appraiser", &"recruitment": &"tavern", &"forge": &"blacksmith"}
	return get_poi(aliases.get(service, service))

func get_ramps() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: StringName in [&"E", &"H"]:
		var transform := district_transform(id)
		var bottom := transform * Vector3(0, -terrace_height, 11.5)
		var top := transform * Vector3(0, 0, 2.5)
		result.append({"id": &"forge" if id == &"E" else &"tavern", "district": id, "bottom": bottom, "top": top, "center": transform * Vector3(0, -terrace_height * 0.5, 7), "width": path_width, "length": ramp_length, "height": terrace_height})
	return result

func navigation_graph() -> Dictionary:
	var points := PackedVector3Array([Vector3.ZERO])
	var edges: Array[Vector2i] = []
	for index in range(16):
		var angle := index * TAU / 16.0
		points.append(Vector3(sin(angle) * ring_radius, 0, -cos(angle) * ring_radius))
		edges.append(Vector2i(1 + index, 1 + (index + 1) % 16))
	var districts := get_districts()
	for index in range(8):
		points.append(districts[index].approach)
		if index not in [4, 7]:
			edges.append(Vector2i(1 + index * 2, 17 + index))
	var ramps := get_ramps()
	for index in range(ramps.size()):
		var district_index := 4 if index == 0 else 7
		var bottom_index := points.size()
		points.append(ramps[index].bottom)
		points.append(ramps[index].top)
		edges.append(Vector2i(1 + district_index * 2, bottom_index))
		edges.append(Vector2i(bottom_index, bottom_index + 1))
		edges.append(Vector2i(bottom_index + 1, 17 + district_index))
	# Six inner circulation nodes link the center to the outer ring through
	# the generous gaps between counters. Existing district/ramp indices stay
	# unchanged, and the complete graph remains below the 48-point AI budget.
	var inner_start := points.size()
	var outer_links := PackedInt32Array([1, 4, 6, 9, 12, 14])
	for index in range(6):
		var angle := float(index) * TAU / 6.0
		points.append(Vector3(sin(angle), 0, -cos(angle)) * float(CAPITAL.inner_circulation_radius))
		edges.append(Vector2i(0, inner_start + index))
		edges.append(Vector2i(inner_start + index, inner_start + (index + 1) % 6))
		edges.append(Vector2i(inner_start + index, outer_links[index]))
	return {"points": points, "edges": edges}

func describe() -> Dictionary:
	return {"radius": radius, "exchange_radius": exchange_radius, "ring_radius": ring_radius, "ring_width": ring_width, "district_radius": district_radius, "path_width": path_width, "districts": get_districts(), "pois": get_pois(), "exchange_booths": get_exchange_booths(), "exchange_connections": get_exchange_connections(), "ramps": get_ramps()}
