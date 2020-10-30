extends Node


func _process(delta):
	#var stats = _terrain.get_statistics()
	
	DDD.set_text("FPS", Engine.get_frames_per_second())
	#DDD.set_text("Main thread block updates", stats.remaining_main_thread_blocks)
	DDD.set_text("Static memory", _format_memory(OS.get_static_memory_usage()))
	DDD.set_text("Dynamic memory", _format_memory(OS.get_dynamic_memory_usage()))
	#DDD.set_text("Blocked lods", stats.blocked_lods)
	#DDD.set_text("Position", _avatar.translation)

	var global_stats = VoxelServer.get_stats()
	for p in [[global_stats.streaming, "streaming_"], [global_stats.meshing, "meshing_"]]:
		var pool_stats = p[0]
		var prefix = p[1]
		for k in pool_stats:
			DDD.set_text(str(prefix, k), pool_stats[k])

#	for k in _process_stat_names:
#		var v = stats[k]
#		if k in _process_stats:
#			_process_stats[k] = max(_process_stats[k], v)
#		else:
#			_process_stats[k] = v

#	_time_before_display_process_stats -= delta
#	if _time_before_display_process_stats < 0:
#		_time_before_display_process_stats = 1.0
#		_displayed_process_stats = _process_stats
#		_process_stats = {}
#
#	for k in _displayed_process_stats:
#		DDD.set_text(k, _displayed_process_stats[k])


static func _format_memory(m):
	var mb = m / 1000000
	var mbr = m % 1000000
	return str(mb, ".", mbr, " Mb")
