extends ColorRect

@onready var _label = $CC/PC/VB/Label
@onready var _progress_bar = $CC/PC/VB/ProgressBar


func _on_GameWorld_loading_progressed(info):
	if info.finished:
		hide()
	else:
		_label.text = info.message
		_progress_bar.value = info.progress
