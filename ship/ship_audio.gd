extends Node3D

const MultiSound = preload("res://sounds/multisound.gd")

const ShipIdleOnSound = preload("res://sounds/ship_idle_on.wav")
const ShipIdleOffSound = preload("res://sounds/ship_idle_off.wav")

const ShipHitSounds = [
	preload("res://sounds/ship_hit_01.wav"),
	preload("res://sounds/ship_hit_02.wav"),
	preload("res://sounds/ship_hit_03.wav"),
	preload("res://sounds/ship_hit_04.wav"),
	preload("res://sounds/ship_hit_05.wav")
]

@onready var _main_jets_player = $MainJets
@onready var _secondary_jets_player = $SecondaryJets
@onready var _idle_player = $ShipIdle
@onready var _hit_players = [
	$Hit01,
	$Hit02,
	$Hit03
]
@onready var _on_player = $On
@onready var _off_player = $Off
@onready var _superspeed_start_player = $SuperSpeedOn
@onready var _superspeed_stop_player = $SuperSpeedOff
@onready var _superspeed_loop_player = $SuperSpeedLoop
# TODO Hardcoded path is not good.
@onready var _ambient_sounds = get_node("/root/Main/GameWorld/AmbientSounds")
@onready var _air_friction_player = $AirFriction
@onready var _scrape_player = $Scrape

var _smooth_main_jet_power := 0.0
var _target_main_jet_power := 0.0

var _smooth_secondary_jet_power := 0.0
var _target_secondary_jet_power := 0.0

var _hit_multisound


func _ready():
	_idle_player.stream = ShipIdleOnSound
	_idle_player.play()
	
	_hit_multisound = MultiSound.new()
	_hit_multisound.set_streams(ShipHitSounds)
	_hit_multisound.set_players(_hit_players)


func set_main_jet_power(power: float):
	_target_main_jet_power = power


func set_secondary_jet_power(power: float):
	_target_secondary_jet_power = power


func play_enabled():
	_on_player.play()
	_idle_player.stream = ShipIdleOnSound
	_idle_player.play()
	_air_friction_player.play()


func play_disabled():
	_off_player.play()
	_idle_player.stream = ShipIdleOffSound
	_idle_player.play()
	_air_friction_player.stop()


func play_start_superspeed():
	_superspeed_start_player.play()
	_superspeed_loop_player.play()


func play_stop_superspeed():
	_superspeed_stop_player.play()
	_superspeed_loop_player.stop()


func _process(delta):
	_smooth_main_jet_power = lerp(_smooth_main_jet_power, _target_main_jet_power, delta * 5.0)
	var jet_power = clamp(_smooth_main_jet_power, 0.0, 1.0)
	_main_jets_player.volume_db = linear_to_db(jet_power)
	_main_jets_player.pitch_scale = lerp(0.8, 1.0, jet_power)

	_smooth_secondary_jet_power = \
		lerp(_smooth_secondary_jet_power, _target_secondary_jet_power, delta * 5.0)
	jet_power = clamp(_smooth_secondary_jet_power, 0.0, 1.0)
	_secondary_jets_player.volume_db = linear_to_db(jet_power) - 5.0
	_secondary_jets_player.pitch_scale = lerp(0.8, 1.0, jet_power)
	
	var speed = get_parent().linear_velocity.length()
	var air_factor = clamp(speed / get_parent().speed_cap_on_planet, 0.0, 1.0)
	var planet_factor = _ambient_sounds.get_planet_factor()
	_air_friction_player.volume_db = linear_to_db((air_factor * 0.9 + 0.1) * planet_factor)
	DDD.set_text("SFX air factor", air_factor)
	
	var contacts = get_parent().get_last_contacts_count()
	if contacts > 0 and not get_parent().freeze:
		if not _scrape_player.playing:
			_scrape_player.play()
		_scrape_player.volume_db = linear_to_db(clamp(air_factor * 5.0, 0.0, 1.0))
	else:
		if _scrape_player.playing:
			_scrape_player.stop()


func _on_Ship_body_entered(body):
	#print("Body enter ", body)
	_hit_multisound.play(global_transform.origin)
