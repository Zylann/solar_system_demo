
# Handles mouse capture when clicking the game or hitting the Escape key.

extends Control

@export var capture_mouse_in_ready = true

signal escaped


func _ready():
	if capture_mouse_in_ready:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func capture():
	# Remove focus from the HUD
	var focus_owner = get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()
	
	# Capture the mouse for the game
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			capture()
	
	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
				# Get the mouse back
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				emit_signal("escaped")
