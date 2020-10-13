
static func get_sphere_volume(r: float) -> float:
	return PI * r * r * r * 4.0 / 3.0


static func find_node_by_type(parent, klass):
	for i in parent.get_child_count():
		var child = parent.get_child(i)
		if child is klass:
			return child
		var res = find_node_by_type(child, klass)
		if res != null:
			return res
	return null

