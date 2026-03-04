extends Node3D
## Procedural starfield background for the 3D space scene.
##
## Generates a sphere of distant "background" stars as a particle-like effect
## using MultiMeshInstance3D for performance. These are purely visual and not
## interactable -- they represent the distant galaxy backdrop.

## Number of background stars to render.
@export var star_count: int = 2000
## Radius of the starfield sphere around the camera.
@export var sphere_radius: float = 1000.0
## Base size of star points.
@export var star_size: float = 0.5

## The MultiMeshInstance3D used to render background stars.
var _multi_mesh_instance: MultiMeshInstance3D = null


func _ready() -> void:
	_generate_starfield()


## Build the starfield MultiMesh with randomly placed points on a sphere.
func _generate_starfield() -> void:
	# Create mesh for individual star (small quad billboard)
	var quad := QuadMesh.new()
	quad.size = Vector2(star_size, star_size)

	# Material: unshaded, billboard, vertex-colored
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat

	# Create MultiMesh
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.mesh = quad
	multi_mesh.instance_count = star_count

	# Distribute stars on a sphere with varying brightness
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # Fixed seed for consistent background

	for i: int in range(star_count):
		# Random point on sphere surface
		var theta: float = rng.randf() * TAU
		var phi: float = acos(2.0 * rng.randf() - 1.0)
		var r: float = sphere_radius * (0.8 + rng.randf() * 0.2)

		var pos := Vector3(
			r * sin(phi) * cos(theta),
			r * sin(phi) * sin(theta),
			r * cos(phi),
		)

		var xform := Transform3D()
		xform.origin = pos
		# Random size variation
		var s: float = star_size * rng.randf_range(0.3, 1.5)
		xform = xform.scaled_local(Vector3(s, s, s))
		multi_mesh.set_instance_transform(i, xform)

		# Color: mostly white/blue with some warm stars
		var brightness: float = rng.randf_range(0.3, 1.0)
		var color_roll: float = rng.randf()
		var star_color: Color
		if color_roll < 0.6:
			star_color = Color(brightness, brightness, brightness * 1.1, brightness)
		elif color_roll < 0.8:
			star_color = Color(brightness * 0.8, brightness * 0.85, brightness, brightness)
		else:
			star_color = Color(brightness, brightness * 0.8, brightness * 0.6, brightness)
		multi_mesh.set_instance_color(i, star_color)

	# Create the instance node
	_multi_mesh_instance = MultiMeshInstance3D.new()
	_multi_mesh_instance.multimesh = multi_mesh
	add_child(_multi_mesh_instance)


## Reposition the starfield to follow the camera (infinite background effect).
func follow_camera(camera_pos: Vector3) -> void:
	if _multi_mesh_instance:
		_multi_mesh_instance.global_position = camera_pos
