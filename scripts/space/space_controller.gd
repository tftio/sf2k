extends Node3D
## Controls the 3D space navigation scene.
##
## Manages the player ship, star system nodes, camera, and travel between
## systems. Uses floating origin to handle large coordinate spaces.

## Emitted when the player arrives at a star system.
signal arrived_at_system(system_index: int)
## Emitted when the player initiates travel to a system.
signal travel_started(from_index: int, to_index: int)

## Speed of ship travel (units per second).
@export var travel_speed: float = 50.0
## Camera distance behind/above the ship.
@export var camera_offset: Vector3 = Vector3(0.0, 30.0, 50.0)
## Floating origin threshold -- rebase coordinates when ship exceeds this.
@export var origin_threshold: float = 200.0

## References set up in _ready from the scene tree.
@onready var _camera: Camera3D = $Camera3D
@onready var _ship: Node3D = $PlayerShip
@onready var _starfield: Node3D = $Starfield

## All generated star system data.
var _star_systems: Array[StarSystemData] = []
## Nodes representing visible star systems in the 3D scene.
var _system_nodes: Array[Node3D] = []
## Accumulated origin offset for floating origin.
var _origin_offset: Vector3 = Vector3.ZERO

## Travel state.
var _travel_target_index: int = -1
var _travel_target_pos: Vector3 = Vector3.ZERO
var _is_traveling: bool = false


func _ready() -> void:
	_generate_galaxy()
	_spawn_system_nodes()
	_position_ship_at_current_system()


func _process(delta: float) -> void:
	if _is_traveling:
		_process_travel(delta)
	_update_camera()
	# Keep starfield centered on camera
	if _starfield and _camera:
		_starfield.follow_camera(_camera.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(event.position)


## Generate all star systems from the galaxy seed.
func _generate_galaxy() -> void:
	_star_systems.clear()
	for i: int in range(GameState.GALAXY_SIZE):
		var system: StarSystemData = StarSystemData.generate(GameState.galaxy_seed, i)
		_star_systems.append(system)


## Create 3D nodes for each star system.
func _spawn_system_nodes() -> void:
	# Clear existing
	for node: Node3D in _system_nodes:
		node.queue_free()
	_system_nodes.clear()

	for system: StarSystemData in _star_systems:
		var node := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		node.mesh = sphere

		# Color by star type
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = system.get_star_color()
		node.material_override = mat

		# Position relative to floating origin
		node.position = system.position - _origin_offset
		node.name = "Star_%d" % system.index

		# Store system index in metadata for click detection
		node.set_meta("system_index", system.index)

		add_child(node)
		_system_nodes.append(node)


## Place the ship at the current star system.
func _position_ship_at_current_system() -> void:
	if GameState.current_system_index >= 0 and GameState.current_system_index < _star_systems.size():
		var system: StarSystemData = _star_systems[GameState.current_system_index]
		_ship.position = system.position - _origin_offset
		GameState.ship_position = system.position


## Begin traveling to a target star system.
func travel_to_system(target_index: int) -> void:
	if _is_traveling:
		return
	if target_index < 0 or target_index >= _star_systems.size():
		return
	if target_index == GameState.current_system_index:
		return

	var target_system: StarSystemData = _star_systems[target_index]
	var distance: float = (target_system.position - GameState.ship_position).length()

	# Check fuel
	if not GameState.consume_fuel(distance):
		return

	_travel_target_index = target_index
	_travel_target_pos = target_system.position - _origin_offset
	_is_traveling = true
	GameState.is_traveling = true
	travel_started.emit(GameState.current_system_index, target_index)


## Process ship movement toward target during travel.
func _process_travel(delta: float) -> void:
	var direction: Vector3 = (_travel_target_pos - _ship.position).normalized()
	var step: float = travel_speed * delta
	var remaining: float = _ship.position.distance_to(_travel_target_pos)

	if step >= remaining:
		# Arrived
		_ship.position = _travel_target_pos
		_is_traveling = false
		GameState.is_traveling = false
		GameState.current_system_index = _travel_target_index
		GameState.ship_position = _star_systems[_travel_target_index].position
		GameState.discover_system(_travel_target_index)
		arrived_at_system.emit(_travel_target_index)
		_check_floating_origin()
	else:
		_ship.position += direction * step
		GameState.ship_position = _ship.position + _origin_offset


## Rebase the coordinate system if the ship is too far from the origin.
func _check_floating_origin() -> void:
	if _ship.position.length() > origin_threshold:
		var shift: Vector3 = _ship.position
		_origin_offset += shift
		_ship.position = Vector3.ZERO

		# Shift all system nodes
		for i: int in range(_system_nodes.size()):
			_system_nodes[i].position = _star_systems[i].position - _origin_offset


## Smooth camera follow.
func _update_camera() -> void:
	if _camera and _ship:
		var target_pos: Vector3 = _ship.position + camera_offset
		_camera.position = _camera.position.lerp(target_pos, 0.05)
		_camera.look_at(_ship.position, Vector3.UP)


## Handle mouse click for selecting star systems.
func _handle_click(screen_pos: Vector2) -> void:
	if _is_traveling:
		return
	if _camera == null:
		return

	# Raycast from camera through click point
	var from: Vector3 = _camera.project_ray_origin(screen_pos)
	var direction: Vector3 = _camera.project_ray_normal(screen_pos)

	# Find closest system to the ray
	var best_index: int = -1
	var best_dist: float = 5.0  # Max click distance threshold

	for i: int in range(_system_nodes.size()):
		var node: Node3D = _system_nodes[i]
		var to_node: Vector3 = node.position - from
		var proj: float = to_node.dot(direction)
		if proj < 0.0:
			continue
		var closest_on_ray: Vector3 = from + direction * proj
		var dist: float = closest_on_ray.distance_to(node.position)
		if dist < best_dist:
			best_dist = dist
			best_index = i

	if best_index >= 0:
		travel_to_system(best_index)


## Get the StarSystemData for a given index.
func get_system_data(index: int) -> StarSystemData:
	if index >= 0 and index < _star_systems.size():
		return _star_systems[index]
	return null


## Get all star systems (for star map UI).
func get_all_systems() -> Array[StarSystemData]:
	return _star_systems
