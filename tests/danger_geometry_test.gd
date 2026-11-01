extends "res://tests/test_harness.gd"
const Danger = preload("res://scripts/combat/danger_geometry.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND DANGER GEOMETRY"
	_run.call_deferred()

func _run() -> void:
	var circle := {"shape": &"circle", "position": Vector3.ZERO, "radius": 2.0}
	var capsule := {"shape": &"capsule", "position": Vector3.ZERO, "radius": 0.5, "start": Vector3(-3, 0, 0), "end": Vector3(3, 0, 0)}
	var sector := {"shape": &"sector", "position": Vector3.ZERO, "radius": 4.0, "direction": Vector3.RIGHT, "half_angle": PI / 4.0}
	var ring := {"shape": &"annular_sector", "position": Vector3.ZERO, "radius": 5.0, "inner_radius": 2.0, "outer_radius": 5.0, "direction": Vector3.RIGHT, "half_angle": PI * 0.75}
	for shape: Dictionary in [circle, capsule, sector, ring]:
		check(Danger.validate(shape).is_empty(), "Declared shape validates: " + String(shape.shape))
		var original := shape.duplicate(true)
		var probe := Vector3(2.3, 0.06, 0.1)
		var candidates: Array[Vector3] = Danger.escape_candidates(shape, probe, 0.65)
		check(candidates.size() > 0 and candidates.size() <= 12 and candidates == Danger.escape_candidates(shape, probe, 0.65), "Escape candidates are deterministic and bounded: " + String(shape.shape))
		for point: Vector3 in candidates:
			check(point.y == probe.y and not Danger.contains(shape, point, 0.65), "Candidate preserves floor and exits padded shape")
		var loops: Array[PackedVector3Array] = Danger.outline(shape, 32)
		check(not loops.is_empty(), "Shape has a drawable footprint")
		for loop: PackedVector3Array in loops:
			check(loop.size() > 3 and loop[0] == loop[-1], "Warning boundary loop is closed")
			for point: Vector3 in loop:
				check(absf(Danger.signed_distance(shape, point)) < 0.0001 and point.y == 0.0, "Warning vertex shares analytic boundary and floor")
		var triangles := Danger.triangles(shape, 32)
		check(triangles.size() > 0 and triangles.size() % 3 == 0, "Warning mesh is an unindexed triangle list")
		for index in range(0, triangles.size(), 3):
			check((triangles[index + 1] - triangles[index]).cross(triangles[index + 2] - triangles[index]).y < 0.0, "Warning triangles use Godot clockwise upward-facing winding")
		check(shape == original, "Geometry/visual queries do not mutate issued shape")
	check(is_equal_approx(Danger.signed_distance(circle, Vector3.ZERO), -2.0), "Circle center has signed interior distance")
	check(Danger.contains(circle, Vector3(2, 0, 0)) and not Danger.contains(circle, Vector3(2.001, 0, 0)), "Circle boundary is inclusive without loose radius tolerance")
	check(Danger.contains(circle, Vector3(2.5, 0, 0), 0.5) and not Danger.contains(circle, Vector3(2.501, 0, 0), 0.5), "Horizontal padding follows exact circle distance")
	check(Danger.signed_distance(circle, Vector3(0, 2.01, 0)) == INF and not Danger.contains(circle, Vector3(0, 2.01, 0), 4), "Padding never expands the explicit height slab")
	check(Danger.contains(capsule, Vector3(3.5, 0, 0)) and not Danger.contains(capsule, Vector3(3.51, 0, 0)), "Capsule end cap matches its radius")
	check(is_equal_approx(Danger.signed_distance(capsule, Vector3(0, 0, 1)), 0.5), "Capsule distance uses its finite axis")
	check(Danger.contains(sector, Vector3(2, 0, 2)) and not Danger.contains(sector, Vector3(-0.1, 0, 0)), "Sector includes radial boundary and excludes rear")
	check(Danger.contains(sector, Vector3(-0.3, 0, 0), 0.3) and not Danger.contains(sector, Vector3(-0.3, 0, 0.3), 0.3), "Sector tip padding is rounded rather than a square expansion")
	check(not Danger.contains(ring, Vector3.ZERO) and Danger.contains(ring, Vector3(2, 0, 0)), "Annular center remains a real safe hole")
	check(Danger.contains(ring, Vector3(1.5, 0, 0), 0.5) and not Danger.contains(ring, Vector3(1.49, 0, 0), 0.5), "Padding shrinks the inner safe radius consistently")
	var cuts := Danger.segment_intervals(circle, Vector3(-4, 0, 0), Vector3(4, 0, 0))
	check(cuts.size() == 1 and cuts[0].is_equal_approx(Vector2(0.25, 0.75)), "Circle crossing has exact analytic entry/exit")
	cuts = Danger.segment_intervals(circle, Vector3(-4, 0, 2), Vector3(4, 0, 2))
	check(cuts.size() == 1 and cuts[0].x < 0.5 and cuts[0].y > 0.5 and cuts[0].y - cuts[0].x < 0.002, "Tangent contact preserves the same bounded metre tolerance as membership")
	var near_tangent := {"shape": &"circle", "position": Vector3.ZERO, "radius": 1.0}
	cuts = Danger.segment_intervals(near_tangent, Vector3(-2, 0, 1.000005), Vector3(2, 0, 1.000005))
	check(cuts.size() == 1 and cuts[0].x > 0.49 and cuts[0].y < 0.51 \
		and not Danger.contains(near_tangent, Vector3(-2, 0, 1.000005)), "Epsilon-near tangent cannot classify the entire segment as dangerous")
	cuts = Danger.segment_intervals(circle, Vector3(0, -4, 0), Vector3(0, 4, 0))
	check(cuts.size() == 1 and cuts[0].is_equal_approx(Vector2(0.25, 0.75)), "Vertical path is clipped by the independent height slab")
	cuts = Danger.segment_intervals(capsule, Vector3(0, 0, -100), Vector3(0, 0, 100))
	check(cuts.size() == 1 and cuts[0].is_equal_approx(Vector2(0.4975, 0.5025)), "Long segment cannot miss a narrow capsule lane")
	var full_ring := ring.duplicate(true)
	full_ring.half_angle = PI
	cuts = Danger.segment_intervals(full_ring, Vector3(-6, 0, 0), Vector3(6, 0, 0))
	check(cuts.size() == 2 and cuts[0].is_equal_approx(Vector2(1.0 / 12.0, 1.0 / 3.0)) and cuts[1].is_equal_approx(Vector2(2.0 / 3.0, 11.0 / 12.0)), "Annular crossing distinguishes danger, safe center and reentry")
	var long_ring := full_ring.duplicate(true)
	long_ring.inner_radius = 0.1
	cuts = Danger.segment_intervals(long_ring, Vector3(-100000, 0, 0), Vector3(100000, 0, 0))
	check(cuts.size() == 2 and cuts[0].y < 0.5 and cuts[1].x > 0.5, "Metre tolerance scales to long-segment t without merging the annular safe hole")
	var tight_hole := full_ring.duplicate(true)
	tight_hole.inner_radius = 0.7
	check(Danger.escape_candidates(tight_hole, Vector3(1, 0, 0), 0.65).has(Vector3.ZERO), "A tight valid annular safe center survives the optional extra exit margin")
	check(Danger.segment_intervals(circle, Vector3(1e30, 0, 0), Vector3.ZERO).is_empty() and Danger.signed_distance(circle, Vector3(1e30, 0, 0)) == INF, "Out-of-budget finite query coordinates cannot overflow analytic roots")
	var coarse_mesh := Danger.triangles(full_ring, 8)
	var minimum_inner_chord := INF
	for triangle in range(0, coarse_mesh.size(), 3):
		for edge in range(3):
			var a := coarse_mesh[triangle + edge]
			var b := coarse_mesh[triangle + (edge + 1) % 3]
			if is_equal_approx(a.length(), 2.0) and is_equal_approx(b.length(), 2.0) and a.distance_to(b) > 0.01:
				minimum_inner_chord = minf(minimum_inner_chord, ((a + b) * 0.5).length())
	check(is_equal_approx(minimum_inner_chord, 2.0 * cos(PI / 8.0)) and minimum_inner_chord < 2.0,
		"Measured actual coarse inner chord requires analytic renderer clipping before an annular attack is enabled")
	check(Danger.outline(full_ring).size() == 2 and Danger.signed_distance(full_ring, Vector3(3, 0, 0)) < -0.9, "Full annular boundary has separate loops without a false radial seam")
	check(Danger.segment_intervals(circle, Vector3.ZERO, Vector3.ZERO) == [Vector2(0, 1)] and Danger.segment_intervals(circle, Vector3(8, 0, 0), Vector3(8, 0, 0)).is_empty(), "Degenerate segment distinguishes occupied and safe points")
	var warning := circle.duplicate(true)
	warning.merge({"phase": &"warning", "remaining": 0.4, "active_remaining": 0.0, "attack_id": 1, "stage_id": 0})
	check(Danger.is_live(warning), "Positive warning remains actionable")
	warning.remaining = 0.0
	check(not Danger.is_live(warning), "Expired warning is not a future danger")
	warning.phase = &"active"
	warning.active_remaining = 0.3
	check(Danger.is_live(warning), "Active footprint remains actionable after warning reaches zero")
	for patch: Dictionary in [{"shape": &"unknown"}, {"position": Vector3.INF}, {"radius": NAN}, {"radius": 24.01}, {"height_tolerance": 4.01}, {"remaining": -1.0}, {"attack_id": 0}, {"stage_id": 1.5}, {"phase": &"finished"}]:
		var invalid := circle.duplicate(true)
		invalid.merge(patch, true)
		check(not Danger.validate(invalid).is_empty() and not Danger.contains(invalid, Vector3.ZERO) and Danger.segment_intervals(invalid, Vector3.ZERO, Vector3.ONE).is_empty(), "Invalid explicit input fails closed: " + str(patch))
	var invalid_capsule := capsule.duplicate(true)
	invalid_capsule.position = Vector3.RIGHT
	check(not Danger.validate(invalid_capsule).is_empty(), "Capsule compatibility midpoint cannot disagree with endpoints")
	var invalid_ring := ring.duplicate(true)
	invalid_ring.radius = 4.0
	check(not Danger.validate(invalid_ring).is_empty(), "Annular compatibility radius cannot contradict the actual outer arc")
	check(not Danger.contains(circle, Vector3.ZERO, -1) and not Danger.contains(circle, Vector3.ZERO, INF) and not Danger.contains(circle, Vector3.ZERO, 4.01), "Unbounded or negative padding fails closed")
	var diagnosed_a := Vector3(-2.719601, -1.809365, 4.32733)
	var diagnosed_b := Vector3(5.57652, 1.939676, -3.013842)
	var diagnosed_t := 0.875
	var diagnosed_covered := false
	for interval: Vector2 in Danger.segment_intervals(ring, diagnosed_a, diagnosed_b):
		if diagnosed_t >= interval.x and diagnosed_t <= interval.y: diagnosed_covered = true
	check(not diagnosed_covered and not _independent_inside(ring, diagnosed_a.lerp(diagnosed_b, diagnosed_t)),
		"Independent oracle does not expand normalized intervals by an unscaled world tolerance")
	_sampled_oracle([circle, capsule, sector, ring, full_ring])
	finish()

func _sampled_oracle(shapes: Array) -> void:
	# Independent polar/segment distance classification supplements exact fixtures;
	# it cannot replace the narrow-lane, tangent and safe-hole checks above.
	var random := RandomNumberGenerator.new()
	random.seed = 71491
	for shape: Dictionary in shapes:
		for trial in range(24):
			var a := Vector3(random.randf_range(-8, 8), random.randf_range(-3, 3), random.randf_range(-8, 8))
			var b := Vector3(random.randf_range(-8, 8), random.randf_range(-3, 3), random.randf_range(-8, 8))
			var intervals := Danger.segment_intervals(shape, a, b)
			var agrees := true
			for step in range(81):
				var t := float(step) / 80.0
				var covered := false
				for interval: Vector2 in intervals:
					if t >= interval.x and t <= interval.y: covered = true
				var p := a.lerp(b, t)
				var inside := _independent_inside(shape, p)
				if absf(Danger.signed_distance(shape, p)) > 0.0001 and covered != inside: agrees = false
			check(agrees, "Seeded segment intervals match independent footprint membership: %s/%d" % [shape.shape, trial])

func _independent_inside(shape: Dictionary, point: Vector3) -> bool:
	if absf(point.y) > 2.0 + Danger.EPSILON: return false
	var flat := Vector2(point.x, point.z)
	if shape.shape == &"circle": return flat.length() <= float(shape.radius)
	if shape.shape == &"capsule":
		return Vector2(point.x - clampf(point.x, -3.0, 3.0), point.z).length() <= 0.5
	var radius := flat.length()
	return radius <= float(shape.radius) and radius >= float(shape.get("inner_radius", 0.0)) and absf(atan2(point.z, point.x)) <= float(shape.half_angle)
