class_name VaultUITheme
extends RefCounted
## Shared lightweight palette and frame treatment; no imported artwork or shaders.
const GOLD := Color("e5bd70")
const BRONZE := Color("9f7546")
const IVORY := Color("f1f1e8")
const MUTED := Color("a5b3c7")
const TEAL := Color("54e2d0")
const HEALTH := Color("62dc86")
const RESOURCE := Color("60b8f3")
const WARNING := Color("f29079")
const PANEL := Color(0.035, 0.052, 0.095, 0.95)
const RARITY_COLORS := [Color("b8c2cf"), Color("6cdb8c"), Color("65b7f5"), Color("bd88f4"), Color("efc96a"), Color("ee647d"), Color("5be7d6")]
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythic", "ancient_relic"]
const RARITY_MARKS := ["I", "II", "III", "IV", "V", "VI", "VII"]
const FRAME_CACHE_LIMIT := 96
static var _frame_cache: Dictionary = {}

static func rarity_marker(rarity: String) -> String:
	var index := RARITIES.find(rarity)
	return RARITY_MARKS[index] if index >= 0 else ""

static func rarity_label(rarity: String) -> String:
	var marker := rarity_marker(rarity)
	return (marker + " · " if not marker.is_empty() else "") + rarity.replace("_", " ").to_upper()

static func rarity_accents(rarity: String) -> Array[Color]:
	var color: Color = RARITY_COLORS[maxi(0, RARITIES.find(rarity))]
	var accents: Array[Color] = [color]
	if rarity == "ancient_relic": accents.append(GOLD)
	return accents

static func rarity_frame(canvas: CanvasItem, rect: Rect2, fill: Color, rarity: String, selected: bool = false) -> void:
	var accents := rarity_accents(rarity)
	frame(canvas, rect, fill, accents[0], selected)
	if accents.size() > 1:
		canvas.draw_rect(rect.grow(-4), Color(accents[1], 0.8), false, 1)

static func item_inspection_note(item: Dictionary) -> String:
	var notes: Array[String] = []
	if not bool(item.get("obtainable", true)):
		notes.append("Not currently obtainable")
	if not bool(item.get("combat_supported", true)):
		notes.append("Combat unavailable")
	match String(item.get("model_art_status", "")):
		"shared_family_placeholder": notes.append("Shared family model (prototype)")
		"missing": notes.append("Model unavailable")
	if String(item.get("icon_art_status", "")) == "catalog_placeholder":
		notes.append("Placeholder icon")
	if notes.size() < 3 and bool(item.get("obtainable", true)):
		var sources: Array[String] = []
		for source: String in item.get("acquisition_sources", []):
			var label := ""
			if source.begins_with("chest:"): label = "chests"
			elif source.begins_with("monster:"): label = "monster caches"
			elif source.begins_with("craft:"): label = "crafting"
			elif source.begins_with("merchant:"): label = "merchants"
			elif source.begins_with("objective:"): label = "objectives"
			if not label.is_empty() and not sources.has(label): sources.append(label)
		if not sources.is_empty():
			var summary := ", ".join(sources.slice(0, 2))
			if sources.size() > 2: summary += " +%d sources" % (sources.size() - 2)
			notes.append("From " + summary)
	return " · ".join(notes)

static func frame(canvas: CanvasItem, rect: Rect2, fill: Color, accent: Color = GOLD, selected: bool = false) -> void:
	# Quantize only the decorative frame fade. Shared immutable styles keep HUD
	# redraws allocation-free, with a strict bound even for transient notice colors.
	fill.a = snappedf(fill.a, 1.0 / 16.0)
	var key := "%s:%s:%s" % [fill.to_html(), accent.to_html(), selected]
	if not _frame_cache.has(key):
		if _frame_cache.size() >= FRAME_CACHE_LIMIT:
			_frame_cache.erase(_frame_cache.keys()[0])
		var created := StyleBoxFlat.new()
		created.bg_color = fill
		created.border_color = Color(accent, 0.72 if selected else 0.38)
		created.set_border_width_all(2 if selected else 1)
		created.set_corner_radius_all(7)
		created.corner_detail = 3
		_frame_cache[key] = created
	var shape: StyleBoxFlat = _frame_cache[key]
	canvas.draw_style_box(shape, rect)
	var length := minf(18.0, rect.size.x * 0.12)
	for corner: Vector2 in [rect.position + Vector2(6, 0), Vector2(rect.end.x - 6, rect.position.y), rect.end - Vector2(6, 0), Vector2(rect.position.x + 6, rect.end.y)]:
		var direction := 1.0 if corner.x < rect.get_center().x else -1.0
		canvas.draw_line(corner, corner + Vector2(direction * length, 0), Color(accent, 0.75), 2, true)
	canvas.draw_line(rect.position + Vector2(10, 3), Vector2(rect.end.x - 10, rect.position.y + 3), Color(IVORY, 0.055), 1)

static func scale_from(settings: Dictionary) -> float:
	return clampf(float(settings.get("ui_scale_percent", 100)) / 100.0, 1.0, 1.2)

static func safe_inset(control: Control) -> Vector2:
	var overlay := control.get_parent()
	if is_instance_valid(overlay) and overlay.get("source_surface") is Control:
		return Vector2(overlay.source_surface._safe_inset)
	return Vector2.ZERO
