@tool
extends SpringArm3D
# Control the zoom of the camera with `zoom`, a value between 0 and 1

@export var length_range := Vector2(3.0, 6.0):
	get:
		return length_range
	set(value):
		# Ensures that each value is greater than 0, and that length_range.x <= length_range.y
		# Then updates the zoom
		value.x = max(value.x, 0.0)
		value.y = max(value.y, 0.0)
		length_range.x = min(value.x, value.y)
		length_range.y = max(value.x, value.y)
		self.zoom = zoom


@export var zoom := 0.5:
	get:
		return zoom
	set(value):
		assert(value >= 0.0 and value <= 1.0)
		zoom = value
		spring_length = lerp(length_range.y, length_range.x, zoom)


@onready var _position_start: Vector3 = position
