@tool
extends Node

@export_range(0, 100) var flareStrength := 10.0:
	get:
		return flareStrength
	set(value):
		flareStrength = value
		material.set_shader_parameter('bloom_scale', value)


@export_range(0, 16) var flareBias := 1.05:
	get:
		return flareBias
	set(value):
		flareBias = value
		material.set_shader_parameter('bloom_bias', value)


@export_range(0, 10) var flareBlur := 2.0:
	get:
		return flareBlur
	set(value):
		flareBlur = value
		material.set_shader_parameter('lod', value)


@export_enum("Low", "Medium", "High") var distortionQuality := 0:
	get:
		return distortionQuality
	set(value):
		distortionQuality = value
		material.set_shader_parameter('distortion_quality', value)


@export_range(0, 50) var distortion := 2.0:
	get:
		return distortion
	set(value):
		distortion = value
		material.set_shader_parameter('distort', value)


@export_range(0, 100) var ghostCount := 7:
	get:
		return ghostCount
	set(value):
		ghostCount = value
		material.set_shader_parameter('ghosts', value)


@export_range(0, 1) var ghostSpacing := 0.3:
	get:
		return ghostSpacing
	set(value):
		ghostSpacing = value
		material.set_shader_parameter('ghost_dispersal', value)


@export_range(0, 1) var haloWidth := 0.25:
	get:
		return haloWidth
	set(value):
		haloWidth = value
		material.set_shader_parameter('halo_width', value)


@export var lensDirt : Texture2D = preload("lens-dirt-default.jpeg"):
	get:
		return lensDirt
	set(value):
		lensDirt = value
		material.set_shader_parameter('lens_dirt', value)


var screen : MeshInstance3D
var material : ShaderMaterial

func _init():
	screen = MeshInstance3D.new()
	screen.mesh = BoxMesh.new()
	screen.scale = Vector3(1,1,1) * pow(2.0,30);
	add_child(screen)
	screen.material_override = preload("lens-flare-shader.tres").duplicate()
	material = screen.material_override
