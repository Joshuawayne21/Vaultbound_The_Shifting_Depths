class_name VaultEmoteCatalog
extends RefCounted
## Original local procedural poses. These entries grant no inventory or network state.

const ENTRIES := [
	{"id": &"wave", "label": "Wave", "duration": 2.4},
	{"id": &"cheer", "label": "Cheer", "duration": 2.8},
	{"id": &"dance", "label": "Dance", "duration": 4.8},
	{"id": &"sit", "label": "Sit", "duration": 8.0},
	{"id": &"point", "label": "Point", "duration": 2.4},
	{"id": &"bow", "label": "Bow", "duration": 2.8},
	{"id": &"laugh", "label": "Laugh", "duration": 3.0},
	{"id": &"celebrate", "label": "Celebrate", "duration": 3.6},
	{"id": &"inspect", "label": "Inspect", "duration": 3.2},
]

static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in ENTRIES:
		result.append(entry.duplicate(true))
	return result

static func has_emote(id: StringName) -> bool:
	return duration_for(id) > 0.0

static func duration_for(id: StringName) -> float:
	for entry: Dictionary in ENTRIES:
		if entry.id == id:
			return float(entry.duration)
	return 0.0
