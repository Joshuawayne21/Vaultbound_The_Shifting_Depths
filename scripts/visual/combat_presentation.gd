class_name CombatPresentation
extends RefCounted
## Presentation-only geometry and budgets. No hit tests, damage commands, random
## gameplay state, lights or depth overrides belong in this helper.

static func quality(context: Node) -> int:
	var settings := context.get_node_or_null("/root/VisualSettings")
	return clampi(int(settings.get("current_quality")), 0, 2) if settings != null else 1

static func burst_limit(context: Node) -> int:
	var settings := context.get_node_or_null("/root/VisualSettings")
	return clampi(int(settings.get("effect_budget")), 1, 20) if settings != null else 14

static func unlit(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

static func warning_mesh(half_angle: float = PI) -> ImmediateMesh:
	# Fill, accurate perimeter and inward notches share one draw call. Every vertex
	# lies inside the original unit footprint; scaling still uses the combat radius.
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 48 if half_angle > 3.0 else 24
	for index in range(segments):
		var a := lerpf(-half_angle, half_angle, float(index) / segments)
		var b := lerpf(-half_angle, half_angle, float(index + 1) / segments)
		var va := Vector3(sin(a), 0, -cos(a))
		var vb := Vector3(sin(b), 0, -cos(b))
		_triangle(mesh, Vector3.ZERO, va * 0.94, vb * 0.94, 0.32)
		_triangle(mesh, va * 0.94, va, vb, 1.0)
		_triangle(mesh, va * 0.94, vb, vb * 0.94, 1.0)
		if index % 4 == 0:
			_triangle(mesh, va * 0.78, va * 0.94, vb * 0.94, 0.9)
	mesh.surface_end()
	return mesh

static func _triangle(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, opacity: float) -> void:
	mesh.surface_set_color(Color(1, 1, 1, opacity))
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(c)
