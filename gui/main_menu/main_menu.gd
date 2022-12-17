extends Control


signal start_requested
signal settings_requested
signal exit_requested


func _on_Start_pressed():
	start_requested.emit()


func _on_Settings_pressed():
	settings_requested.emit()


func _on_Exit_pressed():
	exit_requested.emit()
