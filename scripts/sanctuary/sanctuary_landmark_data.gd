class_name SanctuaryLandmarkData
extends Resource
## Authored, presentation-only exterior landmarks. No reward or navigation data.

@export var trees: Array[Dictionary] = []
@export var waterfalls: Array[Dictionary] = []
@export var floating_stones: Array[Dictionary] = []
@export var minimum_radius := 56.0
@export var maximum_meshes := 20
@export var maximum_triangles := 12000
@export var optional_mesh_caps := PackedInt32Array([2, 4, 7])
@export var visibility_distance := 180.0
