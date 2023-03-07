
const StellarBody = preload("./stellar_body.gd")
const Settings = preload("res://settings.gd")

const VolumetricAtmosphereScene = preload("res://addons/zylann.atmosphere/planet_atmosphere.tscn")
const BigRock1Scene = preload("../props/big_rocks/big_rock1.tscn")
const Rock1Scene = preload("../props/rocks/rock1.tscn")
const GrassScene = preload("res://props/grass/grass.tscn")

const SunMaterial = preload("./materials/sun_yellow.tres")
const PlanetRockyMaterial = preload("./materials/planet_material_rocky.tres")
const PlanetGrassyMaterial = preload("./materials/planet_material_grassy.tres")
const WaterSeaMaterial = preload("./materials/water_sea_material.tres")
const RockMaterial = preload("res://props/rocks/rock_material.tres")

const Pebble1Mesh = preload("res://props/pebbles/pebble1.obj")
const Rock1Mesh = preload("res://props/rocks/rock1.obj")
const BigRock1Mesh = preload("res://props/big_rocks/big_rock1.obj")

const BasePlanetVoxelGraph = preload("./voxel_graph_planet_v4.tres")

const EarthDaySound = preload("res://sounds/earth_surface_day.ogg")
const EarthNightSound = preload("res://sounds/earth_surface_night.ogg")
const WindSound = preload("res://sounds/wind.ogg")

const SAVE_FOLDER_PATH = "debug_data"
const LARGE_SCALE = 10.0


static func create_solar_system_data(settings: Settings) -> Array:
	var bodies = []
	
	var sun = StellarBody.new()
	sun.type = StellarBody.TYPE_SUN
	sun.radius = 2000.0
	sun.self_revolution_time = 60.0
	sun.orbit_revolution_time = 60.0
	sun.name = "Sun"
	bodies.append(sun)
	
	var planet = StellarBody.new()
	planet.name = "Mercury"
	planet.type = StellarBody.TYPE_ROCKY
	planet.radius = 900.0
	planet.parent_id = 0
	planet.distance_to_parent = 14400.0
	planet.self_revolution_time = 10.0 * 60.0
	planet.orbit_revolution_time = 50.0 * 60.0
	planet.atmosphere_color = Color(1.0, 0.4, 0.1)
	planet.orbit_revolution_progress = -0.1
	planet.day_ambient_sound = WindSound
	bodies.append(planet)

	planet = StellarBody.new()
	planet.name = "Earth"
	planet.type = StellarBody.TYPE_ROCKY
	planet.radius = 1800.0
	planet.parent_id = 0
	planet.distance_to_parent = 25600.0
	planet.self_revolution_time = 10.0 * 60.0
	planet.orbit_revolution_time = 150.0 * 60.0
	planet.atmosphere_color = Color(0.3, 0.5, 1.0)
	planet.orbit_revolution_progress = 0.0
	planet.day_ambient_sound = EarthDaySound
	planet.night_ambient_sound = EarthNightSound
	planet.sea = true
	var earth_id = len(bodies)
	bodies.append(planet)

	planet = StellarBody.new()
	planet.name = "Moon"
	planet.type = StellarBody.TYPE_ROCKY
	planet.radius = 600.0
	planet.parent_id = earth_id
	# The moon should not be too close, otherwise referential change
	# will overlap and physics will break. Every planet is a static body
	# and only the reference one is not moving, so it's a problem is the
	# moon is still moving while we reach it.
	planet.distance_to_parent = 7500.0
	planet.self_revolution_time = 10.0 * 60.0
	planet.orbit_revolution_time = 10.0 * 60.0
	planet.atmosphere_color = Color(0.2, 0.2, 0.2)
	planet.orbit_revolution_progress = 0.25
	planet.day_ambient_sound = WindSound
	bodies.append(planet)

	planet = StellarBody.new()
	planet.name = "Mars"
	planet.type = StellarBody.TYPE_ROCKY
	planet.radius = 1280.0
	planet.parent_id = 0
	planet.distance_to_parent = 48000.0
	planet.self_revolution_time = 10.0 * 60.0
	planet.orbit_revolution_time = 100.0 * 60.0
	planet.atmosphere_color = Color(1.2, 0.8, 0.5)
	planet.orbit_revolution_progress = 0.1
	planet.day_ambient_sound = WindSound
	bodies.append(planet)

	planet = StellarBody.new()
	planet.name = "Jupiter"
	planet.type = StellarBody.TYPE_GAS
	planet.radius = 3000.0
	planet.parent_id = 0
	planet.distance_to_parent = 70400.0
	planet.self_revolution_time = 8.0 * 60.0
	planet.orbit_revolution_time = 300.0 * 60.0
	planet.atmosphere_color = Color(0.8, 0.6, 0.4)
	planet.day_ambient_sound = WindSound
	bodies.append(planet)
	
	var scale = 1.0
	if settings.world_scale_x10:
		scale = LARGE_SCALE

	for body in bodies:
		body.radius *= scale
		var speed = body.distance_to_parent * TAU / body.orbit_revolution_time
		body.distance_to_parent *= scale
		body.orbit_revolution_time = body.distance_to_parent * TAU / speed
	
	return bodies


static func _setup_sun(body: StellarBody, root: Node3D) -> DirectionalLight3D:
	var mi = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = body.radius
	mesh.height = 2.0 * mesh.radius
	mi.mesh = mesh
	mi.material_override = SunMaterial
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	
	var directional_light := DirectionalLight3D.new()
	directional_light.shadow_enabled = true
	# The environment in this game is a space background so it's very dark. Sky is actually a post
	# effect because you can fly out and it's a planet... And still you can also have shadows while
	# in your ship!
	directional_light.shadow_opacity = 0.9
	directional_light.shadow_normal_bias = 0.2
	directional_light.directional_shadow_split_1 = 0.1
	directional_light.directional_shadow_split_2 = 0.2
	directional_light.directional_shadow_split_3 = 0.5
	directional_light.directional_shadow_blend_splits = true
	directional_light.directional_shadow_max_distance = 20000.0
	directional_light.name = "DirectionalLight"
	body.node.add_child(directional_light)
	
	return directional_light


static func _setup_atmosphere(body: StellarBody, root: Node3D, settings: Settings):
	var atmo = VolumetricAtmosphereScene.instantiate()
	#atmo.scale = Vector3(1, 1, 1) * (0.99 * body.radius)
	if settings.world_scale_x10:
		atmo.planet_radius = body.radius * 1.0
		atmo.atmosphere_height = 125.0 * LARGE_SCALE
	else:
		atmo.planet_radius = body.radius * 1.03
		atmo.atmosphere_height = 0.12 * body.radius
	# TODO This is kinda bad to hardcode the path, need to find another robust way
	atmo.sun_path = "/root/Main/GameWorld/Sun/DirectionalLight"
	#atmo.day_color = body.atmosphere_color
	#atmo.night_color = body.atmosphere_color.darkened(0.8)
	var atmo_density = 0.001
	if body.type == StellarBody.TYPE_GAS:
		if settings.world_scale_x10:
			# TODO Need to investigate this, atmosphere currently blows up HDR when large and dense
			atmo_density /= LARGE_SCALE
	atmo.set_shader_param("u_density", atmo_density)
	atmo.set_shader_param("u_attenuation_distance", 50.0)
	atmo.set_shader_param("u_day_color0", body.atmosphere_color)
	atmo.set_shader_param("u_day_color1", 
		body.atmosphere_color.lerp(Color(1,1,1), 0.5))
	atmo.set_shader_param("u_night_color0", body.atmosphere_color.darkened(0.8))
	atmo.set_shader_param("u_night_color1", 
		body.atmosphere_color.darkened(0.8).lerp(Color(1,1,1), 0.0))
	body.atmosphere = atmo
	root.add_child(atmo)


static func _setup_sea(body: StellarBody, root: Node3D):
	var sea_mesh := SphereMesh.new()
	sea_mesh.radius = body.radius * 0.985
	sea_mesh.height = 2.0 * sea_mesh.radius
	var sea_mesh_instance = MeshInstance3D.new()
	sea_mesh_instance.mesh = sea_mesh
	sea_mesh_instance.material_override = WaterSeaMaterial
	root.add_child(sea_mesh_instance)


static func _setup_rocky_planet(body: StellarBody, root: Node3D, settings: Settings):
	var mat : ShaderMaterial
	# TODO Dont hardcode this
	if body.name == "Earth":
		mat = PlanetGrassyMaterial.duplicate()
	else:
		mat = PlanetRockyMaterial.duplicate()
	mat.set_shader_parameter("u_mountain_height", body.radius + 80.0)
	
	var generator : VoxelGeneratorGraph = BasePlanetVoxelGraph.duplicate(true)
	var graph : VoxelGraphFunction = generator.get_main_function()
	var sphere_node_id := graph.find_node_by_name("sphere")
	# TODO Need an API that doesnt suck
	var radius_param_id := 0
	graph.set_node_param(sphere_node_id, radius_param_id, body.radius)
	var ravine_blend_noise_node_id := graph.find_node_by_name("ravine_blend_noise")
	var noise_param_id := 0
	var ravine_blend_noise = graph.get_node_param(ravine_blend_noise_node_id, noise_param_id)
	ravine_blend_noise.seed = body.name.hash()
	var cave_height_node_id := graph.find_node_by_name("cave_height_subtract")
	graph.set_node_default_input(cave_height_node_id, 1, body.radius - 100.0)
	var cave_noise_node_id := graph.find_node_by_name("cave_noise")
	var cave_noise = graph.get_node_param(cave_noise_node_id, noise_param_id)
	cave_noise.period = 900.0 / body.radius
	var ravine_depth_multiplier_node_id := graph.find_node_by_name("ravine_depth_multiplier")
	var ravine_depth = graph.get_node_default_input(ravine_depth_multiplier_node_id, 1)
	if settings.world_scale_x10:
		ravine_depth *= LARGE_SCALE
	graph.set_node_default_input(ravine_depth_multiplier_node_id, 1, ravine_depth)
	# var cave_height_multiplier_node_id = generator.find_node_by_name("cave_height_multiplier")
	# generator.set_node_default_input(cave_height_multiplier_node_id, 1, 0.015)
	generator.compile()

	generator.use_subdivision = true
	generator.subdivision_size = 8
	#generator.sdf_clip_threshold = 10.0
	generator.use_optimized_execution_map = true

	# ResourceSaver.save(generator, str("debug_data/generator_", body.name, ".tres"),
	# 			ResourceSaver.FLAG_BUNDLE_RESOURCES)

	#var sphere_normalmap = Image.new()
	#sphere_normalmap.create(512, 256, false, Image.FORMAT_RGB8)
	#generator.bake_sphere_normalmap(sphere_normalmap, body.radius * 0.95, 200.0 / body.radius)
	#sphere_normalmap.save_png(str("debug_data/test_sphere_normalmap_", body.name, ".png"))
	#var sphere_normalmap_tex = ImageTexture.create_from_image(sphere_normalmap)
	#mat.set_shader_parameter("u_global_normalmap", sphere_normalmap_tex)

	var stream = VoxelStreamSQLite.new()
	stream.database_path = str(SAVE_FOLDER_PATH, "/", body.name, ".sqlite")

	var extra_lods = 0
	if settings.world_scale_x10:
		var temp = int(LARGE_SCALE)
		while temp > 1:
			extra_lods += 1
			temp /= 2

	var pot = 1024
	while body.radius >= pot:
		pot *= 2

	var volume := VoxelLodTerrain.new()
	volume.lod_count = 7 + extra_lods
	volume.lod_distance = 60.0
	volume.collision_lod_count = 2
	volume.generator = generator
	volume.stream = stream
	var view_distance = 100000
	if settings.world_scale_x10:
		view_distance *= LARGE_SCALE
	volume.view_distance = view_distance
	volume.voxel_bounds = AABB(Vector3(-pot, -pot, -pot), Vector3(2 * pot, 2 * pot, 2 * pot))
	volume.lod_fade_duration = 0.3
	volume.threaded_update_enabled = true
	# Keep all edited blocks loaded. Leaving this off enables data streaming, but it is slower
	volume.full_load_mode_enabled = true
	
	volume.normalmap_enabled = true
	volume.normalmap_tile_resolution_min = 4
	volume.normalmap_tile_resolution_max = 8
	volume.normalmap_begin_lod_index = 2
	volume.normalmap_max_deviation_degrees = 50
	volume.normalmap_octahedral_encoding_enabled = false
	volume.normalmap_use_gpu = true

	volume.material = mat
	# TODO Set before setting voxel bounds?
	volume.mesh_block_size = 32

	volume.mesher = VoxelMesherTransvoxel.new()
	#volume.mesher.mesh_optimization_enabled = true
	volume.mesher.mesh_optimization_error_threshold = 0.0025
	#volume.set_process_mode(VoxelLodTerrain.PROCESS_MODE_PHYSICS)
	body.volume = volume
	root.add_child(volume)

	_configure_instancing_for_planet(body, volume)


static func _configure_instancing_for_planet(body: StellarBody, volume: VoxelLodTerrain):
	for mesh in [Pebble1Mesh, Rock1Mesh, BigRock1Mesh]:
		mesh.surface_set_material(0, RockMaterial)

	var instancer = VoxelInstancer.new()
	instancer.set_up_mode(VoxelInstancer.UP_MODE_SPHERE)

	var library = VoxelInstanceLibrary.new()
	# Usually most of this is done in editor, but some features can only be setup by code atm.
	# Also if we want to procedurally-generate some of this, we may need code anyways.

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
	instance_generator.noise.frequency = 1.0 / 16.0
	instance_generator.noise.fractal_octaves = 2
	instance_generator.noise_on_scale = 1
	#instance_generator.noise.noise_type = FastNoiseLite.TYPE_PERLIN
	var item = VoxelInstanceLibraryMultiMeshItem.new()
	
	if body.name == "Earth":
		var grass_mesh = GrassScene.instantiate()
		item.setup_from_template(grass_mesh)
		grass_mesh.free()

		#instance_generator.density = 0.32
		instance_generator.density = 2.0
		instance_generator.min_scale = 0.8
		instance_generator.max_scale = 1.6
		instance_generator.random_vertical_flip = false
		instance_generator.max_slope_degrees = 30

		item.name = "grass"
		
	else:
		item.set_mesh(Pebble1Mesh, 0)
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
	item = VoxelInstanceLibraryMultiMeshItem.new()
	var rock1_template = Rock1Scene.instantiate()
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
	item = VoxelInstanceLibraryMultiMeshItem.new()
	item.set_mesh(BigRock1Mesh, 0)
	item.generator = instance_generator
	item.persistent = true
	item.lod_index = 3
	item.name = "big_rock"
	library.add_item(1, item)

	instance_generator = VoxelInstanceGenerator.new()
	instance_generator.noise = FastNoiseLite.new()
	instance_generator.noise.frequency = 1.0 / 16.0
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
	item = VoxelInstanceLibraryMultiMeshItem.new()
	var cone = CylinderMesh.new()
	cone.radial_segments = 8
	cone.rings = 0
	cone.top_radius = 0.5
	cone.bottom_radius = 0.1
	cone.height = 2.5
	cone.material = RockMaterial
	item.set_mesh(cone, 0)
	item.generator = instance_generator
	item.persistent = true
	item.lod_index = 0
	item.name = "stalactite"
	library.add_item(3, item)

	instancer.library = library

	volume.add_child(instancer)
	body.instancer = instancer


static func setup_stellar_body(body: StellarBody, parent: Node, 
	settings: Settings) -> DirectionalLight3D:
	
	var root := Node3D.new()
	root.name = body.name
	body.node = root
	parent.add_child(root)
	
	var sun_light : DirectionalLight3D = null

	if body.type == StellarBody.TYPE_SUN:
		sun_light = _setup_sun(body, root)
	
	elif body.type == StellarBody.TYPE_ROCKY:
		_setup_rocky_planet(body, root, settings)

	if body.sea:
		_setup_sea(body, root)
	
	if body.type != StellarBody.TYPE_SUN:
		_setup_atmosphere(body, root, settings)
	
	return sun_light

