class_name VaultPetDiscoveryLayout
extends Resource
## Seeded cosmetic discovery layout, independent of every existing dungeon RNG.
@export_range(0.0, 1.0) var egg_chance := 0.45
@export var eggs_enabled := true
@export var rescues_enabled := true
@export var candidate_points: Array[Vector3] = [
	Vector3(-7, 0, -3.5), Vector3(-3.5, 0, -7), Vector3(3.5, 0, -7), Vector3(7, 0, -3.5),
	Vector3(7, 0, 3.5), Vector3(3.5, 0, 7), Vector3(-3.5, 0, 7), Vector3(-7, 0, 3.5)]

func plan(layout: Dictionary, expedition_seed: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var eligible: Array[int] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = ("vaultbound/pet-discovery-layout/v1/%d" % expedition_seed).hash()
	for room: Dictionary in layout.get("rooms", []):
		if room.kind in [&"treasure", &"secret"]:
			eligible.append(int(room.id))
		if rescues_enabled and room.kind == &"secret" and bool(room.hidden):
			result.append({"room_id": int(room.id), "kind": "rescue", "receipt": "pet_rescue_room_%d" % int(room.id),
				"offset": rng.randi_range(0, maxi(0, candidate_points.size() - 1)), "attempts": 0})
	# One rare egg at most, and no fabricated source in a missing biome/room.
	if eggs_enabled and not eligible.is_empty() and rng.randf() < clampf(egg_chance, 0.0, 1.0):
		var room_id := eligible[rng.randi_range(0, eligible.size() - 1)]
		result.append({"room_id": room_id, "kind": "egg", "receipt": "pet_egg_room_%d" % room_id,
			"offset": rng.randi_range(0, maxi(0, candidate_points.size() - 1)), "attempts": 0})
	return result

func points_for(offset: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for index in range(mini(8, candidate_points.size())):
		result.append(candidate_points[posmod(index + offset, candidate_points.size())])
	return result
