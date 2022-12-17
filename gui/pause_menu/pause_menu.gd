extends Control


signal resume_requested
signal settings_requested
signal exit_to_menu_requested
signal exit_to_os_requested


func _on_Resume_pressed():
	resume_requested.emit()


func _on_Settings_pressed():
	settings_requested.emit()


func _on_ExitToMenu_pressed():
	exit_to_menu_requested.emit()


func _on_ExitToOs_pressed():
	exit_to_os_requested.emit()

