extends Node3D
## Three reused foam strips imply water flow without particles, fluid physics,
## screen-space effects or animated material instances. Rotate the scene for falls.

@export var flow_length := 10.0
@export var flow_speed := 0.65
var _distance := 0.0

func _process(delta: float) -> void:
	_distance = fposmod(_distance + delta * flow_speed, flow_length)
	for index in range(3):
		var foam := get_node("Foam%d" % index) as Node3D
		foam.position.z = fposmod(_distance + index * flow_length / 3.0, flow_length) - flow_length * 0.5
