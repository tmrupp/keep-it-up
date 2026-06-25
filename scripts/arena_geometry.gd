extends Node
class_name ArenaGeometry

const GameConfig := preload("res://scripts/game_config.gd")

@export var arena_radius := 16.0
@export var dome_height := 14.0
@export var cone_base_height := 9.38
@export var cone_top_radius := 8.0
@export var cone_incline_degrees := 30.0
@export var floor_y := 0.0

var overview_camera: Camera3D
var dome_body: StaticBody3D
var floor_body: StaticBody3D

func setup(new_arena_radius: float, new_dome_height: float, new_cone_top_radius: float, new_cone_incline_degrees: float, new_floor_y: float) -> void:
	arena_radius = new_arena_radius
	dome_height = new_dome_height
	cone_top_radius = new_cone_top_radius
	cone_incline_degrees = new_cone_incline_degrees
	floor_y = new_floor_y
	cone_base_height = calculate_cone_base_height()

func build(parent_node: Node) -> void:
	add_lighting(parent_node)
	add_overview_camera(parent_node)
	add_floor(parent_node)
	add_dome(parent_node)
	add_arena_shape_guides(parent_node)

func calculate_cone_base_height() -> float:
	var run := maxf(0.0, arena_radius - cone_top_radius)
	var rise := run * tan(deg_to_rad(cone_incline_degrees))
	return clampf(dome_height - rise, floor_y + 3.0, dome_height - 1.0)

func get_frustum_incline_degrees() -> float:
	var run := maxf(0.001, arena_radius - cone_top_radius)
	var rise := dome_height - cone_base_height
	return rad_to_deg(atan(rise / run))

func get_surface_normal_at(point: Vector3) -> Vector3:
	if point.y >= dome_height - 0.01:
		return Vector3.UP
	var radial := Vector3(point.x, 0.0, point.z)
	if radial.length() <= 0.001:
		return Vector3.UP
	var radial_normal := radial.normalized()
	if point.y < cone_base_height:
		return radial_normal
	var cone_height := maxf(0.001, dome_height - cone_base_height)
	var cone_slope := (cone_top_radius - arena_radius) / cone_height
	return Vector3(radial_normal.x, -cone_slope, radial_normal.z).normalized()

func is_point_on_cap(point: Vector3, tolerance: float = 0.0) -> bool:
	if absf(point.y - dome_height) > tolerance:
		return false
	return Vector2(point.x, point.z).length() <= cone_top_radius + tolerance

func is_point_on_frustum_band(point: Vector3, tolerance: float = 0.0) -> bool:
	if point.y < cone_base_height - tolerance or point.y > dome_height + tolerance:
		return false
	var height_range := maxf(0.001, dome_height - cone_base_height)
	var t := clampf((point.y - cone_base_height) / height_range, 0.0, 1.0)
	var expected_radius := lerpf(arena_radius, cone_top_radius, t)
	var point_radius := Vector2(point.x, point.z).length()
	return absf(point_radius - expected_radius) <= tolerance

func add_lighting(parent_node: Node) -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.04, 0.05, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62, 1.0)
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	parent_node.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.light_energy = 2.1
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	parent_node.add_child(sun)
	var fill := OmniLight3D.new()
	fill.name = "ArenaFillLight"
	fill.position = Vector3(0.0, 8.0, 0.0)
	fill.light_energy = 3.0
	fill.omni_range = 28.0
	parent_node.add_child(fill)

func add_overview_camera(parent_node: Node) -> void:
	overview_camera = Camera3D.new()
	overview_camera.name = "OverviewCamera"
	overview_camera.position = Vector3(0.0, 9.0, 19.0)
	overview_camera.fov = 68.0
	overview_camera.transform = overview_camera.transform.looking_at(Vector3(0.0, 5.4, 0.0), Vector3.UP)
	parent_node.add_child(overview_camera)

func add_floor(parent_node: Node) -> void:
	floor_body = StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.add_to_group(GameConfig.WALL_GROUP)
	floor_body.add_to_group(GameConfig.DOME_GROUP)
	parent_node.add_child(floor_body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = arena_radius
	shape.height = 0.25
	collision.shape = shape
	floor_body.add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = arena_radius
	cylinder_mesh.bottom_radius = arena_radius
	cylinder_mesh.height = 0.18
	cylinder_mesh.radial_segments = 64
	mesh.mesh = cylinder_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.19, 0.2, 1.0)
	material.roughness = 0.9
	mesh.material_override = material
	floor_body.add_child(mesh)

func add_dome(parent_node: Node) -> void:
	dome_body = StaticBody3D.new()
	dome_body.name = "Dome"
	dome_body.add_to_group(GameConfig.WALL_GROUP)
	dome_body.add_to_group(GameConfig.DOME_GROUP)
	parent_node.add_child(dome_body)
	var dome_mesh := create_cylinder_cone_mesh(10, 64)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var dome_shape := dome_mesh.create_trimesh_shape()
	if dome_shape is ConcavePolygonShape3D:
		dome_shape.backface_collision = true
	collision.shape = dome_shape
	dome_body.add_child(collision)
	var top_cap_collision := CollisionShape3D.new()
	top_cap_collision.name = "TopCapCollisionShape3D"
	top_cap_collision.position = Vector3(0.0, dome_height, 0.0)
	var top_cap_shape := CylinderShape3D.new()
	top_cap_shape.radius = cone_top_radius
	top_cap_shape.height = 0.3
	top_cap_collision.shape = top_cap_shape
	dome_body.add_child(top_cap_collision)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	mesh_instance.mesh = dome_mesh
	mesh_instance.visible = false
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.34, 0.42, 0.32)
	material.roughness = 0.72
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material
	dome_body.add_child(mesh_instance)
	add_cylinder_frustum_visuals(dome_body)

func create_cylinder_cone_mesh(cone_ring_count: int, radial_segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var ring_specs := [
		{"radius": arena_radius, "y": floor_y},
		{"radius": arena_radius, "y": cone_base_height}
	]
	for ring in range(1, cone_ring_count + 1):
		var t := float(ring) / float(cone_ring_count)
		ring_specs.append({
			"radius": lerpf(arena_radius, cone_top_radius, t),
			"y": lerpf(cone_base_height, dome_height, t)
		})
	for ring in range(ring_specs.size()):
		var ring_radius: float = ring_specs[ring].get("radius", arena_radius)
		var y: float = ring_specs[ring].get("y", floor_y)
		for segment in range(radial_segments):
			var angle := TAU * float(segment) / float(radial_segments)
			var vertex := Vector3(cos(angle) * ring_radius, y, sin(angle) * ring_radius)
			vertices.append(vertex)
			normals.append(get_surface_normal_at(vertex))
	for ring in range(ring_specs.size() - 1):
		for segment in range(radial_segments):
			var next_segment := (segment + 1) % radial_segments
			var current := ring * radial_segments + segment
			var current_next := ring * radial_segments + next_segment
			var below := (ring + 1) * radial_segments + segment
			var below_next := (ring + 1) * radial_segments + next_segment
			indices.append_array([current, below, below_next, current, below_next, current_next])
	var top_center_index := vertices.size()
	vertices.append(Vector3(0.0, dome_height, 0.0))
	normals.append(Vector3.UP)
	var top_ring_start := (ring_specs.size() - 1) * radial_segments
	for segment in range(radial_segments):
		var next_segment := (segment + 1) % radial_segments
		indices.append_array([top_center_index, top_ring_start + next_segment, top_ring_start + segment])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func add_cylinder_frustum_visuals(parent_node: Node) -> void:
	var cylinder := MeshInstance3D.new()
	cylinder.name = "CylinderWallVisual"
	cylinder.position = Vector3(0.0, cone_base_height * 0.5, 0.0)
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = arena_radius
	cylinder_mesh.bottom_radius = arena_radius
	cylinder_mesh.height = cone_base_height
	cylinder_mesh.radial_segments = 96
	cylinder_mesh.rings = 2
	cylinder_mesh.cap_top = false
	cylinder_mesh.cap_bottom = false
	cylinder.mesh = cylinder_mesh
	var cylinder_material := StandardMaterial3D.new()
	cylinder_material.albedo_color = Color(0.16, 0.46, 0.58, 0.24)
	cylinder_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cylinder_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cylinder_material.roughness = 0.8
	cylinder.material_override = cylinder_material
	parent_node.add_child(cylinder)
	var frustum := MeshInstance3D.new()
	frustum.name = "FrustumRoofVisual"
	frustum.visible = false
	frustum.position = Vector3(0.0, cone_base_height + (dome_height - cone_base_height) * 0.5, 0.0)
	var frustum_mesh := CylinderMesh.new()
	frustum_mesh.bottom_radius = arena_radius
	frustum_mesh.top_radius = cone_top_radius
	frustum_mesh.height = dome_height - cone_base_height
	frustum_mesh.radial_segments = 96
	frustum_mesh.rings = 2
	frustum_mesh.cap_top = false
	frustum_mesh.cap_bottom = false
	frustum.mesh = frustum_mesh
	var frustum_material := StandardMaterial3D.new()
	frustum_material.albedo_color = Color(0.34, 0.68, 0.78, 0.34)
	frustum_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frustum_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	frustum_material.roughness = 0.74
	frustum.material_override = frustum_material
	parent_node.add_child(frustum)

func add_arena_shape_guides(parent_node: Node) -> void:
	add_ring_marker(parent_node, "CylinderFrustumSeam", cone_base_height, arena_radius, Color(0.7, 0.95, 1.0, 0.7))
	add_ring_marker(parent_node, "TopCapRing", dome_height, cone_top_radius, Color(1.0, 0.9, 0.3, 0.85))
	var marker_mesh := MeshInstance3D.new()
	marker_mesh.name = "DomeApexMarker"
	marker_mesh.position = Vector3(0.0, dome_height + 0.1, 0.0)
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	marker_mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.9, 0.3, 1.0)
	marker_mesh.material_override = material
	parent_node.add_child(marker_mesh)

func add_ring_marker(parent_node: Node, marker_name: String, y: float, radius: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	ring.name = marker_name
	var line_mesh := ImmediateMesh.new()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var segments := 96
	for segment in range(segments):
		var angle := TAU * float(segment) / float(segments)
		var next_angle := TAU * float(segment + 1) / float(segments)
		line_mesh.surface_add_vertex(Vector3(cos(angle) * radius, y, sin(angle) * radius))
		line_mesh.surface_add_vertex(Vector3(cos(next_angle) * radius, y, sin(next_angle) * radius))
	line_mesh.surface_end()
	ring.mesh = line_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = material
	parent_node.add_child(ring)
