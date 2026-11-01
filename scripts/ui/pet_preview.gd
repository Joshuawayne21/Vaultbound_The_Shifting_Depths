extends Control
## Isolated static catalog preview. No follower, animation loop or gameplay groups.
var viewport: SubViewport
var camera: Camera3D
var pivot: Node3D
var model: Node3D
var texture: TextureRect
var pet_id: StringName
var variant: StringName = &"natural"
var frame_requests := 0
var fitted_bounds := AABB()
var _settings: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_ensure_preview()

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
	light.shadow_enabled = false
	stage.add_child(light)
	pivot = Node3D.new()
	stage.add_child(pivot)
	camera = Camera3D.new()
	camera.fov = 34
	camera.current = true
	stage.add_child(camera)
	texture = TextureRect.new()
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.texture = viewport.get_texture()
	add_child(texture)
	_layout()

func set_pet(id: StringName, appearance: StringName = &"natural") -> void:
	_ensure_preview()
	var was_visible := is_visible_in_tree()
	show()
	if pet_id == id and variant == appearance and is_instance_valid(model):
		if not was_visible: _request_frame()
		return
	pet_id = id
	variant = appearance
	if is_instance_valid(model):
		pivot.remove_child(model)
		model.queue_free()
	model = null
	var catalog: Script = load("res://scripts/pets/pet_catalog.gd")
	var visual: Script = load("res://scripts/pets/pet_visual.gd")
	var definition: Resource = catalog.definition_for(id)
	if definition == null: return
	model = visual.new() as Node3D
	if not model.configure(definition, {"id": String(id), "variant": String(appearance)}):
		model.free()
		model = null
		return
	model.process_mode = Node.PROCESS_MODE_DISABLED
	pivot.add_child(model)
	model.apply_visual_settings(_settings)
	var measured: AABB = model.get_visual_bounds()
	model.position = -measured.get_center()
	fitted_bounds = AABB(measured.position - measured.get_center(), measured.size)
	# Authored silhouettes face local -Z; present their front three-quarter view.
	pivot.rotation_degrees = Vector3(0, 204, 0)
	var radius := maxf(0.1, fitted_bounds.size.length() * 0.5)
	var distance := radius / sin(deg_to_rad(camera.fov * 0.5)) * 1.12
	camera.near = maxf(0.01, distance - radius * 1.5)
	camera.far = distance + radius * 2 + 1
	camera.position = Vector3(0, radius * 0.12, distance)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	_request_frame()

func hide_preview() -> void:
	hide()
	if is_instance_valid(viewport): viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func apply_visual_settings(value: Dictionary) -> void:
	_settings = value.duplicate(true)
	if is_instance_valid(model): model.apply_visual_settings(_settings)
	_request_frame()

func _layout() -> void:
	if is_instance_valid(texture):
		texture.position = Vector2.ZERO
		texture.size = size
	_request_frame()

func _request_frame() -> void:
	if is_visible_in_tree() and is_instance_valid(model):
		frame_requests += 1
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
