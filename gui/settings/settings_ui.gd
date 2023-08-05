extends CenterContainer

const Settings = preload("res://settings.gd")
const Binding = preload("res://binding.gd")

@onready var _world_scale_x10_checkbox : CheckBox = \
	$PC/MC/VB/TabContainer/Game/GC/VBoxContainer/WorldScaleX10

@onready var _lens_flares_checkbox : CheckBox = $PC/MC/VB/TabContainer/Graphics/GC/LensFlares
@onready var _glow_checkbox : CheckBox = $PC/MC/VB/TabContainer/Graphics/GC/Glow
@onready var _shadows_checkbox : CheckBox = $PC/MC/VB/TabContainer/Graphics/GC/Shadows
@onready var _detail_rendering_selector : OptionButton = \
	$PC/MC/VB/TabContainer/Graphics/GC/DetailRenderingSelector

@onready var _main_volume_slider : Slider = $PC/MC/VB/TabContainer/Sound/GridContainer/MainVolume

@onready var _debug_text_checkbox : CheckBox = $PC/MC/VB/TabContainer/Debug/GC/ShowDebugText
@onready var _show_octree_nodes_checkbox : CheckBox = \
	$PC/MC/VB/TabContainer/Debug/GC/ShowOctreeNodes
@onready var _show_mesh_updates_checkbox : CheckBox = \
	$PC/MC/VB/TabContainer/Debug/GC/ShowMeshUpdates
@onready var _show_edited_data_blocks_checkbox : CheckBox = \
	$PC/MC/VB/TabContainer/Debug/GC/ShowEditedDataBlocks
@onready var _wireframe_checkbox : CheckBox = $PC/MC/VB/TabContainer/Debug/GC/Wireframe
@onready var _clouds_selector : OptionButton = $PC/MC/VB/TabContainer/Graphics/GC/CloudsSelector
@onready var _antialias_selector : OptionButton = \
	$PC/MC/VB/TabContainer/Graphics/GC/AntialiasSelector


var _settings : Settings
var _updating_gui := false
var _bindings : Array[Binding.BindingBase] = []


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
	# TODO Setting to toggle GPU generation
	_bindings.append(Binding.create(_settings, "main_volume_linear", _main_volume_slider))
	_bindings.append(Binding.create(_settings, "debug_text", _debug_text_checkbox))
	_bindings.append(Binding.create(_settings, "show_octree_nodes", _show_octree_nodes_checkbox))
	_bindings.append(Binding.create(_settings, "show_mesh_updates", _show_mesh_updates_checkbox))
	_bindings.append(Binding.create(_settings, "show_edited_data_blocks", 
		_show_edited_data_blocks_checkbox))
	_bindings.append(Binding.create(_settings, "wireframe", _wireframe_checkbox))
	_bindings.append(Binding.create(_settings, "clouds_quality", _clouds_selector))
	_bindings.append(Binding.create(_settings, "antialias", _antialias_selector))
	
	_update_ui()


func _update_ui():
	for binding in _bindings:
		binding.update_ui()


func _on_Close_pressed():
	hide()

