extends Resource
## Authored interior coordinates. Activity definitions and entry authority live
## in RealmCatalog/Game; this resource never grants progression or rewards.
const Catalog = preload("res://scripts/realms/realm_catalog.gd")
const ANGLES: Array[float] = [-135, -105, -75, -45, -15, 15, 45, 75, 105, 135]
const GALLERY_IDS: Array[StringName] = [&"A", &"C", &"S"]
const GALLERY_KEYS := ["adventure", "conflict", "ascension"]
const GALLERY_LABELS := ["Hall of Adventure", "Hall of Conflict", "Hall of Ascension"]
@export var radius := 30.0
@export var portal_radius := 23.0
@export var approach_distance := 2.6
@export var ring_radius := 17.0
@export var inner_ring_radius := 7.0

func valid() -> bool:
	return Catalog.valid() and Catalog.IDS.size() == ANGLES.size() and is_equal_approx(radius, 30.0) \
		and is_equal_approx(portal_radius, 23.0) and is_equal_approx(approach_distance, 2.6) \
		and is_equal_approx(ring_radius, 17.0) and is_equal_approx(inner_ring_radius, 7.0)

func portals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(Catalog.IDS.size()):
		var id: StringName = Catalog.IDS[index]
		var data: Resource = Catalog.definition(id)
		var angle := deg_to_rad(float(ANGLES[index]))
		var basis := Basis(Vector3.UP, -angle)
		var at := Vector3(sin(angle), 0, -cos(angle)) * portal_radius
		var gallery_index: int = GALLERY_KEYS.find(String(data.gallery))
		result.append({"id": id, "activity_id": id, "label": String(data.label),
			"district": GALLERY_IDS[gallery_index], "gallery": String(data.gallery),
			"position": at, "rotation": -angle, "angle": angle, "kind": &"portal",
			"approach": at + basis * Vector3(0, 0, approach_distance)})
	return result

func districts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(3):
		var angle := deg_to_rad([-90.0, 15.0, 105.0][index])
		var center := Vector3(sin(angle), 0, -cos(angle)) * ring_radius
		result.append({"id": GALLERY_IDS[index], "name": GALLERY_LABELS[index],
			"label": "%s · %s" % [GALLERY_IDS[index], GALLERY_LABELS[index]],
			"center": center, "approach": center, "angle": angle, "height": 0.0})
	return result

func get_poi(id: StringName) -> Dictionary:
	for row: Dictionary in portals():
		if row.id == id: return row
	if id == &"nexus_return":
		return {"id": id, "label": "Return to Sanctuary", "district": &"exchange", "kind": &"portal",
			"position": Vector3(0, 0, 27), "rotation": -PI, "approach": Vector3(0, 0, 24.4)}
	if id == &"nexus_practice":
		return {"id": id, "label": "Sunken Vault · Existing Practice", "district": &"exchange", "kind": &"portal",
			"position": Vector3(10, 0, 24), "rotation": -PI, "approach": Vector3(10, 0, 21.4)}
	if id == &"map":
		return {"id": id, "label": "Realm Conduit · Orientation", "district": &"exchange", "kind": &"guide",
			"position": Vector3(0, 0, 6), "approach": Vector3(0, 0, 7), "rotation": 0.0}
	for row: Dictionary in districts():
		if row.id == id:
			return {"id": id, "label": row.label, "position": row.center, "approach": row.approach, "kind": &"district"}
	return {}

func describe() -> Dictionary:
	var points := portals()
	points.append(get_poi(&"nexus_return"))
	points.append(get_poi(&"nexus_practice"))
	points.append(get_poi(&"map"))
	return {"radius": radius, "exchange_radius": 3.6, "ring_radius": ring_radius,
		"ring_width": 3.2, "path_width": 4.0, "districts": districts(), "pois": points,
		"map_title": "NEXUS OF REALMS", "map_subtitle": "A: Adventure · C: Conflict · S: Ascension",
		"center_label": "Realm Conduit", "center_button": "REALM",
		"center_district_id": &"exchange",
		"map_caption": "Select a gallery. Available routes and unfinished activities are marked in each gateway's details.",
		"location_id": &"realm_nexus"}

func navigation_graph() -> Dictionary:
	# Two rings avoid the solid central pedestal. Portal approaches attach to
	# their corresponding outer node; no graph edge crosses the Conduit body.
	var points := PackedVector3Array()
	var edges: Array[Vector2i] = []
	for index in range(12):
		var angle := deg_to_rad(-165.0 + float(index) * 30.0)
		points.append(Vector3(sin(angle), 0, -cos(angle)) * ring_radius)
		edges.append(Vector2i(index, (index + 1) % 12))
	for index in range(8):
		var angle := float(index) * TAU / 8.0
		points.append(Vector3(sin(angle), 0, -cos(angle)) * inner_ring_radius)
		edges.append(Vector2i(12 + index, 12 + (index + 1) % 8))
	for index in range(12):
		var nearest := 12
		for inner in range(13, 20):
			if points[index].distance_squared_to(points[inner]) < points[index].distance_squared_to(points[nearest]): nearest = inner
		edges.append(Vector2i(index, nearest))
	var rows := portals()
	for index in range(rows.size()):
		points.append(rows[index].approach)
		edges.append(Vector2i(index + 1, 20 + index))
	for id: StringName in [&"nexus_return", &"nexus_practice"]:
		var point: Vector3 = get_poi(id).approach
		var nearest := 0
		for index in range(1, 12):
			if point.distance_squared_to(points[index]) < point.distance_squared_to(points[nearest]): nearest = index
		var next := points.size()
		points.append(point)
		edges.append(Vector2i(nearest, next))
	return {"points": points, "edges": edges}
