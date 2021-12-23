@tool
extends Node3D
class_name CameraRig
# Accessor class that gives the nodes in the scene access the player or some
# frequently used nodes in the scene itself.

signal aim_fired(target_position)

@onready var camera: InterpolatedCamera3D = $InterpolatedCamera
@onready var spring_arm: SpringArm3D = $SpringArm
@onready var aim_ray: RayCast3D = $InterpolatedCamera/AimRay
@onready var aim_target: Sprite3D = $AimTarget

var player: CharacterBody3D


var zoom := 0.5:
	get:
		return zoom
	set(value):
		zoom = clamp(value, 0.0, 1.0)
		if not spring_arm:
			await spring_arm.ready
		spring_arm.zoom = zoom


@onready var _position_start: Vector3 = position


func _ready() -> void:
	top_level = true
	await owner.ready
	player = owner


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(["Missing player node" if not player else ""])
