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
const FRAME_CACHE_LIMIT := 96
static var _frame_cache: Dictionary = {}

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
