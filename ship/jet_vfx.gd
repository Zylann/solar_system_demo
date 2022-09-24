extends Node3D


@onready var _mesh_instance = $MeshInstance
@onready var _light = $OmniLight

var _power = 0.0
var _target_power = 0.0


func _ready():
	_mesh_instance.material_override = _mesh_instance.material_override.duplicate()


func set_power(p: float):
	_target_power = clamp(p, 0.0, 1.0)


func _process(delta: float):
	_power = lerp(_power, _target_power, delta * 2.0)
	var p = _power
	_mesh_instance.material_override.set_shader_parameter("u_power", p)
	_mesh_instance.scale = Vector3(1, 1, 0.1 + p * 15.0 * _mesh_instance.scale.x)
	_light.light_energy = p * 2.0
