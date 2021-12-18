@tool
class_name Player
extends CharacterBody3D
# Helper class for the Player scene's scripts to be able to have access to the
# camera and its orientation.

@onready var camera: CameraRig = $CameraRig
@onready var skin: Mannequiny = $Mannequiny
@onready var state_machine: StateMachine = $StateMachine


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(["Missing camera node" if not camera else ""])
