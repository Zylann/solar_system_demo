extends Node

const Settings = preload("res://settings.gd")

@onready var _main_menu = $MainMenu
@onready var _settings_ui = $SettingsUI

var _settings = Settings.new()


func _ready():
	_settings_ui.set_settings(_settings)


func _on_MainMenu_start_requested():
	_main_menu.hide()
	var game_scene : PackedScene = load("res://game.tscn")
	var game = game_scene.instantiate()
	game.set_settings(_settings)
	add_child(game)
	# TODO Apply settings in game
	# TODO Add a pause menu
	# TODO Make settings UI available in game
	# TODO Allow return to main menu


func _on_MainMenu_settings_requested():
	_settings_ui.show()


func _on_MainMenu_exit_requested():
	get_tree().quit()


func _process(delta):
	AudioServer.set_bus_volume_db(0, linear_to_db(_settings.main_volume_linear))
	DDD.visible = _settings.debug_text


