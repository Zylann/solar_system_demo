extends Camera3D


@export var _head_path := NodePath()

var _head : Node3D


func _ready():
	_head = get_node(_head_path)
	# Workaround for Godot not allowing to select child nodes of a scene in the nodepath dialog
	if _head.has_method("get_head"):
		_head = _head.get_head()


func _process(delta: float):
	global_transform = _head.global_transform
