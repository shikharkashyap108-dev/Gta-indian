extends Node3D

const AREA_SIZE: float = 100.0
const ROAD_LENGTH: float = 88.0
const ROAD_WIDTH: float = 12.0
const SIDEWALK_WIDTH: float = 3.0
const BUILDING_WIDTH: float = 12.0
const BUILDING_DEPTH: float = 12.0
const BUILDING_HEIGHT: float = 9.0

var _ground_material: StandardMaterial3D
var _asphalt_material: StandardMaterial3D
var _sidewalk_material: StandardMaterial3D
var _lane_material: StandardMaterial3D
var _crosswalk_material: StandardMaterial3D
var _window_material: StandardMaterial3D
var _trim_material: StandardMaterial3D
var _bark_material: StandardMaterial3D
var _leaf_material: StandardMaterial3D
var _lamp_material: StandardMaterial3D
var _building_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	_create_materials()
	_build_ground_and_roads()
	_build_road_markings()
	_build_buildings()
	_build_trees()
	_build_streetlights()

func _create_materials() -> void:
	_ground_material = _make_noise_material(Color(0.25, 0.29, 0.22), 1021, 128)
	_asphalt_material = _make_noise_material(Color(0.31, 0.33, 0.34), 2063, 128)
	_sidewalk_material = _make_noise_material(Color(0.55, 0.54, 0.49), 3067, 128)
	_lane_material = _make_solid_material(Color(0.92, 0.72, 0.3), 0.8)
	_crosswalk_material = _make_solid_material(Color(0.88, 0.87, 0.81), 0.82)
	_window_material = _make_solid_material(Color(0.12, 0.2, 0.25), 0.28)
	_trim_material = _make_solid_material(Color(0.79, 0.74, 0.64), 0.78)
	_bark_material = _make_solid_material(Color(0.25, 0.16, 0.1), 0.95)
	_leaf_material = _make_solid_material(Color(0.2, 0.34, 0.19), 0.92)
	_lamp_material = _make_solid_material(Color(0.95, 0.79, 0.46), 0.3)
	_lamp_material.emission_enabled = true
	_lamp_material.emission = Color(0.9, 0.54, 0.22)

	_building_materials.append(_make_solid_material(Color(0.58, 0.43, 0.31), 0.9))
	_building_materials.append(_make_solid_material(Color(0.57, 0.58, 0.54), 0.9))
	_building_materials.append(_make_solid_material(Color(0.48, 0.34, 0.29), 0.9))
	_building_materials.append(_make_solid_material(Color(0.68, 0.61, 0.48), 0.9))

func _make_noise_material(base_color: Color, seed_value: int, texture_size: int) -> StandardMaterial3D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.07
	noise.fractal_octaves = 2

	var color_ramp: Gradient = Gradient.new()
	color_ramp.offsets = PackedFloat32Array([0.0, 1.0])
	color_ramp.colors = PackedColorArray([
		base_color.darkened(0.12),
		base_color.lightened(0.12)
	])

	var noise_texture: NoiseTexture2D = NoiseTexture2D.new()
	noise_texture.width = texture_size
	noise_texture.height = texture_size
	noise_texture.seamless = true
	noise_texture.noise = noise
	noise_texture.color_ramp = color_ramp

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = noise_texture
	material.roughness = 0.94
	material.uv1_scale = Vector3(12.0, 12.0, 1.0)
	return material

func _make_solid_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _build_ground_and_roads() -> void:
	_add_box_body(
		"Ground",
		Vector3(AREA_SIZE, 0.2, AREA_SIZE),
		Vector3(0.0, -0.1, 0.0),
		_ground_material
	)
	_add_box_body(
		"MainRoad",
		Vector3(ROAD_WIDTH, 0.12, ROAD_LENGTH),
		Vector3(0.0, -0.02, 0.0),
		_asphalt_material
	)
	_add_box_body(
		"CrossRoad",
		Vector3(AREA_SIZE, 0.12, ROAD_WIDTH),
		Vector3(0.0, -0.02, -5.0),
		_asphalt_material
	)

	var sidewalk_offset: float = ROAD_WIDTH * 0.5 + SIDEWALK_WIDTH * 0.5
	for side in [-1, 1]:
		_add_box_body(
			"Sidewalk_%d" % side,
			Vector3(SIDEWALK_WIDTH, 0.12, ROAD_LENGTH),
			Vector3(float(side) * sidewalk_offset, -0.02, 0.0),
			_sidewalk_material
		)
		_add_box_body(
			"CrossSidewalk_%d" % side,
			Vector3(AREA_SIZE, 0.12, SIDEWALK_WIDTH),
			Vector3(0.0, -0.02, -5.0 + float(side) * sidewalk_offset),
			_sidewalk_material
		)

func _build_road_markings() -> void:
	for mark_index in range(12):
		var mark_z: float = -40.0 + float(mark_index) * 7.0
		_add_visual_box(
			"CenterLine_%02d" % mark_index,
			Vector3(0.12, 0.015, 3.2),
			Vector3(0.0, 0.05, mark_z),
			_lane_material
		)

	for stripe_index in range(9):
		var stripe_x: float = -4.8 + float(stripe_index) * 1.2
		_add_visual_box(
			"Crosswalk_%02d" % stripe_index,
			Vector3(0.82, 0.016, 0.34),
			Vector3(stripe_x, 0.052, -5.0),
			_crosswalk_material
		)

	for side in [-1, 1]:
		var edge_x: float = float(side) * (ROAD_WIDTH * 0.5 - 0.25)
		_add_visual_box(
			"EdgeLine_%d" % side,
			Vector3(0.08, 0.014, ROAD_LENGTH - 2.0),
			Vector3(edge_x, 0.05, 0.0),
			_lane_material
		)

func _build_buildings() -> void:
	var building_z_positions: Array[float] = [-33.0, -12.0, 12.0, 33.0]
	for side in [-1, 1]:
		for building_index in range(building_z_positions.size()):
			var center_x: float = float(side) * 19.0
			var center_z: float = building_z_positions[building_index]
			var material: StandardMaterial3D = _building_materials[
				building_index % _building_materials.size()
			]
			_add_box_body(
				"Building_%d_%d" % [side, building_index],
				Vector3(BUILDING_WIDTH, BUILDING_HEIGHT, BUILDING_DEPTH),
				Vector3(center_x, BUILDING_HEIGHT * 0.5, center_z),
				material
			)
			_add_building_facade(side, center_x, center_z)

func _add_building_facade(side: int, center_x: float, center_z: float) -> void:
	var outward: float = -float(side)
	var facade_x: float = center_x - float(side) * BUILDING_WIDTH * 0.5
	facade_x += outward * 0.09
	var facade_length: float = BUILDING_DEPTH - 1.0

	_add_visual_box(
		"FacadeBand",
		Vector3(0.18, 0.28, facade_length),
		Vector3(facade_x, 0.32, center_z),
		_trim_material
	)
	for floor_index in range(2):
		var window_y: float = 2.5 + float(floor_index) * 3.0
		for window_index in range(3):
			var window_z: float = center_z - 3.6 + float(window_index) * 3.6
			_add_visual_box(
				"WindowFrame",
				Vector3(0.14, 1.55, 2.0),
				Vector3(facade_x, window_y, window_z),
				_trim_material
			)
			_add_visual_box(
				"WindowGlass",
				Vector3(0.16, 1.28, 1.7),
				Vector3(facade_x + outward * 0.025, window_y, window_z),
				_window_material
			)

	var door_z: float = center_z + 4.0
	_add_visual_box(
		"EntryDoor",
		Vector3(0.17, 2.1, 1.4),
		Vector3(facade_x + outward * 0.04, 1.1, door_z),
		_bark_material
	)
	_add_visual_box(
		"RoofCornice",
		Vector3(0.35, 0.35, BUILDING_DEPTH + 0.4),
		Vector3(facade_x - outward * 0.1, BUILDING_HEIGHT - 0.25, center_z),
		_trim_material
	)

func _build_trees() -> void:
	var tree_z_positions: Array[float] = [-34.0, -17.0, 2.0, 20.0, 37.0]
	for side in [-1, 1]:
		for tree_index in range(tree_z_positions.size()):
			var tree_x: float = float(side) * 8.55
			var tree_z: float = tree_z_positions[tree_index]
			_add_cylinder_body(
				"TreeTrunk_%d_%d" % [side, tree_index],
				0.24,
				2.8,
				Vector3(tree_x, 1.4, tree_z),
				_bark_material
			)

			var canopy: MeshInstance3D = MeshInstance3D.new()
			canopy.name = "TreeCanopy_%d_%d" % [side, tree_index]
			var canopy_mesh: SphereMesh = SphereMesh.new()
			canopy_mesh.radius = 1.65
			canopy_mesh.height = 3.2
			canopy_mesh.radial_segments = 10
			canopy_mesh.rings = 5
			canopy.mesh = canopy_mesh
			canopy.material_override = _leaf_material
			canopy.position = Vector3(tree_x, 3.7, tree_z)
			add_child(canopy)

func _build_streetlights() -> void:
	var light_z_positions: Array[float] = [-31.0, -8.0, 16.0, 37.0]
	for side in [-1, 1]:
		for light_index in range(light_z_positions.size()):
			var pole_x: float = float(side) * 7.0
			var pole_z: float = light_z_positions[light_index]
			_add_cylinder_body(
				"StreetlightPole_%d_%d" % [side, light_index],
				0.11,
				5.8,
				Vector3(pole_x, 2.9, pole_z),
				_trim_material
			)
			_add_box_body(
				"StreetlightArm_%d_%d" % [side, light_index],
				Vector3(1.25, 0.12, 0.12),
				Vector3(pole_x - float(side) * 0.58, 5.55, pole_z),
				_trim_material
			)

			var lamp: MeshInstance3D = MeshInstance3D.new()
			lamp.name = "StreetlightLamp_%d_%d" % [side, light_index]
			var lamp_mesh: SphereMesh = SphereMesh.new()
			lamp_mesh.radius = 0.2
			lamp_mesh.height = 0.4
			lamp_mesh.radial_segments = 8
			lamp_mesh.rings = 4
			lamp.mesh = lamp_mesh
			lamp.material_override = _lamp_material
			lamp.position = Vector3(pole_x - float(side) * 1.15, 5.42, pole_z)
			add_child(lamp)

func _add_box_body(
	node_name: String,
	size: Vector3,
	position: Vector3,
	material: Material
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 1

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	body.add_child(collision)
	add_child(body)
	return body

func _add_cylinder_body(
	node_name: String,
	radius: float,
	height: float,
	position: Vector3,
	material: Material
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 1

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var cylinder_mesh: CylinderMesh = CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	cylinder_mesh.height = height
	cylinder_mesh.radial_segments = 10
	mesh_instance.mesh = cylinder_mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule_shape: CapsuleShape3D = CapsuleShape3D.new()
	capsule_shape.radius = radius
	capsule_shape.height = height
	collision.shape = capsule_shape
	body.add_child(collision)
	add_child(body)
	return body

func _add_visual_box(
	node_name: String,
	size: Vector3,
	position: Vector3,
	material: Material
) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	mesh_instance.position = position
	add_child(mesh_instance)
