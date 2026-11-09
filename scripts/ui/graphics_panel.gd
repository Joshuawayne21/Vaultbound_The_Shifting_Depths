class_name VaultGraphicsPanel
extends Control
## Uses the existing modal input owner. Changes commit only on a completed tap.
signal close_requested
signal pointers_canceled(ids: Array[int])
const GOLD := VaultUITheme.GOLD
const IVORY := VaultUITheme.IVORY
const MUTED := VaultUITheme.MUTED
const TEAL := VaultUITheme.TEAL
const PANEL := VaultUITheme.PANEL
const DETAILS := ["Fewer decorative plants and motes. Dynamic shadows off.", "Balanced decoration and soft dynamic shadows.", "Richer decoration, sharper shadows and smoother edges."]
const TABS := ["graphics", "accessibility", "ambience", "tester"]
var settings: Node
var session: Node
var input_owner: Control
var tester_data: Dictionary = {}
var tester_quote: Dictionary = {}
var selected_tester := false
var tester_scroll := 0
var _tester_focused := true
var _tester_busy := false
var selected_quality := 1
var selected_fps := 30
var selected_ui_scale := 100
var selected_reduced_motion := false
var selected_reduced_effects := false
var selected_ambient_density := 100
var selected_high_contrast := false
var selected_ambient_sound := false
var section := "graphics"
var ui_scale := 1.0
var notice := ""
var _font: Font
var _pointers: Dictionary = {}
var _epoch := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	settings = get_node_or_null("/root/VisualSettings")
	hide()

func open_panel() -> void:
	_cancel_tester_review()
	_tester_focused = true
	settings = get_node_or_null("/root/VisualSettings")
	if is_instance_valid(settings):
		selected_quality = settings.current_quality
		selected_fps = settings.target_fps
		selected_ui_scale = settings.ui_scale_percent
		selected_reduced_motion = settings.reduced_motion
		selected_reduced_effects = settings.reduced_effects
		selected_ambient_density = settings.ambient_density_percent
		selected_high_contrast = settings.high_contrast_prompts
		selected_ambient_sound = settings.ambient_sound_enabled
		notice = settings.storage_error
	else:
		notice = "Graphics settings are unavailable."
	_pointers.clear()
	section = "graphics"
	_epoch += 1
	show()
	refresh_tester()
	selected_tester = bool(tester_data.get("enabled", false))
	queue_redraw()

func hide_panel() -> void:
	hide()
	_cancel_tester_review()

func apply_visual_settings(value: Dictionary) -> void:
	ui_scale = VaultUITheme.scale_from(value)
	_cancel_tester_review()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_tester_focused = false
		_cancel_tester_review()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		_tester_focused = true
	elif what == NOTIFICATION_RESIZED and is_node_ready():
		_cancel_tester_review()

func handle_event(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE, KEY_F10]:
		close_requested.emit()
		return
	if event is InputEventScreenTouch:
		var point := _local_point(event.position)
		if event.pressed and not event.canceled:
			_begin(event.index, point)
		else:
			_end(event.index, point, event.canceled)
	elif event is InputEventScreenDrag:
		_drag(event.index, _local_point(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(-1, _local_point(event.position))
		else:
			_end(-1, _local_point(event.position), false)
	elif event is InputEventMouseMotion:
		_drag(-1, _local_point(event.position))

func _local_point(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _begin(id: int, point: Vector2) -> void:
	if not _pointers.has(id) and _pointers.size() < 10:
		_pointers[id] = {"start": point, "last": point, "dragged": false, "action": _hit(point), "epoch": _epoch,
			"tester_scroll": section == "tester" and tester_detail_rect().has_point(point)}

func _drag(id: int, point: Vector2) -> void:
	if _pointers.has(id) and point.distance_to(_pointers[id].start) > 12.0:
		_pointers[id].dragged = true
	if _pointers.has(id) and bool(_pointers[id].tester_scroll) and bool(_pointers[id].dragged):
		var delta := point.y - float(_pointers[id].last.y)
		var step := roundi(delta / (22.0 * ui_scale))
		if step != 0:
			tester_scroll = clampi(tester_scroll - step, 0, maxi(0, tester_lines().size() - tester_line_capacity()))
			_pointers[id].last = point
			queue_redraw()

func _end(id: int, point: Vector2, canceled: bool) -> void:
	if not _pointers.has(id):
		return
	var pointer: Dictionary = _pointers[id]
	_pointers.erase(id)
	if canceled or pointer.dragged or int(pointer.epoch) != _epoch or String(pointer.action).is_empty() or _hit(point) != pointer.action:
		return
	_activate(pointer.action)

func _hit(point: Vector2) -> String:
	if close_rect().has_point(point): return "close"
	if apply_rect().has_point(point): return "tester_apply" if section == "tester" else "apply"
	for index in range(TABS.size()):
		if tab_rect(index).has_point(point): return "tab_%d" % index
	if section == "tester":
		for index in range(2):
			if tester_option_rect(index).has_point(point): return "tester_%d" % index
		return ""
	if section == "accessibility":
		for index in range(3):
			if scale_rect(index).has_point(point): return "scale_%d" % index
		if motion_rect().has_point(point): return "motion"
		if effects_rect().has_point(point): return "effects"
		if contrast_rect().has_point(point): return "contrast"
		return ""
	if section == "ambience":
		for index in range(3):
			if density_rect(index).has_point(point): return "density_%d" % index
		if sound_rect().has_point(point): return "sound"
		return ""
	for index in range(3):
		if quality_rect(index).has_point(point): return "quality_%d" % index
	for index in range(2):
		if fps_rect(index).has_point(point): return "fps_%d" % index
	return ""

func _activate(action: String) -> void:
	_epoch += 1
	if action.begins_with("tester_"):
		_activate_tester(action)
		return
	if action == "close":
		if section == "tester" and not tester_quote.is_empty():
			_cancel_tester_review()
			notice = "Review canceled. Your saved access is unchanged."
			queue_redraw()
			return
		_cancel_tester_review()
		close_requested.emit()
	elif action == "apply" and is_instance_valid(settings):
		if settings.set_presentation_preferences(selected_quality, selected_fps, selected_ui_scale, selected_reduced_motion, selected_reduced_effects, selected_ambient_density, selected_high_contrast, selected_ambient_sound):
			notice = "%s · %d FPS target · UI %d%% saved" % [settings.quality_name, settings.target_fps, settings.ui_scale_percent]
		else:
			notice = settings.storage_error
	elif action.begins_with("quality_"):
		selected_quality = action.trim_prefix("quality_").to_int()
	elif action.begins_with("fps_"):
		selected_fps = 30 if action.ends_with("0") else 60
	elif action.begins_with("tab_"):
		_cancel_tester_review()
		section = TABS[clampi(action.trim_prefix("tab_").to_int(), 0, TABS.size() - 1)]
		if section == "tester":
			refresh_tester()
			selected_tester = bool(tester_data.get("enabled", false))
			tester_scroll = 0
			notice = ""
	elif action.begins_with("scale_"):
		selected_ui_scale = [100, 110, 120][action.trim_prefix("scale_").to_int()]
	elif action == "motion":
		selected_reduced_motion = not selected_reduced_motion
	elif action == "effects":
		selected_reduced_effects = not selected_reduced_effects
	elif action == "contrast":
		selected_high_contrast = not selected_high_contrast
	elif action.begins_with("density_"):
		selected_ambient_density = [0, 50, 100][clampi(action.trim_prefix("density_").to_int(), 0, 2)]
	elif action == "sound":
		selected_ambient_sound = not selected_ambient_sound
	queue_redraw()

func panel_rect() -> Rect2:
	var inset := VaultUITheme.safe_inset(self)
	var extent := Vector2(minf(900, size.x - 64 - inset.x * 2), minf(620, size.y - 64 - inset.y * 2))
	return Rect2((size - extent) * 0.5, extent)

func tab_rect(index: int) -> Rect2:
	var rect := panel_rect()
	var width := (rect.size.x - 64.0 - 12.0 * (TABS.size() - 1)) / TABS.size()
	return Rect2(rect.position + Vector2(32 + index * (width + 12), 82), Vector2(width, 52))

func quality_rect(index: int) -> Rect2:
	var rect := panel_rect()
	var width := (rect.size.x - 88) / 3.0
	return Rect2(rect.position + Vector2(32 + index * (width + 12), 170), Vector2(width, 64))

func fps_rect(index: int) -> Rect2:
	var rect := panel_rect()
	var width := (rect.size.x - 76) * 0.5
	return Rect2(rect.position + Vector2(32 + index * (width + 12), 330), Vector2(width, 64))

func scale_rect(index: int) -> Rect2:
	return quality_rect(index)

func motion_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(32, 282), Vector2(rect.size.x - 64, 60))

func effects_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(32, 354), Vector2(rect.size.x - 64, 60))

func contrast_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(32, 426), Vector2(rect.size.x - 64, 60))

func density_rect(index: int) -> Rect2:
	return quality_rect(index)

func sound_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(32, 330), Vector2(rect.size.x - 64, 64))

func close_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(32, rect.size.y - 90), Vector2(220, 64))

func apply_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.end - Vector2(252, 90), Vector2(220, 64))

func _draw() -> void:
	if _font == null:
		return
	var rect := panel_rect()
	VaultUITheme.frame(self, rect, PANEL, GOLD, true)
	_text("SETTINGS", rect.position + Vector2(32, 44), 25, IVORY)
	_button(tab_rect(0), "GRAPHICS", section == "graphics")
	_button(tab_rect(1), "ACCESSIBILITY", section == "accessibility")
	_button(tab_rect(2), "AMBIENCE", section == "ambience")
	_button(tab_rect(3), "TEST ACCESS", section == "tester")
	if section == "accessibility":
		_draw_accessibility(rect)
	elif section == "ambience":
		_draw_ambience(rect)
	elif section == "tester":
		_draw_tester(rect)
	else:
		_draw_graphics(rect)
	if not notice.is_empty():
		_text(_fit(notice, rect.size.x - 64, 12), rect.position + Vector2(32, rect.size.y - 105), 12, TEAL)
	_button(close_rect(), "CANCEL REVIEW" if section == "tester" and not tester_quote.is_empty() else "BACK", false)
	_button(apply_rect(), ("CONFIRM & SAVE" if not tester_quote.is_empty() else "REVIEW CHANGE") if section == "tester" else "APPLY & SAVE", section != "tester" or tester_can_apply())

func _draw_graphics(rect: Rect2) -> void:
	_text("VISUAL QUALITY", rect.position + Vector2(32, 156), 13, GOLD)
	for index in range(3):
		_button(quality_rect(index), ["LOW", "MEDIUM", "HIGH"][index], selected_quality == index)
	_text(DETAILS[selected_quality], rect.position + Vector2(32, 260), 14, IVORY)
	_text("Combat warnings and navigation stay equally visible.", rect.position + Vector2(32, 284), 12, MUTED)
	_text("FRAME-RATE TARGET", rect.position + Vector2(32, 316), 13, GOLD)
	_button(fps_rect(0), "30 FPS · BALANCED", selected_fps == 30)
	_button(fps_rect(1), "60 FPS · CAPABLE DEVICES", selected_fps == 60)
	_text("60 FPS uses more battery and may increase heat.", rect.position + Vector2(32, 426), 14, IVORY)
	_text("Frame rates are goals requiring tests on your Android device.", rect.position + Vector2(32, 452), 12, MUTED)

func _draw_accessibility(rect: Rect2) -> void:
	_text("TEXT, ICON & CONTROL SIZE", rect.position + Vector2(32, 156), 13, GOLD)
	for index in range(3):
		var value: int = [100, 110, 120][index]
		_button(scale_rect(index), "%d%%" % value, selected_ui_scale == value)
	_text("Menus reflow at larger sizes; gameplay controls retain safe anchors.", rect.position + Vector2(32, 260), 12, MUTED)
	_toggle_button(motion_rect(), "REDUCED MOTION: " + ("ON" if selected_reduced_motion else "OFF"), "Calmer UI and static decorative water, foliage and motes.", selected_reduced_motion)
	_toggle_button(effects_rect(), "REDUCED PARTICLES & AURAS: " + ("ON" if selected_reduced_effects else "OFF"), "Lower decorative effects; attack warnings remain readable.", selected_reduced_effects)
	_toggle_button(contrast_rect(), "HIGH CONTRAST PROMPTS: " + ("ON" if selected_high_contrast else "OFF"), "Stronger interaction frames, portal labels and entry actions.", selected_high_contrast)

func _draw_ambience(rect: Rect2) -> void:
	_text("AMBIENT DENSITY", rect.position + Vector2(32, 156), 13, GOLD)
	for index in range(3):
		var density: int = [0, 50, 100][index]
		_button(density_rect(index), "%d%%%s" % [density, " · OFF" if density == 0 else ""], selected_ambient_density == density)
	_text("Motes and butterflies only; routes and combat warnings remain visible.", rect.position + Vector2(32, 260), 12, MUTED)
	_text("Density respects the selected quality ceiling and reduced effects.", rect.position + Vector2(32, 284), 12, MUTED)
	_toggle_button(sound_rect(), "AMBIENT SOUND: " + ("ON" if selected_ambient_sound else "OFF"), "Quiet Sanctuary wind and water · off by default.", selected_ambient_sound)
	_text("Original generated placeholder audio; device listening remains to be tested.", rect.position + Vector2(32, 430), 12, MUTED)
	_text("Your selections take effect only after Apply & Save.", rect.position + Vector2(32, 458), 12, IVORY)

func bind_session(value: Node) -> void:
	_cancel_tester_review()
	if is_instance_valid(session) and session.changed.is_connected(_on_tester_changed): session.changed.disconnect(_on_tester_changed)
	session = value
	if is_instance_valid(session): session.changed.connect(_on_tester_changed)
	refresh_tester()

func _on_tester_changed(_snapshot: Dictionary) -> void:
	if visible: refresh_tester()

func refresh_tester() -> void:
	tester_data = session.tester_access_snapshot().duplicate(true) if is_instance_valid(session) else {}
	if not tester_quote.is_empty() and (not bool(tester_data.get("available", false)) \
		or int(tester_quote.get("expected_revision", -1)) != int(tester_data.get("revision", -2))):
		_cancel_tester_review()
		notice = "This review expired. Review the access change again."
	queue_redraw()

func _test_active() -> bool:
	return visible and _tester_focused and section == "tester" and is_instance_valid(session) \
		and is_instance_valid(input_owner) and input_owner.mode == &"graphics" and input_owner._application_focused

func _cancel_tester_review() -> void:
	_epoch += 1
	var previous := tester_quote
	tester_quote = {}
	var ids: Array[int] = []
	for id: int in _pointers: ids.append(id)
	_pointers.clear()
	if not ids.is_empty(): pointers_canceled.emit(ids)
	if not previous.is_empty() and is_instance_valid(session): session.cancel_tester_access(previous)

func tester_can_apply() -> bool:
	return _test_active() and not _tester_busy and bool(tester_data.get("available", false)) \
		and (not tester_quote.is_empty() or selected_tester != bool(tester_data.get("enabled", false)))

func _activate_tester(action: String) -> void:
	if not _test_active() or _tester_busy: return
	refresh_tester()
	if action in ["tester_0", "tester_1"]:
		if not bool(tester_data.get("available", false)):
			notice = String(tester_data.get("reason", "Test access cannot be changed here."))
			queue_redraw()
			return
		_cancel_tester_review()
		selected_tester = action == "tester_1"
		tester_scroll = 0
		notice = "Selection only. Review and confirm to save."
	elif action == "tester_apply":
		if not tester_can_apply():
			notice = String(tester_data.get("reason", "Choose a different access setting first."))
			if notice.is_empty(): notice = "Choose a different access setting first."
			queue_redraw()
			return
		_tester_busy = true
		if tester_quote.is_empty():
			var requested: Dictionary = session.quote_tester_access(selected_tester)
			if _test_active() and bool(requested.get("ok", false)):
				tester_quote = requested.duplicate(true)
				tester_scroll = 0
				notice = "Review the changes below; swipe for more, then confirm."
			else:
				if bool(requested.get("ok", false)): session.cancel_tester_access(requested)
				notice = String(requested.get("error", "This access change is unavailable."))
		else:
			var accepted := tester_quote
			tester_quote = {}
			var saved: bool = session.commit_tester_access(accepted)
			refresh_tester()
			selected_tester = bool(tester_data.get("enabled", false))
			notice = "TEST ACCESS %s saved for this local profile." % ("ON" if selected_tester else "OFF") if saved else "Access was not changed. Review again when saving is available."
		_tester_busy = false
	queue_redraw()

func tester_option_rect(index: int) -> Rect2:
	var rect := panel_rect()
	var width := (rect.size.x - 76) * 0.5
	return Rect2(rect.position + Vector2(32 + index * (width + 12), 178), Vector2(width, 60))

func tester_detail_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(32, 252), Vector2(rect.size.x - 64, maxf(22, rect.size.y - 376)))

func tester_line_capacity() -> int:
	return maxi(1, floori(tester_detail_rect().size.y / (22.0 * ui_scale)))

func tester_lines() -> Array[String]:
	var paragraphs: Array[String] = [
		"Local testing only. Bypasses progression requirements for implemented home rooms, styles, dungeon depths, equipment and recipes.",
		"Your earned level and milestones stay unchanged. Item ownership, materials, Depthmark costs and talent points still apply.",
		"Unfinished content stays unavailable. This is not an online account permission or a purchase."
	]
	if not bool(tester_data.get("available", false)):
		paragraphs.push_front(String(tester_data.get("reason", "Return to Sanctuary or your home to change access.")))
	if not tester_quote.is_empty():
		paragraphs.push_front("REVIEW: turn TEST ACCESS " + ("ON" if selected_tester else "OFF"))
		var preview: Dictionary = tester_quote.get("preview", {})
		for line: Variant in preview.get("changes", []): paragraphs.append(String(line))
		if not selected_tester:
			paragraphs.append("Turning OFF restores normal requirements. Any listed test-only selections are reset; owned items and pets are retained.")
	var result: Array[String] = []
	var width := tester_detail_rect().size.x - 12
	for paragraph: String in paragraphs:
		var line := ""
		for word: String in paragraph.split(" "):
			var next := word if line.is_empty() else line + " " + word
			if not line.is_empty() and _font != null and _font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(13 * ui_scale)).x > width:
				result.append(line)
				line = word
			else: line = next
		if not line.is_empty(): result.append(line)
	return result

func _draw_tester(rect: Rect2) -> void:
	var enabled := bool(tester_data.get("enabled", false))
	_text("SAVED TEST ACCESS: " + ("ON" if enabled else "OFF"), rect.position + Vector2(32, 162), 14, TEAL if enabled else GOLD)
	_button(tester_option_rect(0), "OFF · NORMAL REQUIREMENTS", not selected_tester)
	_button(tester_option_rect(1), "ON · TEST IMPLEMENTED CONTENT", selected_tester)
	var lines := tester_lines()
	var capacity := tester_line_capacity()
	tester_scroll = clampi(tester_scroll, 0, maxi(0, lines.size() - capacity))
	var body := tester_detail_rect()
	for index in range(mini(capacity, lines.size() - tester_scroll)):
		_text(lines[tester_scroll + index], body.position + Vector2(0, (index + 0.8) * 22 * ui_scale), 13, IVORY)
	if lines.size() > capacity and notice.is_empty():
		_text("Swipe details · %d–%d / %d" % [tester_scroll + 1, mini(lines.size(), tester_scroll + capacity), lines.size()], rect.position + Vector2(32, rect.size.y - 105), 10, MUTED)

func _fit(value: String, width: float, pixels: int) -> String:
	if _font == null: return value
	var size_px := roundi(pixels * ui_scale)
	if _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x <= width: return value
	var shortened := value
	while not shortened.is_empty() and _font.get_string_size(shortened + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > width:
		shortened = shortened.left(shortened.length() - 1)
	return shortened + "…"

func _toggle_button(rect: Rect2, label: String, detail: String, selected: bool) -> void:
	VaultUITheme.frame(self, rect, Color("173549") if selected else Color("141e32"), TEAL if selected else GOLD, selected)
	_centered_text(label, rect.get_center() + Vector2(0, -5), 14, IVORY)
	_centered_text(detail, rect.get_center() + Vector2(0, 18), 11, MUTED)

func _centered_text(value: String, at: Vector2, pixels: int, tint: Color) -> void:
	var width := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(pixels * ui_scale)).x
	_text(value, at - Vector2(width * 0.5, 0), pixels, tint)

func _button(rect: Rect2, label: String, selected: bool) -> void:
	VaultUITheme.frame(self, rect, Color("173549") if selected else Color("141e32"), TEAL if selected else GOLD, selected)
	var fitted := _fit(label, rect.size.x - 18, 15)
	var width := _font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(15 * ui_scale)).x
	_text(fitted, rect.get_center() + Vector2(-width * 0.5, 5), 15, IVORY if selected else MUTED)

func _text(value: String, at: Vector2, font_size: int, color: Color) -> void:
	font_size = roundi(font_size * ui_scale)
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
