extends Node3D

const MultiSound = preload("res://sounds/multisound.gd")

const STEP_DISTANCE = 1.5
const STEP_DISTANCE_RANDOMNESS = 0.05

const _step_sounds = [
	preload("res://sounds/step_dirt_01.wav"),
	preload("res://sounds/step_dirt_02.wav"),
	preload("res://sounds/step_dirt_03.wav"),
	preload("res://sounds/step_dirt_04.wav"),
	preload("res://sounds/step_dirt_05.wav"),
	preload("res://sounds/step_dirt_06.wav"),
	preload("res://sounds/step_dirt_07.wav"),
	preload("res://sounds/step_dirt_08.wav"),
	preload("res://sounds/step_dirt_09.wav"),
	preload("res://sounds/step_dirt_10.wav")
]

const _dig_sounds = [
	preload("res://sounds/dig_01.wav"),
	preload("res://sounds/dig_02.wav"),
	preload("res://sounds/dig_03.wav"),
	preload("res://sounds/dig_04.wav"),
	preload("res://sounds/dig_05.wav")
]

@onready var _step_players = [
	$AudioStreamPlayer,
	$AudioStreamPlayer2
]

@onready var _dig_players = [
	$Digs/AudioStreamPlayer3,
	$Digs/AudioStreamPlayer4,
	$Digs/AudioStreamPlayer5
]

@onready var _waypoint_player = $Waypoint
@onready var _light_on_player = $FlashLightOn
@onready var _light_off_player = $FlashLightOff

var _last_step_position := Vector3()
var _step_distance := 0.0
var _step_multisound = MultiSound.new()
var _dig_multisound = MultiSound.new()


func play_dig(pos: Vector3):
	_dig_multisound.play(pos)


func play_waypoint():
	_waypoint_player.play()


func play_light_on():
	_light_on_player.play()


func play_light_off():
	_light_off_player.play()


func _ready():
	_step_multisound.set_players(_step_players)
	_step_multisound.set_streams(_step_sounds)

	_dig_multisound.set_players(_dig_players)
	_dig_multisound.set_streams(_dig_sounds)


func _on_Character_jumped():
	_play_step()


func _process(delta):
	var position = global_transform.origin
	var landed = get_parent().is_on_floor()
	if position.distance_to(_last_step_position) > _step_distance and landed:
		_last_step_position = position
		_play_step()
		_next_step_distance()


func _next_step_distance():
	_step_distance = STEP_DISTANCE + randf_range(-0.5, 0.5) * STEP_DISTANCE_RANDOMNESS


func _play_step():
	_step_multisound.play()

