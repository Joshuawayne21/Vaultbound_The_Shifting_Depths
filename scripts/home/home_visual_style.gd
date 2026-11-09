extends RefCounted
## Shared presentation-only palette and motif data. Progression owns eligibility.
const THEMES := {
	"royal_azure": {"ivory": Color("dbd1b3"), "floor": Color("7d8796"), "cloth": Color("122666"), "window": Color("45a1b8"), "gold": Color("c5a04f"), "hologram": Color("74dbe8")},
	"enchanted_forest": {"ivory": Color("bdcbb1"), "floor": Color("687c71"), "cloth": Color("214c39"), "window": Color("80b89d"), "gold": Color("b8a354"), "hologram": Color("8eeeb8")},
	"runic_obsidian": {"ivory": Color("414554"), "floor": Color("343b4b"), "cloth": Color("532b46"), "window": Color("b89172"), "gold": Color("bd9152"), "hologram": Color("efb688")},
	"celestial_violet": {"ivory": Color("b8b8da"), "floor": Color("787eaa"), "cloth": Color("46316e"), "window": Color("86b2db"), "gold": Color("d0b987"), "hologram": Color("c0a7ff")},
}
const SIGILS := ["vault_diamond", "root_crown", "runic_seal", "crystal_star"]

static func theme_colors(theme_id: String) -> Dictionary:
	return THEMES.get(theme_id, THEMES.royal_azure).duplicate()

static func sigil_outline(sigil_id: String) -> PackedVector2Array:
	match sigil_id:
		"root_crown":
			return PackedVector2Array([Vector2(-0.82, -0.35), Vector2(-0.76, 0.7), Vector2(-0.35, 0.2), Vector2(0, 0.92), Vector2(0.35, 0.2), Vector2(0.76, 0.7), Vector2(0.82, -0.35), Vector2(0, -0.8), Vector2(-0.82, -0.35)])
		"runic_seal":
			var points := PackedVector2Array()
			for index in range(9):
				var angle := float(index) * TAU / 8.0
				points.append(Vector2(sin(angle), cos(angle)) * 0.84)
			return points
		"crystal_star":
			var points := PackedVector2Array()
			for index in range(17):
				var angle := float(index) * TAU / 16.0
				points.append(Vector2(sin(angle), cos(angle)) * (0.96 if index % 2 == 0 else 0.42))
			return points
		_:
			return PackedVector2Array([Vector2(0, 1), Vector2(0.68, 0.15), Vector2(0, -1), Vector2(-0.68, 0.15), Vector2(0, 1)])
