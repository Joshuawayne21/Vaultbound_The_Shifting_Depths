extends RefCounted
## Independent native text extents against the actual drawing layout, not screenshots.
static func verify(harness: SceneTree, overlay: Control, surface: Control) -> void:
	var old_overlay: Vector2 = overlay.size
	var old_surface: Vector2 = surface.size
	var old_inset: Vector2 = surface._safe_inset
	var old_percent: int = roundi(overlay.ui_scale * 100.0)
	var font: Font = ThemeDB.fallback_font
	var full: String = String(overlay.dungeon_snapshot.theme_label).to_upper()
	var positions: Dictionary = overlay.minimap_room_positions()
	var markers: Dictionary = overlay.minimap_return_markers()
	var kinds: Dictionary = {}
	for room: Dictionary in overlay.dungeon_snapshot.get("rooms", []): kinds[int(room.id)] = String(room.kind)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		overlay.size = extent
		surface.size = extent
		for percent: int in [100, 110, 120]:
			overlay.apply_visual_settings({"ui_scale_percent": percent})
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				surface._safe_inset = inset
				var layout: Dictionary = overlay.minimap_layout(not markers.is_empty())
				var rect: Rect2 = layout.rect
				var lines: PackedStringArray = layout.title
				var boxes: Array[Rect2] = []
				var valid: bool = " ".join(lines) == full and lines.size() in [1, 2] and Rect2(inset, extent - inset * 2).encloses(rect)
				var pixels: int = roundi(9 * overlay.ui_scale)
				for index in range(lines.size()):
					var width: float = font.get_string_size(lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
					var baseline: float = rect.position.y + float(layout.title_baseline) + index * float(layout.line_height)
					var box := Rect2(rect.get_center().x - width * 0.5, baseline - font.get_ascent(pixels), width, font.get_ascent(pixels) + font.get_descent(pixels))
					valid = valid and width <= 145.0 and rect.encloses(box)
					for previous: Rect2 in boxes: valid = valid and not previous.intersects(box)
					boxes.append(box)
				var small: int = roundi(8 * overlay.ui_scale)
				if not markers.is_empty():
					var legend := _text_box(font, "R RETURN · E EXTRACT", rect.get_center().x, rect.position.y + float(layout.legend_baseline), small)
					for heading: Rect2 in boxes: valid = valid and not heading.intersects(legend)
					valid = valid and rect.encloses(legend)
					boxes.append(legend)
				var footer := _text_box(font, "%d ROOMS DISCOVERED" % positions.size(), rect.get_center().x, rect.position.y + float(layout.footer_baseline), small)
				valid = valid and rect.encloses(footer)
				boxes.append(footer)
				if not positions.is_empty():
					var minimum := Vector2(INF, INF)
					var maximum := Vector2(-INF, -INF)
					for cell: Vector2 in positions.values():
						minimum = minimum.min(cell)
						maximum = maximum.max(cell)
					var span: Vector2 = maximum - minimum + Vector2.ONE
					var spacing: float = minf(25.0, float(layout.extent) / maxf(span.x, span.y))
					for id: int in positions:
						var at: Vector2 = Vector2(layout.center) + (Vector2(positions[id]) - (minimum + maximum) * 0.5) * spacing
						var radius: float = maxf(3.0, spacing * 0.23) + (2.0 if markers.has(id) else 0.0)
						var node_box := Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
						if markers.has(id) or (not markers.is_empty() and kinds.get(id) == "extraction"):
							node_box = node_box.merge(_text_box(font, "R" if markers.has(id) else "E", at.x, at.y + 3.0, small))
						valid = valid and rect.encloses(node_box)
						for text_box: Rect2 in boxes: valid = valid and not node_box.intersects(text_box)
				harness.check(valid, "Complete issued minimap title, native font heights, R/E legend and actual graph fit %s/%d%%/%s" % [extent, percent, inset])
	overlay.size = old_overlay
	surface.size = old_surface
	surface._safe_inset = old_inset
	overlay.apply_visual_settings({"ui_scale_percent": old_percent})

static func _text_box(font: Font, text: String, center_x: float, baseline: float, pixels: int) -> Rect2:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	return Rect2(center_x - width * 0.5, baseline - font.get_ascent(pixels), width, font.get_ascent(pixels) + font.get_descent(pixels))
