extends RefCounted
## Shared native primitives for the small Rootbound encounter prototypes.
## Materials are borrowed, never edited. No gameplay randomness or authority.
const MATERIALS := {
	"stone": preload("res://resources/materials/abyss_stone.tres"),
	"root_shell": preload("res://resources/materials/abyss_bark.tres"),
	"root_detail": preload("res://resources/materials/abyss_bark_light.tres"),
	"fungal_cap": preload("res://resources/materials/abyss_mushroom.tres"),
	"emissive": preload("res://resources/materials/abyss_glow.tres"),
	"flower_bud": preload("res://resources/materials/abyss_ember.tres"),
}

static func resolve(roles: Array[String], shared: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for role: String in roles:
		var material: Variant = MATERIALS.get(role) if shared.is_empty() else shared.get(role)
		if not material is Material: return {}
		result[role] = material
	return result

static func cylinder(bottom: float, top: float, height: float, sides: int = 8) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh

static func sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 2
	return mesh

static func batch(parent: Node3D, label: String, mesh: Mesh, material: Material, count: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.mesh = mesh
	node.multimesh.instance_count = count
	parent.add_child(node)
	return node

static func piece(parent: Node3D, label: String, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func submit(node: MultiMeshInstance3D, index: int, transform: Transform3D, capture: bool = false) -> void:
	# Capture the exact rendering command only for an explicitly opted-in
	# geometry test. Dummy rendering provides no MultiMesh transform readback.
	# Ordinary play retains no second transform array or inspection metadata.
	node.multimesh.set_instance_transform(index, transform)
	if capture:
		var submitted: Array = node.get_meta("submitted_transforms", [])
		if submitted.size() != node.multimesh.instance_count: submitted.resize(node.multimesh.instance_count)
		submitted[index] = transform
		node.set_meta("submitted_transforms", submitted)
	elif node.has_meta("submitted_transforms"):
		node.remove_meta("submitted_transforms")

static func counters(parent: Node) -> Dictionary:
	var result := {"meshes": 0, "instances": 0, "triangles": 0, "materials": {}}
	_accumulate(parent, result)
	result["materials"] = result.materials.size()
	return result

static func _accumulate(node: Node, result: Dictionary) -> void:
	var mesh: Mesh
	var material: Material
	var count := 1
	if node is MultiMeshInstance3D:
		mesh = node.multimesh.mesh
		count = node.multimesh.instance_count
		material = node.material_override
	elif node is MeshInstance3D:
		mesh = node.mesh
		material = node.material_override
	if mesh != null:
		result.meshes += 1
		result.instances += count
		result.triangles += int(float(mesh.get_faces().size()) / 3.0) * count
		if material != null: result.materials[material.get_instance_id()] = true
	for child: Node in node.get_children(): _accumulate(child, result)

static func mote_count(settings: Dictionary) -> int:
	var quality := clampi(int(settings.get("quality", 1)), 0, 2)
	var count := int([0, 2, 4][quality])
	if bool(settings.get("reduced_effects", false)): count = mini(count, 1)
	return floori(count * clampf(float(settings.get("ambient_density_percent", 100)) / 100.0, 0.0, 1.0))
