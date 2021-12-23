# Copyright © 2020-2021 Hugo Locurcio and contributors - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends Camera3D
class_name InterpolatedCamera3D
@icon("interpolated_camera_3d.svg")

# The factor to use for asymptotical translation lerping.
# If 0, the camera will stop moving. If 1, the camera will move instantly.
@export_range(0, 1, 0.001) var translate_speed := 0.95

# The factor to use for asymptotical rotation lerping.
# If 0, the camera will stop rotating. If 1, the camera will rotate instantly.
@export_range(0, 1, 0.001) var rotate_speed := 0.95

# The factor to use for asymptotical FOV lerping.
# If 0, the camera will stop changing its FOV. If 1, the camera will change its FOV instantly.
# Note: Only works if the target node is a Camera3D.
@export_range(0, 1, 0.001) var fov_speed := 0.95

# The factor to use for asymptotical Z near/far plane distance lerping.
# If 0, the camera will stop changing its Z near/far plane distance. If 1, the camera will do so instantly.
# Note: Only works if the target node is a Camera3D.
@export_range(0, 1, 0.001) var near_far_speed := 0.95

# The node to target.
# Can optionally be a Camera3D to support smooth FOV and Z near/far plane distance changes.
@export_node_path(Node3D) var target: NodePath


func _process(delta: float) -> void:
	if not has_node(target):
		return

	# TODO: Fix delta calculation so it behaves correctly if the speed is set to 1.0.
	var translate_factor := translate_speed * delta * 10
	var rotate_factor := rotate_speed * delta * 10
	var target_node := get_node(target) as Node3D
	var target_xform := target_node.get_global_transform()
	# Interpolate the origin and basis separately so we can have different translation and rotation
	# interpolation speeds.
	var local_transform_only_origin := Transform3D(Basis(), get_global_transform().origin)
	var local_transform_only_basis := Transform3D(get_global_transform().basis, Vector3())
	local_transform_only_origin = local_transform_only_origin.interpolate_with(target_xform, translate_factor)
	local_transform_only_basis = local_transform_only_basis.interpolate_with(target_xform, rotate_factor)
	set_global_transform(Transform3D(local_transform_only_basis.basis, local_transform_only_origin.origin))

	if target_node is Camera3D:
		var camera := target_node as Camera3D
		# The target node can be a Camera3D, which allows interpolating additional properties.
		# In this case, make sure the "Current" property is enabled on the InterpolatedCamera3D
		# and disabled on the Camera3D.
		if camera.projection == projection:
			# Interpolate the near and far clip plane distances.
			var near_far_factor := near_far_speed * delta * 10
			var fov_factor := fov_speed * delta * 10
			var new_near := lerp(near, camera.near, near_far_factor) as float
			var new_far := lerp(far, camera.far, near_far_factor) as float

			# Interpolate size or field of view.
			if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
				var new_size := lerp(size, camera.size, fov_factor) as float
				set_orthogonal(new_size, new_near, new_far)
			else:
				var new_fov := lerp(fov, camera.fov, fov_factor) as float
				set_perspective(new_fov, new_near, new_far)
