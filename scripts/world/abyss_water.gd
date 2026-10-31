extends Node3D
## Opaque water shading plus three reused foam ribbons. CPU updates are limited
## to 10/15/20 Hz by quality; no fluid simulation, refraction or screen textures.

@export var flow_length := 10.0
@export var flow_speed := 0.65
var _distance := 0.0
var _elapsed := 0.0
var _interval := 1.0 / 15.0
var _foam: Array[Node3D] = []

func _ready() -> void:
	add_to_group("visual_quality")
	for index in range(3):
		var ribbon := get_node_or_null("Foam%d" % index) as Node3D
		if ribbon != null:
			_foam.append(ribbon)
	var settings := get_node_or_null("/root/VisualSettings")
	if settings != null and settings.has_method("apply_to"):
		settings.apply_to(self)

func apply_visual_settings(settings: Dictionary) -> void:
	var quality := clampi(int(settings.get("quality", settings.get("current_quality", 1))), 0, 2)
	_interval = 1.0 / float(10 + quality * 5)
	for index in range(_foam.size()):
		_foam[index].visible = quality > 0 or index < 2

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < _interval or not is_visible_in_tree():
		return
	_distance = fposmod(_distance + _elapsed * flow_speed, maxf(0.1, flow_length))
	_elapsed = 0.0
	for index in range(_foam.size()):
		_foam[index].position.z = fposmod(_distance + index * flow_length / 3.0, flow_length) - flow_length * 0.5
