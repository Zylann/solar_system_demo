extends Camera


export var distance_to_target = 5.0

var _target = null
var _prev_target_pos = Vector3()
var _max_target_speed = 50.0


func _ready():
	get_parent().connect("reference_body_changed", self, "_on_solar_system_reference_body_changed")


func _on_solar_system_reference_body_changed(info):
	transform = info.inverse_transform * transform
	_prev_target_pos = info.inverse_transform * _prev_target_pos


func set_target(target):
	_target = target
	_prev_target_pos = _target.global_transform.origin


func _get_ideal_transform(target_transform):
	var ct = target_transform
	ct.origin += target_transform.basis * Vector3(0, distance_to_target / 3.0, distance_to_target)
	return ct


func _physics_process(delta: float):
	var prev_trans = transform
	
	# Get ideal transform
	var tt = _target.global_transform
	var ct = _get_ideal_transform(tt)
	transform = ct
	var up = ct.basis.y
	look_at(tt.origin + 1.5 * tt.basis.y, up)
	var ideal_trans = transform
	var trans = ideal_trans
	
	# Collision avoidance
	var dss = get_world().direct_space_state
	var ignored = [_target] if _target is RigidBody else []
	var hit = dss.intersect_ray(tt.origin, ideal_trans.origin, ignored)
	if not hit.empty():
		#var hit_normal = hit.normal
		trans.origin = hit.position + 0.3 * hit.normal
	
	# Add latency (using interpolation)
#	var q1 = Quat(prev_trans.basis)
#	var q2 = Quat(trans.basis)
#	var q = q1.slerp(q2, 20.0 * delta)
#	trans.basis = Basis(q)
	trans = prev_trans.interpolate_with(trans, 25.0 * delta)
	
	# Assign final transform
	transform = trans
	
	_prev_target_pos = tt.origin

