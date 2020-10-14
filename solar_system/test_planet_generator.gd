extends Node

const Util = preload("../util/util.gd")
const PlanetGenerator = preload("./planet_generator.gd")

var _root : Spatial
var _mesh_instance : MeshInstance

var _radius := 400.0
var _quad_count := 128

var _hill_noise = OpenSimplexNoise.new()
#var _ridge_noise = OpenSimplexNoise.new()


func _ready():
	_root = Spatial.new()
	add_child(_root)
	
	var box = MeshInstance.new()
	box.mesh = Util.create_wirecube_mesh()
	box.translation = -Vector3(1,1,1) * _radius
	box.scale = Vector3(1,1,1) * _radius * 2.0
	_root.add_child(box)
	
	var time_before = OS.get_ticks_msec()
	
	var generator := PlanetGenerator.new()
	var meshes = generator.generate(true)

	for i in len(meshes):
		var m = meshes[i]
		
		var mi = MeshInstance.new()
		mi.mesh = m.mesh
		_root.add_child(mi)
		
#		var sb = StaticBody.new()
#		var cs = CollisionShape.new()
#		cs.shape = m.shape
#		sb.add_child(cs)
#		mi.add_child(sb)

	var time_taken = OS.get_ticks_msec() - time_before
	print("Took ", time_taken, "ms")


func _process(delta):
	_root.rotate_y(delta * 0.2)
