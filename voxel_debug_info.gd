# Debug stuff. A bunch of hotkeys that do things.

extends Node

const CollisionScannerScene = \
	preload("res://addons/zylann.collision_scanner/collision_overlay.tscn")

export(bool) var enable_hotkeys = false

onready var _solar_system = get_parent()


func _ready():
	set_process_unhandled_input(enable_hotkeys)


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed:
			match event.scancode:
				KEY_C:
					_toggle_collision_scanner()

				KEY_KP_2:
					_debug_voxel_raycast_sweep()

				KEY_O:
					var vp = get_viewport()
					if vp.debug_draw == Viewport.DEBUG_DRAW_OVERDRAW:
						vp.debug_draw = Viewport.DEBUG_DRAW_DISABLED
					else:
						vp.debug_draw = Viewport.DEBUG_DRAW_OVERDRAW

				KEY_P:
					_dump_octree()

				KEY_U:
					print("PINNING VIEWER")
					var cam = get_viewport().get_camera()
					var viewer = cam.get_node("VoxelViewer")
					cam.remove_child(viewer)
					add_child(viewer)
					viewer.global_transform = cam.global_transform

				KEY_M:
					_log_pointed_mesh_block_info()


func _log_pointed_mesh_block_info():
	var current_planet = _solar_system.get_reference_stellar_body()
	if current_planet == null or current_planet.volume == null:
		print("No volume")
		return

	var volume = current_planet.volume

	var vt = volume.get_voxel_tool()
	vt.set_raycast_binary_search_iterations(4)
	var vtrans = volume.get_global_transform()
	var vtrans_inv = vtrans.affine_inverse()
	var cam = get_viewport().get_camera()
	var vp_size = get_viewport().size
	var vp_center = vp_size / 2
	var ray_pos_local = vtrans_inv * cam.project_ray_origin(vp_center)
	var ray_dir_local = vtrans_inv.basis * cam.project_ray_normal(vp_center)
	var hit = vt.raycast(ray_pos_local, ray_dir_local, 20)
	if hit == null:
		print("No hit")
		return

	var lod_index = 0
	var bpos = volume.voxel_to_mesh_block_position(hit.position, lod_index)
	var info = volume.debug_get_mesh_block_info(bpos, lod_index)
	print("Info about mesh block ", bpos, " at lod ", lod_index, ":")
	for key in info:
		print("- ", key, ": ", info[key])

	var render_to_data_factor = volume.get_mesh_block_size() / volume.get_data_block_size()
	for lz in render_to_data_factor:
		for ly in render_to_data_factor:
			for lx in render_to_data_factor:
				var lp = Vector3(lx, ly, lz)
				var dbpos = bpos * render_to_data_factor + lp
				var data_info = volume.debug_get_data_block_info(dbpos, lod_index)
				print("- data_block ", lp, ": ", data_info)


func _dump_octree():
	var current_planet = _solar_system.get_reference_stellar_body()
	var volume = current_planet.volume
	if volume == null:
		return
	var data = volume.debug_get_octrees_detailed()
	var f = ConfigFile.new()
	var cam = get_viewport().get_camera()
	f.set_value("debug", "octree", data)
	f.set_value("debug", "lod_count", volume.get_lod_count())
	f.set_value("debug", "block_size", volume.get_mesh_block_size())
	f.set_value("debug", "camera_transform", cam.global_transform)
	f.save("debug_data/octree.dat")


func _debug_voxel_raycast_sweep():
	var old_cubes = get_tree().get_nodes_in_group("ddd_ray_cubes")
	for c in old_cubes:
		c.queue_free()
	var current_planet = _solar_system.get_reference_stellar_body()
	var cube_mesh = CubeMesh.new()
	cube_mesh.size = 0.1 * Vector3(1,1,1)
	var volume = current_planet.volume
	if volume != null:
		var vt = volume.get_voxel_tool()
		vt.set_raycast_binary_search_iterations(4)
		var vtrans = volume.get_global_transform()
		var vtrans_inv = vtrans.affine_inverse()
		var cam = get_viewport().get_camera()
		var vp_size = get_viewport().size
		var vp_center = vp_size / 2
		var vp_r = vp_size.y / 3
		var ccount = 32
		for cy in ccount:
			for cx in ccount:
				var ndc = Vector2(
					float(cx) / float(ccount) - 0.5, 
					float(cy) / float(ccount) - 0.5)
				var spos = vp_center + vp_r * ndc
				var ray_pos_local = vtrans_inv * cam.project_ray_origin(spos)
				var ray_dir_local = vtrans_inv.basis * cam.project_ray_normal(spos)
				var hit = vt.raycast(ray_pos_local, ray_dir_local, 20)
				if hit != null:
					var mi = MeshInstance.new()
					mi.mesh = cube_mesh
					mi.translation = vtrans * (ray_pos_local + ray_dir_local * hit.distance)
					mi.add_to_group("ddd_ray_cubes")
					add_child(mi)


func _toggle_collision_scanner():
	if get_parent().has_node("CollisionOverlay"):
		get_parent().get_node("CollisionOverlay").queue_free()
	else:
		var overlay = CollisionScannerScene.instance()
		overlay.name = "CollisionOverlay"
		overlay.set_restart_when_camera_transform_changes(false)
		overlay.set_camera(get_viewport().get_camera())
		get_parent().add_child(overlay)


func _process(delta):
	DDD.set_text("FPS", Engine.get_frames_per_second())
	DDD.set_text("Static memory", _format_memory(OS.get_static_memory_usage()))
	DDD.set_text("Dynamic memory", _format_memory(OS.get_dynamic_memory_usage()))

	var global_stats = VoxelServer.get_stats()
	for stat_group_key in global_stats:
		var stat_group = global_stats[stat_group_key]
		for stat_key in stat_group:
			DDD.set_text(str(stat_group_key, "_", stat_key), stat_group[stat_key])

	var current_planet = _solar_system.get_reference_stellar_body()
	if current_planet != null and current_planet.volume != null:
		var volume_stats = current_planet.volume.get_statistics()
		DDD.set_text(str("[", current_planet.name, "] Blocked lods: "), volume_stats.blocked_lods)
		_debug_voxel_raycast(current_planet.volume)

		if current_planet.instancer != null:
			var instance_counts = current_planet.instancer.debug_get_instance_counts()
			var lib = current_planet.instancer.library
			for item_id in instance_counts:
				var item = lib.get_item(item_id)
				var count = instance_counts[item_id]
				DDD.set_text(str("Instances of ", item.name), count)


func _debug_voxel_raycast(volume):
	var vt = volume.get_voxel_tool()
	vt.set_raycast_binary_search_iterations(4)
	var vtrans = volume.get_global_transform()
	var vtrans_inv = vtrans.affine_inverse()
	var cam = get_viewport().get_camera()
	var vp_size = get_viewport().size
	var vp_center = vp_size / 2
	var ray_pos_local = vtrans_inv * cam.project_ray_origin(vp_center)
	var ray_dir_local = vtrans_inv.basis * cam.project_ray_normal(vp_center)
	var hit = vt.raycast(ray_pos_local, ray_dir_local, 20)
	if hit != null:
		DDD.draw_box(vtrans * (hit.position + Vector3(0.5, 0.5, 0.5)),
			Vector3(1.0, 1.0, 1.0), Color(0.5, 0.5, 0.5))
		var wpos = vtrans * (ray_pos_local + ray_dir_local * hit.distance)
		var s = 0.2
		DDD.draw_box(wpos, Vector3(s, s, s), Color(0, 1, 0))


static func _format_memory(m):
	var mb = m / 1000000
	var mbr = m % 1000000
	return str(mb, ".", mbr, " Mb")
