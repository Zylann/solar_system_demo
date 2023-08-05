extends ColorRect

const LoadingProgress = preload("res://solar_system/loading_progress.gd")

@onready var _label : Label = $CC/PC/VB/Label
@onready var _progress_bar : ProgressBar = $CC/PC/VB/ProgressBar


func _on_GameWorld_loading_progressed(info: LoadingProgress):
	if info.finished:
		hide()
	else:
		_label.text = info.message
		_progress_bar.value = info.progress
