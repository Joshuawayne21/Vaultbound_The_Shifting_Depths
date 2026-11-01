class_name VaultItemInspectionPanel
extends Control
## Read-only inspection. Owns presentation and gestures, never ownership or saves.

signal close_requested
const UI = preload("res://scripts/ui/ui_theme.gd")
const ItemPresentation = preload("res://scripts/visual/item_presentation.gd")
var item: Dictionary = {}
var ui_scale := 1.0
var reduced_motion := false
var reduced_effects := false
var yaw := 0.0
var scroll := 0.0
var frame_requests := 0
var model_loads := 0
var model_available := false
var viewport: SubViewport
var model_pivot: Node3D
var presentation: Node3D
var fitted_bounds := AABB()
var model: Node3D
var camera: Camera3D
var texture: TextureRect
var _font: Font
var _clip: Control
var _text_canvas: Control
var _lines: Array[Dictionary] = []
var _pointers: Dictionary = {}
var _rotation_owner := -2
var _epoch := 0

class TextCanvas extends Control:
	var panel: VaultItemInspectionPanel
	func _draw() -> void:
		if is_instance_valid(panel): panel.draw_description(self)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_text_canvas = TextCanvas.new()
	_text_canvas.panel = self
	_text_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_text_canvas)
	set_process(false)
	hide()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_cancel_pointers()
	elif what == NOTIFICATION_RESIZED and visible and _font != null:
		_layout()
		_build_lines()
		_request_frame()

func apply_visual_settings(settings: Dictionary) -> void:
	ui_scale = UI.scale_from(settings)
	reduced_motion = bool(settings.get("reduced_motion", false))
	reduced_effects = bool(settings.get("reduced_effects", false))
	_cancel_pointers()
	if is_instance_valid(presentation): presentation.apply_visual_settings(settings)
	if visible:
		_build_lines()
		_layout()
		_request_frame()
	queue_redraw()

func open_item(value: Dictionary) -> void:
	_cancel_pointers()
	item = value.duplicate(true)
	yaw = 0.0
	scroll = 0.0
	show()
	_ensure_preview()
	_load_model()
	_layout()
	_build_lines()
	_request_frame()
	queue_redraw()

func refresh_item(value: Dictionary) -> void:
	if not visible or item == value: return
	var reload_model: bool = item.get("visual_scene", "") != value.get("visual_scene", "") or item.get("identified", true) != value.get("identified", true)
	item = value.duplicate(true)
	if reload_model:
		_load_model()
	else:
		_configure_presentation()
		_fit_camera()
	model_pivot.rotation.y = yaw
	_build_lines()
	_layout()
	_request_frame()
	queue_redraw()

func close_view() -> void:
	_cancel_pointers()
	hide()
	if is_instance_valid(texture): texture.hide()
	if is_instance_valid(viewport): viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _cancel_pointers() -> void:
	_pointers.clear()
	_rotation_owner = -2
	_epoch += 1

func panel_rect() -> Rect2:
	var inset := UI.safe_inset(get_parent())
	var extent := Vector2(minf(1120, size.x - 48 - inset.x * 2), minf(640, size.y - 40 - inset.y * 2))
	return Rect2((size - extent) * 0.5, extent)

func close_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.end.x - 144, rect.position.y + 18, 120, 52)

func preview_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(24, 134), Vector2(floorf(rect.size.x * 0.43) - 36, rect.size.y - 188))

func text_rect() -> Rect2:
	var left := preview_rect()
	return Rect2(Vector2(left.end.x + 24, left.position.y), Vector2(panel_rect().end.x - left.end.x - 48, left.size.y))

func handle_event(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE, KEY_I, KEY_O]: close_requested.emit()
	elif event is InputEventScreenTouch:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and not event.canceled: _begin(event.index, point)
		else: _end(event.index, point, event.canceled)
	elif event is InputEventScreenDrag:
		_drag(event.index, get_global_transform_with_canvas().affine_inverse() * event.position)
	elif event is InputEventMouseButton:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _begin(-1, point)
			else: _end(-1, point, false)
		elif event.pressed and text_rect().has_point(point) and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			scroll += -64 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 64
			_clamp_scroll()
			_text_canvas.queue_redraw()
	elif event is InputEventMouseMotion: _drag(-1, get_global_transform_with_canvas().affine_inverse() * event.position)

func _begin(id: int, point: Vector2) -> void:
	if _pointers.has(id): return
	var rotate := preview_rect().has_point(point) and _rotation_owner == -2 and model_available
	if rotate: _rotation_owner = id
	_pointers[id] = {"start": point, "last": point, "dragged": false, "epoch": _epoch,
		"rotate": rotate, "scroll": text_rect().has_point(point), "close": close_rect().has_point(point)}

func _drag(id: int, point: Vector2) -> void:
	if not _pointers.has(id): return
	var pointer: Dictionary = _pointers[id]
	pointer.dragged = bool(pointer.dragged) or point.distance_to(pointer.start) > 12
	if pointer.dragged and pointer.rotate and id == _rotation_owner:
		yaw = wrapf(yaw + (point.x - Vector2(pointer.last).x) * 0.012, -PI, PI)
		model_pivot.rotation.y = yaw
		_request_frame()
	elif pointer.dragged and pointer.scroll:
		scroll -= point.y - Vector2(pointer.last).y
		_clamp_scroll()
		_text_canvas.queue_redraw()
	pointer.last = point

func _end(id: int, point: Vector2, canceled: bool) -> void:
	if not _pointers.has(id): return
	var pointer: Dictionary = _pointers[id]
	_pointers.erase(id)
	if _rotation_owner == id: _rotation_owner = -2
	if not canceled and int(pointer.epoch) == _epoch and not pointer.dragged and pointer.close and close_rect().has_point(point):
		close_requested.emit()

func _ensure_preview() -> void:
	if is_instance_valid(viewport): return
	viewport = SubViewport.new()
	viewport.size = Vector2i(384, 384)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("cbd8cc")
	environment.environment.ambient_light_energy = 0.8
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32, -40, 0)
	light.light_color = Color("ffdfac")
	light.shadow_enabled = false
	stage.add_child(light)
	model_pivot = Node3D.new()
	stage.add_child(model_pivot)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.fov = 34
	camera.current = true
	texture = TextureRect.new()
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.texture = viewport.get_texture()
	add_child(texture)

func _load_model() -> void:
	if is_instance_valid(model):
		model_pivot.remove_child(model)
		model.queue_free()
	model = null
	if is_instance_valid(presentation):
		model_pivot.remove_child(presentation)
		presentation.queue_free()
	presentation = null
	model_available = false
	model_pivot.rotation = Vector3.ZERO
	var path := String(item.get("visual_scene", ""))
	if path.is_empty() or not bool(item.get("identified", true)) or not ResourceLoader.exists(path): return
	var scene := load(path) as PackedScene
	if scene == null: return
	model = scene.instantiate() as Node3D
	if model == null: return
	model_loads += 1
	# Remove authored scripts and disable every descendant BEFORE tree entry.
	# Static inspection never invokes model _ready logic or ambient processing.
	_prepare_static_model(model)
	model_pivot.add_child(model)
	var own_bounds := _visual_bounds(model, model_pivot)
	if not bool(own_bounds.valid): return
	model.position -= AABB(own_bounds.bounds).get_center()
	_configure_presentation()
	_fit_camera()
	model_available = true

func _prepare_static_model(node: Node) -> void:
	if node.get_script() != null: node.set_script(null)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)
	if node is GPUParticles3D or node is CPUParticles3D: node.emitting = false
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D:
		node.autoplay = false
		node.stop()
	if node is AnimationMixer: node.active = false
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is Area3D:
		node.monitoring = false
		node.monitorable = false
	for child: Node in node.get_children(): _prepare_static_model(child)

func _configure_presentation() -> void:
	if is_instance_valid(presentation):
		model_pivot.remove_child(presentation)
		presentation.queue_free()
	presentation = null
	if not is_instance_valid(model) or not bool(item.get("identified", true)): return
	var definition := VaultLootTable.item_for(String(item.get("item_id", item.get("id", ""))))
	if definition == null: return
	presentation = ItemPresentation.new()
	presentation.process_mode = Node.PROCESS_MODE_DISABLED
	presentation.configure(definition, item, null, &"inspection")
	model_pivot.add_child(presentation)
	presentation.apply_visual_settings({"reduced_motion": reduced_motion, "reduced_effects": reduced_effects})

func _visual_bounds(node: Node, relative_to: Node3D) -> Dictionary:
	var result := {"valid": false, "bounds": AABB()}
	if node is MeshInstance3D and node.mesh != null:
		result.bounds = relative_to.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
		result.valid = true
	elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
		var multi: MultiMesh = node.multimesh
		var count := multi.instance_count if multi.visible_instance_count < 0 else mini(multi.instance_count, multi.visible_instance_count)
		var transform: Transform3D = relative_to.global_transform.affine_inverse() * node.global_transform
		for index in range(count):
			var box: AABB = transform * multi.get_instance_transform(index) * multi.mesh.get_aabb()
			result.bounds = AABB(result.bounds).merge(box) if result.valid else box
			result.valid = true
	for child: Node in node.get_children():
		var child_result := _visual_bounds(child, relative_to)
		if child_result.valid:
			result.bounds = AABB(result.bounds).merge(child_result.bounds) if result.valid else child_result.bounds
			result.valid = true
	return result

func _fit_camera() -> void:
	var measured := _visual_bounds(model_pivot, model_pivot)
	if not bool(measured.valid): return
	fitted_bounds = measured.bounds
	# Fit the bounding sphere about the rotation pivot, including every rune.
	# The sphere keeps a small ring and its larger halo visible at every yaw.
	var radius := 0.1
	for index in range(8): radius = maxf(radius, fitted_bounds.get_endpoint(index).length())
	var distance := radius / sin(deg_to_rad(camera.fov * 0.5)) * 1.12
	camera.near = maxf(0.01, distance - radius * 1.5)
	camera.far = distance + radius * 2.0 + 1.0
	camera.position = Vector3(0, radius * 0.12, distance)
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _layout() -> void:
	_clip.position = text_rect().position
	_clip.size = text_rect().size
	_text_canvas.size = _clip.size
	if is_instance_valid(texture):
		texture.position = preview_rect().position
		texture.size = preview_rect().size
		texture.visible = visible and model_available

func _request_frame() -> void:
	if visible and model_available and is_instance_valid(viewport):
		frame_requests += 1
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _build_lines() -> void:
	_lines.clear()
	var owned := not String(item.get("uid", "")).is_empty()
	var origin := String(item.get("inspection_origin", "owned_instance" if owned else "catalog"))
	match origin:
		"demo_asset": _add_paragraph("LOCAL TEST ASSET · DEMO / NOT LIVE · NOT REAL INVENTORY", UI.GOLD)
		"demo_order": _add_paragraph("LOCAL TEST ORDER · DEMO / NOT LIVE · NOT REAL INVENTORY", UI.GOLD)
		"owned_instance": _add_paragraph("OWNED INSTANCE · " + String(item.get("uid", "")), UI.GOLD)
		"unsecured_stack": _add_paragraph("EXPEDITION LOOT · UNSECURED · Quantity %d" % int(item.get("quantity", 1)), UI.GOLD)
		"secured_reserve": _add_paragraph("SECURED LEGACY RESERVE · Quantity %d" % int(item.get("quantity", 1)), UI.GOLD)
		"merchant": _add_paragraph("MERCHANT STOCK · NOT PURCHASED · Quantity %d" % int(item.get("quantity", 1)), UI.GOLD)
		_: _add_paragraph("CATALOG REFERENCE · NOT AN OWNED INSTANCE", UI.GOLD)
	if origin == "unsecured_stack": _add_paragraph("Collected on this expedition. Extract safely to secure these items.", UI.MUTED)
	elif origin == "secured_reserve": _add_paragraph("Preserved from your earlier save. Claim into free inventory slots.", UI.MUTED)
	if not bool(item.get("obtainable", true)):
		_add_paragraph("UNAVAILABLE · Future content. Cannot be acquired or equipped in this prototype.", UI.WARNING)
	elif item.get("category", "") == "equipment" and not bool(item.get("combat_supported", true)):
		_add_paragraph("COMBAT UNAVAILABLE · This weapon family has no supported attacks.", UI.WARNING)
	if owned or origin in ["demo_asset", "demo_order"]:
		_add_paragraph("Enhancement +%d · Durability %d%% · Quantity %d" % [int(item.get("enhancement", 0)), int(item.get("durability", 100)), int(item.get("quantity", 1))], UI.IVORY)
	_add_paragraph(String(item.get("description", "")), UI.IVORY)
	if not bool(item.get("identified", true)):
		_add_paragraph("Hidden properties. Visit the Relic Appraiser before inspection.", UI.WARNING)
	else:
		var lore := String(item.get("lore", ""))
		if not lore.is_empty():
			_add_paragraph("LORE", UI.GOLD)
			_add_paragraph(lore, UI.IVORY)
		for effect: String in item.get("special_effects", []): _add_paragraph(effect, UI.TEAL)
	_add_paragraph("DISPLAY ART", UI.GOLD)
	_add_paragraph(UI.item_inspection_note(item), UI.MUTED)
	if not model_available: _add_paragraph("No inspection model available for this item.", UI.MUTED)
	_clamp_scroll()
	_text_canvas.queue_redraw()

func _add_paragraph(value: String, tint: Color) -> void:
	if value.is_empty(): return
	var line := ""
	for word: String in value.split(" "):
		var proposed := line + (" " if not line.is_empty() else "") + word
		if _font.get_string_size(proposed, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(15 * ui_scale)).x > text_rect().size.x - 18 and not line.is_empty():
			_lines.append({"text": line, "color": tint})
			line = word
		else: line = proposed
	if not line.is_empty(): _lines.append({"text": line, "color": tint})
	_lines.append({"text": "", "color": tint})

func _clamp_scroll() -> void:
	scroll = clampf(scroll, 0, maxf(0, _lines.size() * 25.0 * ui_scale - text_rect().size.y))

func draw_description(canvas: Control) -> void:
	for index in range(_lines.size()):
		var at := Vector2(0, (index * 25 + 20) * ui_scale - scroll)
		canvas.draw_string(_font, at, String(_lines[index].text), HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(15 * ui_scale), _lines[index].color)
	var total := _lines.size() * 25.0 * ui_scale
	if total > text_rect().size.y:
		var height := text_rect().size.y
		var thumb := maxf(24, height * height / total)
		canvas.draw_rect(Rect2(text_rect().size.x - 3, (height - thumb) * scroll / (total - height), 3, thumb), UI.TEAL)

func _draw() -> void:
	if not visible or _font == null: return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.018, 0.028, 0.99))
	UI.rarity_frame(self, panel_rect(), UI.PANEL, String(item.get("rarity", "common")))
	UI.frame(self, preview_rect(), Color("0b2028"))
	var rect := panel_rect()
	_text("ITEM INSPECTION", rect.position + Vector2(24, 42), 17, UI.GOLD)
	_text(String(item.get("label", "Item")), rect.position + Vector2(24, 82), 23, UI.IVORY)
	_text(UI.rarity_label(String(item.get("rarity", "common"))), rect.position + Vector2(24, 111), 12, UI.TEAL)
	UI.frame(self, close_rect(), Color("193f44"))
	_text("BACK", close_rect().position + Vector2(32, 33), 15, UI.IVORY)
	_text("DRAG TO ROTATE" if model_available else "MODEL UNAVAILABLE", preview_rect().position + Vector2(12, preview_rect().size.y + 26), 12, UI.MUTED)
	if not model_available: _text("No 3D artwork", preview_rect().get_center() + Vector2(-72, 0), 15, UI.MUTED)

func _text(value: String, at: Vector2, pixels: int, tint: Color) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(pixels * ui_scale), tint)
