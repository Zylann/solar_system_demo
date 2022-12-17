
static func create(obj, var_name: String, control: Control) -> BindingBase:
	if control is CheckBox:
		return CheckBoxBinding.new(obj, var_name, control as CheckBox)
	if control is Range:
		return RangeBinding.new(obj, var_name, control as Range)
	if control is OptionButton:
		return OptionBinding.new(obj, var_name, control as OptionButton)
	push_error("Cannot find binding type")
	return null


class BindingBase:
	var _var_name := ""
	var _obj
	var _updating_ui = false
	
	func update_ui():
		push_error("Unimplemented")


class CheckBoxBinding extends BindingBase:
	var _control : CheckBox
	
	func _init(obj, var_name: String, cb: CheckBox):
		_var_name = var_name
		_obj = obj
		_control = cb
		_control.toggled.connect(_on_gui_toggle)
	
	func _on_gui_toggle(enabled: bool):
		if _updating_ui:
			return
		_obj.set(_var_name, enabled)

	func update_ui():
		var v = _obj.get(_var_name)
		_updating_ui = true
		_control.button_pressed = v
		_updating_ui = false


class RangeBinding extends BindingBase:
	var _control : Range
	
	func _init(obj, var_name: String, r: Range):
		_var_name = var_name
		_obj = obj
		_control = r
		_control.value_changed.connect(_on_range_value_changed)
	
	func _on_range_value_changed(new_value: float):
		if _updating_ui:
			return
		_obj.set(_var_name, new_value)

	func update_ui():
		var v = _obj.get(_var_name)
		_updating_ui = true
		_control.value = v
		_updating_ui = false


class OptionBinding extends BindingBase:
	var _control : OptionButton
	
	func _init(obj, var_name: String, ob: OptionButton):
		_var_name = var_name
		_obj = obj
		_control = ob
		_control.get_popup().id_pressed.connect(_on_gui_option_selected)
	
	func _on_gui_option_selected(option: int):
		if _updating_ui:
			return
		_obj.set(_var_name, option)

	func update_ui():
		var v = _obj.get(_var_name)
		_updating_ui = true
		var i = _control.get_item_index(v)
		_control.select(i)
		_updating_ui = false

