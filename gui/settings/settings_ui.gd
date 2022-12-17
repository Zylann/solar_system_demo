extends CenterContainer

const Settings = preload("res://settings.gd")
const Binding = preload("res://binding.gd")

@onready var _world_scale_x10_checkbox = $PC/MC/VB/TabContainer/Game/GC/VBoxContainer/WorldScaleX10

@onready var _lens_flares_checkbox = $PC/MC/VB/TabContainer/Graphics/GC/LensFlares
@onready var _glow_checkbox = $PC/MC/VB/TabContainer/Graphics/GC/Glow
@onready var _shadows_checkbox = $PC/MC/VB/TabContainer/Graphics/GC/Shadows
@onready var _detail_rendering_selector = $PC/MC/VB/TabContainer/Graphics/GC/DetailRenderingSelector

@onready var _main_volume_slider = $PC/MC/VB/TabContainer/Sound/GridContainer/MainVolume

@onready var _debug_text_checkbox = $PC/MC/VB/TabContainer/Debug/GC/ShowDebugText


var _settings : Settings
var _updating_gui := false
var _bindings = []


func _ready():
	_detail_rendering_selector.clear()
	_detail_rendering_selector.add_item("Disabled", Settings.DETAIL_RENDERING_DISABLED)
	_detail_rendering_selector.add_item("CPU (slow)", Settings.DETAIL_RENDERING_CPU)
	_detail_rendering_selector.add_item("GPU (fast, requires Vulkan)", 
		Settings.DETAIL_RENDERING_GPU)


func set_settings(s: Settings):
	assert(_settings == null)
	
	_settings = s
	
	_bindings.append(Binding.create(_settings, "world_scale_x10", _world_scale_x10_checkbox))
	_bindings.append(Binding.create(_settings, "shadows_enabled", _shadows_checkbox))
	_bindings.append(Binding.create(_settings, "lens_flares_enabled", _lens_flares_checkbox))
	_bindings.append(Binding.create(_settings, "glow_enabled", _glow_checkbox))
	_bindings.append(Binding.create(_settings, "detail_rendering_mode", _detail_rendering_selector))
	_bindings.append(Binding.create(_settings, "main_volume_linear", _main_volume_slider))
	_bindings.append(Binding.create(_settings, "debug_text", _debug_text_checkbox))
	
	_update_ui()


func _update_ui():
	for binding in _bindings:
		binding.update_ui()


func _on_Close_pressed():
	hide()


func _unhandled_input(event):
	if visible == false:
		return
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_ESCAPE:
				hide()


