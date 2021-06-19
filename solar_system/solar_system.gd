extends Node

const StellarBody = preload("./stellar_body.gd")

const SunMaterial = preload("./materials/sun_yellow.tres")
const PlanetRockyMaterial = preload("./materials/planet_material_rocky.tres")
const PlanetGrassyMaterial = preload("./materials/planet_material_grassy.tres")
const WaterSeaMaterial = preload("./materials/water_sea_material.tres")
const VolumetricAtmosphereScene = preload("res://addons/zylann.atmosphere/planet_atmosphere.tscn")
const CameraScene = preload("../camera/camera.tscn")
const ShipScene = preload("../ship/ship.tscn")
const BasePlanetVoxelGraph = preload("./voxel_graph_planet_v4.tres")
const BigRock1Scene = preload("../props/big_rocks/big_rock1.tscn")
const Rock1Scene = preload("../props/rocks/rock1.tscn")

const BODY_REFERENCE_ENTRY_RADIUS_FACTOR = 3.0
const BODY_REFERENCE_EXIT_RADIUS_FACTOR = 3.25 # Must be higher for hysteresis

class ReferenceChangeInfo:
	var inverse_transform : Transform

class LoadingProgress:
	var progress := 0.0
	var message := ""
	var finished := false


signal reference_body_changed(info)
signal loading_progressed(info)


onready var _environment = $WorldEnvironment.environment
onready var _spawn_point = $SpawnPoint
onready var _mouse_capture = $MouseCapture
onready var _hud = $HUD

var _ship = null

var _bodies := []
var _reference_body_id := 0
var _directional_light : DirectionalLight
var _physics_count := 0
var _physics_count_on_last_reference_change = 0


func _ready():
	set_physics_process(false)
	_hud.hide()
	
	var sun = StellarBody.new()
	sun.type = StellarBody.TYPE_SUN
	sun.radius = 2000.0
	sun.self_revolution_time = 60.0
	sun.orbit_revolution_time = 60.0
	sun.name = "Sun"
	_bodies.append(sun)
	
	var planet = StellarBody.new()
	planet.name = "Mercury"
	planet.type = StellarBody.TYPE_ROCKY
	planet.radius = 900.0
	planet.parent_id = 0
	planet.distance_to_parent = 14400.0
	planet.self_revolution_time = 0.0*10.0 * 60.0
	planet.orbit_revolution_time = 0.0*50.0 * 60.0
	planet.atmosphere_color = Color(1.0, 0.4, 0.1)
	_bodies.append(planet)

	planet = StellarBody.new()
	planet.name = "Earth"
	planet.type = StellarBody.TYPE_ROCKY
	planet.radius = 1800.0
	planet.parent_id = 0
	planet.distance_to_parent = 25600.0
	planet.self_revolution_time = 10.0 * 60.0
	planet.orbit_revolution_time = 150.0 * 60.0
	planet.atmosphere_color = Color(0.3, 0.5, 1.0)
	planet.sea = true
	var earth_id = len(_bodies)
	_bodies.append(planet)

	planet = StellarBody.new()
	planet.name = "Moon"
	planet.type = StellarBody.TYPE_ROCKY
	planet.radius = 600.0
	planet.parent_id = earth_id
	planet.distance_to_parent = 5000.0
	planet.self_revolution_time = 10.0 * 60.0
	planet.orbit_revolution_time = 10.0 * 60.0
	planet.atmosphere_color = Color(0.2, 0.2, 0.2)
	_bodies.append(planet)

	planet = StellarBody.new()
	planet.name = "Mars"
	planet.type = StellarBody.TYPE_ROCKY
	planet.radius = 1280.0
	planet.parent_id = 0
	planet.distance_to_parent = 48000.0
	planet.self_revolution_time = 10.0 * 60.0
	planet.orbit_revolution_time = 100.0 * 60.0
	planet.atmosphere_color = Color(1.2, 0.8, 0.5)
	_bodies.append(planet)

	planet = StellarBody.new()
	planet.name = "Jupiter"
	planet.type = StellarBody.TYPE_GAS
	planet.radius = 3000.0
	planet.parent_id = 0
	planet.distance_to_parent = 70400.0
	planet.self_revolution_time = 8.0 * 60.0
	planet.orbit_revolution_time = 300.0 * 60.0
	planet.atmosphere_color = Color(0.8, 0.6, 0.4)
	_bodies.append(planet)
	
	_directional_light = DirectionalLight.new()
	_directional_light.shadow_enabled = true
	_directional_light.shadow_color = Color(0.2, 0.2, 0.2)
	_directional_light.directional_shadow_normal_bias = 0.2
	_directional_light.directional_shadow_split_1 = 0.1
	_directional_light.directional_shadow_split_2 = 0.2
	_directional_light.directional_shadow_split_3 = 0.5
	_directional_light.directional_shadow_blend_splits = true
	_directional_light.directional_shadow_max_distance = 200.0
	_directional_light.name = "DirectionalLight"
	
	var progress_info = LoadingProgress.new()
	
	for i in len(_bodies):
		var body : StellarBody = _bodies[i]
		
		progress_info.message = "Generating {0}...".format([body.name])
		progress_info.progress = float(i) / float(len(_bodies))
		emit_signal("loading_progressed", progress_info)
		yield(get_tree(), "idle_frame")

		var root := Spatial.new()
		root.name = body.name
		body.node = root
		add_child(root)

		if body.type == StellarBody.TYPE_SUN:
			var mi = MeshInstance.new()
			var mesh = SphereMesh.new()
			mesh.radius = body.radius
			mesh.height = 2.0 * mesh.radius
			mi.mesh = mesh
			mi.material_override = SunMaterial
			mi.cast_shadow = false
			root.add_child(mi)
			
		elif body.type == StellarBody.TYPE_ROCKY:
			var mat : ShaderMaterial
			# TODO Dont hardcode this
			if body.name == "Earth":
				mat = PlanetGrassyMaterial.duplicate()
			else:
				mat = PlanetRockyMaterial.duplicate()
			mat.set_shader_param("u_mountain_height", body.radius + 80.0)
			
			var generator : VoxelGeneratorGraph = BasePlanetVoxelGraph.duplicate(true)
			var sphere_node_id := generator.find_node_by_name("sphere")
			# TODO Need an API that doesnt suck
			var radius_input_id := 3
			generator.set_node_default_input(sphere_node_id, radius_input_id, body.radius)
			var ravine_blend_noise_node_id := generator.find_node_by_name("ravine_blend_noise")
			var noise_param_id := 0
			var ravine_blend_noise = generator.get_node_param(ravine_blend_noise_node_id, noise_param_id)
			ravine_blend_noise.seed = body.name.hash()
			var cave_height_node_id := generator.find_node_by_name("cave_height_subtract")
			generator.set_node_default_input(cave_height_node_id, 1, body.radius - 100.0)
			var cave_noise_node_id := generator.find_node_by_name("cave_noise")
			var cave_noise = generator.get_node_param(cave_noise_node_id, noise_param_id)
			cave_noise.period = 900.0 / body.radius
			# var cave_height_multiplier_node_id = generator.find_node_by_name("cave_height_multiplier")
			# generator.set_node_default_input(cave_height_multiplier_node_id, 1, 0.015)
			generator.compile()

			generator.use_subdivision = true
			generator.subdivision_size = 8

#			ResourceSaver.save(str("debug_data/generator_", body.name, ".tres"), generator, 
#				ResourceSaver.FLAG_BUNDLE_RESOURCES)

			var sphere_normalmap = Image.new()
			sphere_normalmap.create(512, 256, false, Image.FORMAT_RGB8)
			generator.bake_sphere_normalmap(sphere_normalmap, body.radius * 0.95, 200.0 / body.radius)
			sphere_normalmap.save_png(str("debug_data/test_sphere_normalmap_", body.name, ".png"))
			var sphere_normalmap_tex = ImageTexture.new()
			sphere_normalmap_tex.create_from_image(sphere_normalmap)
			mat.set_shader_param("u_global_normalmap", sphere_normalmap_tex)

			var stream = VoxelStreamSQLite.new()
			stream.database_path = str("debug_data/", body.name, ".sqlite")

			var pot = 1024
			while body.radius >= pot:
				pot *= 2
			var volume := VoxelLodTerrain.new()
			volume.lod_count = 7
			volume.lod_distance = 60.0
			volume.collision_lod_count = 2
			volume.generator = generator
			volume.stream = stream
			volume.view_distance = 100000
			volume.voxel_bounds = AABB(Vector3(-pot, -pot, -pot), Vector3(2 * pot, 2 * pot, 2 * pot))
			volume.lod_fade_duration = 0.3
			print("DDD ", body.name, " has bounds ", volume.voxel_bounds, " for radius ", body.radius)
			volume.material = mat
			# TODO Set before setting voxel bounds?
			volume.mesh_block_size = 32
			#volume.set_process_mode(VoxelLodTerrain.PROCESS_MODE_PHYSICS)
			body.volume = volume
			root.add_child(volume)

			# Configure instancing
			if true:
				var pebble1 = load("res://props/pebbles/pebble1.obj")
				var rock1 = load("res://props/rocks/rock1.obj")
				var big_rock1 = load("res://props/big_rocks/big_rock1.obj")

				for mesh in [pebble1, rock1, big_rock1]:
					mesh.surface_set_material(0, load("res://props/rocks/rock_material.tres"))

				var instancer = VoxelInstancer.new()
				instancer.set_up_mode(VoxelInstancer.UP_MODE_SPHERE)

				var library = VoxelInstanceLibrary.new()

				var instance_generator = VoxelInstanceGenerator.new()
				instance_generator.density = 0.15
				instance_generator.min_scale = 0.2
				instance_generator.max_scale = 0.4
				instance_generator.min_slope_degrees = 0
				instance_generator.max_slope_degrees = 40
				#instance_generator.set_layer_min_height(layer_index, body.radius * 0.95)
				instance_generator.random_vertical_flip = true
				instance_generator.vertical_alignment = 0.0
				instance_generator.emit_mode = VoxelInstanceGenerator.EMIT_FROM_FACES
				instance_generator.noise = FastNoiseLite.new()
				instance_generator.noise.period = 16
				instance_generator.noise.fractal_octaves = 2
				instance_generator.noise_on_scale = 1
				#instance_generator.noise.noise_type = FastNoiseLite.TYPE_PERLIN
				var item = VoxelInstanceLibraryItem.new()
				
				if body.name == "Earth":
					var grass_mesh = preload("res://props/grass/grass.tscn").instance()
					item.setup_from_template(grass_mesh)
					grass_mesh.free()

					instance_generator.density = 0.32
					instance_generator.min_scale = 0.8
					instance_generator.max_scale = 1.6
					instance_generator.random_vertical_flip = false

					item.name = "grass"
					
				else:
					item.set_mesh(pebble1, 0)
					item.name = "pebbles"

				item.generator = instance_generator
				item.persistent = false
				item.lod_index = 0
				library.add_item(2, item)

				instance_generator = VoxelInstanceGenerator.new()
				instance_generator.density = 0.08
				instance_generator.min_scale = 0.5
				instance_generator.max_scale = 0.8
				instance_generator.min_slope_degrees = 0
				instance_generator.max_slope_degrees = 12
				instance_generator.vertical_alignment = 0.0
				item = VoxelInstanceLibraryItem.new()
				var rock1_template = Rock1Scene.instance()
				item.setup_from_template(rock1_template)
				rock1_template.free()
				item.generator = instance_generator
				item.persistent = true
				item.lod_index = 2
				item.name = "rock"
				library.add_item(0, item)

				instance_generator = VoxelInstanceGenerator.new()
				instance_generator.density = 0.03
				instance_generator.min_scale = 0.6
				instance_generator.max_scale = 1.2
				instance_generator.min_slope_degrees = 0
				instance_generator.max_slope_degrees = 10
				instance_generator.vertical_alignment = 0.0
				item = VoxelInstanceLibraryItem.new()
				item.set_mesh(big_rock1, 0)
				item.generator = instance_generator
				item.persistent = true
				item.lod_index = 3
				item.name = "big_rock"
				library.add_item(1, item)

				instance_generator = VoxelInstanceGenerator.new()
				instance_generator.noise = FastNoiseLite.new()
				instance_generator.noise.period = 16
				instance_generator.noise.fractal_octaves = 2
				instance_generator.noise_on_scale = 1
				instance_generator.density = 0.06
				instance_generator.min_scale = 0.6
				instance_generator.max_scale = 3.0
				instance_generator.scale_distribution = VoxelInstanceGenerator.DISTRIBUTION_CUBIC
				instance_generator.min_slope_degrees = 140
				instance_generator.max_slope_degrees = 180
				instance_generator.vertical_alignment = 1.0
				instance_generator.offset_along_normal = -0.5
				item = VoxelInstanceLibraryItem.new()
				var cone = CylinderMesh.new()
				cone.radial_segments = 8
				cone.rings = 0
				cone.top_radius = 0.5
				cone.bottom_radius = 0.1
				cone.height = 2.5
				cone.material = load("res://props/rocks/rock_material.tres")
				item.set_mesh(cone, 0)
				item.generator = instance_generator
				item.persistent = true
				item.lod_index = 0
				item.name = "stalactite"
				library.add_item(3, item)

				instancer.library = library

				volume.add_child(instancer)
				body.instancer = instancer

		if body.sea:
			var sea_mesh := SphereMesh.new()
			sea_mesh.radius = body.radius * 0.985
			sea_mesh.height = 2.0 * sea_mesh.radius
			var sea_mesh_instance = MeshInstance.new()
			sea_mesh_instance.mesh = sea_mesh
			sea_mesh_instance.material_override = WaterSeaMaterial
			root.add_child(sea_mesh_instance)
		
		if body.type != StellarBody.TYPE_SUN:
			var atmo = VolumetricAtmosphereScene.instance()
			#atmo.scale = Vector3(1, 1, 1) * (0.99 * body.radius)
			atmo.planet_radius = body.radius * 1.03
			atmo.atmosphere_height = 175.0#0.12 * body.radius
			atmo.sun_path = "/root/GameWorld/Sun/DirectionalLight"
			#atmo.day_color = body.atmosphere_color
			#atmo.night_color = body.atmosphere_color.darkened(0.8)
			atmo.set_shader_param("u_density", 0.001)
			atmo.set_shader_param("u_attenuation_distance", 50.0)
			atmo.set_shader_param("u_day_color0", body.atmosphere_color)
			atmo.set_shader_param("u_day_color1", 
				body.atmosphere_color.linear_interpolate(Color(1,1,1), 0.5))
			atmo.set_shader_param("u_night_color0", body.atmosphere_color.darkened(0.8))
			atmo.set_shader_param("u_night_color1", 
				body.atmosphere_color.darkened(0.8).linear_interpolate(Color(1,1,1), 0.0))
			root.add_child(atmo)

	sun.node.add_child(_directional_light)

	# Spawn player
	_mouse_capture.capture()
	# Camera must process before the ship so we have to spawn it before...
	var camera = CameraScene.instance()
	camera.auto_find_camera_anchor = true
	add_child(camera)
	_ship = ShipScene.instance()
	_ship.global_transform = _spawn_point.global_transform
	add_child(_ship)
	camera.set_target(_ship)
	_hud.show()
	
	set_physics_process(true)

	progress_info.finished = true
	emit_signal("loading_progressed", progress_info)


func _physics_process(delta: float):
	# Check when to change referential.
	# Only do so after a few frames elapsed from the last change, because in Godot,
	# physics are deferred in shitty ways even if we presently are in _physics_process
	if _physics_count > 0 and _physics_count - _physics_count_on_last_reference_change > 10:
		if _reference_body_id == 0:
			for i in len(_bodies):
				var body : StellarBody = _bodies[i]
				if body.type == StellarBody.TYPE_SUN:
					# Ignore sun, no point landing there
					continue
				var body_pos = body.node.global_transform.origin
				var d = body_pos.distance_to(_ship.global_transform.origin)
				if d < BODY_REFERENCE_ENTRY_RADIUS_FACTOR * body.radius:
					print("Close to ", body.name, " which is at ", body_pos)
					set_reference_body(i)
					break
		else:
			var ref_body = _bodies[_reference_body_id]
			var body_pos = ref_body.node.global_transform.origin
			var d = body_pos.distance_to(_ship.global_transform.origin)
			if d > BODY_REFERENCE_EXIT_RADIUS_FACTOR * ref_body.radius:
				set_reference_body(0)
	
	# Calculate current referential transform
	var ref_trans_inverse = Transform()
	if _reference_body_id != 0:
		var ref_body = _bodies[_reference_body_id]
		var ref_trans = _compute_absolute_body_transform(ref_body)
		ref_trans_inverse = ref_trans.affine_inverse()

	# Simulate orbits
	for i in len(_bodies):
		var body : StellarBody = _bodies[i]
		
		if body.self_revolution_time > 0:
			body.self_revolution_progress += delta / body.self_revolution_time
			if body.self_revolution_progress >= 1.0:
				body.self_revolution_progress -= 1.0
				body.day_count += 1
		
		if body.orbit_revolution_time > 0:
			body.orbit_revolution_progress += delta / body.orbit_revolution_time
			if body.orbit_revolution_progress >= 1.0:
				body.orbit_revolution_progress -= 1.0
				body.year_count += 1
		
		if _reference_body_id == i:
			# Don't touch the reference body
			continue
		
		var trans = _compute_absolute_body_transform(body)
		
		if _reference_body_id != 0:
			trans = ref_trans_inverse * trans
		
		body.node.transform = trans
	
	# Update directional light. Smoke and mirrors here
	var camera : Camera = get_viewport().get_camera()
	if camera != null:
		var pos = camera.global_transform.origin
		pos.y = 0.0
		if pos != _directional_light.global_transform.origin:
			_directional_light.look_at(pos, Vector3(0, 1, 0))
	
	# Update sky rotation
	if _reference_body_id != 0:
		_environment.background_sky_orientation = ref_trans_inverse.basis
	else:
		_environment.background_sky_orientation = Basis()
	
	if len(_bodies) > 0:
		DDD.set_text("Reference body", _bodies[_reference_body_id].name)
	_physics_count += 1

	# DEBUG
	for i in len(_bodies):
		var body : StellarBody = _bodies[i]
		if body.volume == null:
			continue
		var s = str(
			"D: ", body.volume.debug_get_data_block_count(), ", ", 
			"M: ", body.volume.debug_get_mesh_block_count())
		if body.instancer != null:
			s += str("| I: ", body.instancer.debug_get_block_count())
		DDD.set_text(str("Blocks in ", body.name), s)
		#var stats = body.volume.get_statistics()
		#for k in stats:
		#	if k.begins_with("time_"):
		#		var t = stats[k]
		#		if t > 8000:
		#			DDD.set_text(str("!! ", body.name, " ", k), t)
		#if stats.blocked_lods > 0:
		#	DDD.set_text(str("!! blocked lods on ", body.name), stats.blocked_lods)


func set_reference_body(ref_id: int):
	if _reference_body_id == ref_id:
		return
	
	var previous_body = _bodies[_reference_body_id]
	for sb in previous_body.static_bodies:
		sb.get_parent().remove_child(sb)
	previous_body.static_bodies_are_in_tree = false
	
	_reference_body_id = ref_id
	var body = _bodies[_reference_body_id]
	print("Setting reference to ", ref_id, " (", body.name, ")")
	var trans = body.node.transform
	body.node.transform = Transform()
	
	var info := ReferenceChangeInfo.new()
	# TODO Also have relative velocity of the body,
	# so the ship can integrate it so it looks seamless
	info.inverse_transform = trans.affine_inverse() * body.node.transform
	_physics_count_on_last_reference_change = _physics_count
	
	for sb in body.static_bodies:
		body.node.add_child(sb)
	body.static_bodies_are_in_tree = true

	_directional_light.shadow_color = body.atmosphere_color.darkened(0.8)
	var environment = get_viewport().world.environment
	environment.ambient_light_color = body.atmosphere_color
	environment.ambient_light_energy = 20
	
	emit_signal("reference_body_changed", info)


func _compute_absolute_body_transform(body: StellarBody) -> Transform:
	if body.parent_id == -1:
		# Sun
		return Transform()
	var parent_transform := Transform()
	if body.parent_id != -1:
		var parent_body = _bodies[body.parent_id]
		parent_transform = _compute_absolute_body_transform(parent_body)
	var orbit_angle := body.orbit_revolution_progress * TAU
	# TODO Elliptic orbits
	var pos := Vector3(cos(orbit_angle), 0, sin(orbit_angle)) * body.distance_to_parent
	pos = pos.rotated(Vector3(0, 0, 1), body.orbit_tilt)
	var self_angle := body.self_revolution_progress * TAU
	var basis := Basis(Vector3(0, self_angle, body.self_tilt))
	var local_transform := Transform(basis, pos)
	return parent_transform * local_transform


func get_stellar_body_count() -> int:
	return len(_bodies)


func get_stellar_body(idx: int) -> StellarBody:
	return _bodies[idx]


func get_reference_stellar_body() -> StellarBody:
	return _bodies[_reference_body_id]


func _notification(what: int):
	match what:
		NOTIFICATION_WM_QUIT_REQUEST:
			# Save game when the user closes the window
			_save_world()


func _save_world():
	print("Saving world")
	for body in _bodies:
		if body.volume != null:
			body.volume.save_modified_blocks()

