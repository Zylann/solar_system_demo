extends Particles

onready var base_translation = translation


func _process(delta):
	var rb = get_parent().get_parent().get_parent()
	
	var velocity = rb.linear_velocity
	
	#var trans = transform
	#trans.origin = base_translation + velocity
	#transform = gtrans
	
	material_override.set_shader_param("u_position", global_transform.origin)
	material_override.set_shader_param("u_velocity", velocity)

