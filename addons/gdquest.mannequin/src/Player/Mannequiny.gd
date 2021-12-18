extends Node3D
class_name Mannequiny
# Controls the animation tree's transitions for this animated character.

# # It has a signal connected to the player state machine, and uses the resulting
# state names to translate them into the states for the animation tree.

enum States { IDLE, RUN, AIR, LAND }

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var _playback: AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"]

var _move_direction := Vector3.ZERO
var move_direction := Vector3.ZERO:
	get:
		return _move_direction
	set(value):
		set_move_direction(value)


var _is_moving := false
var is_moving := false:
	get:
		return _is_moving
	set(value):
		set_is_moving(value)


func _ready() -> void:
	animation_tree.active = true


func set_move_direction(direction: Vector3) -> void:
	_move_direction = direction
	animation_tree["parameters/move_ground/blend_position"] = direction.length()


func set_is_moving(value: bool) -> void:
	_is_moving = value
	animation_tree["parameters/conditions/is_moving"] = value


func transition_to(state_id: int) -> void:
	match state_id:
		States.IDLE:
			_playback.travel("idle")
		States.LAND:
			_playback.travel("land")
		States.RUN:
			_playback.travel("move_ground")
		States.AIR:
			_playback.travel("jump")
		_:
			_playback.travel("idle")
