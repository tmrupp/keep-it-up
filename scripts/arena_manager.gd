extends Node3D
class_name ArenaManager

const GameConfig := preload("res://scripts/game_config.gd")
const PlayerController := preload("res://scripts/player_controller.gd")
const TeamBall := preload("res://scripts/team_ball.gd")
const SpringTrap := preload("res://scripts/spring_trap.gd")
const MatchManager := preload("res://scripts/match_manager.gd")

signal arena_ready

@export var arena_radius := 16.0
@export var dome_height := 14.0
@export var cone_base_height := 9.38
@export var cone_top_radius := 8.0
@export var cone_incline_degrees := 30.0
@export var floor_y := 0.0
@export var ball_floor_loss_y := 0.65
@export var player_one_spawn := Vector3(-5.0, 1.2, 5.0)
@export var player_two_spawn := Vector3(5.0, 1.2, -5.0)
@export var ball_one_spawn := Vector3(-5.0, 9.5, 2.5)
@export var ball_two_spawn := Vector3(5.0, 9.5, -2.5)
@export var shot_path_lifetime := 0.75
@export var shot_path_start_offset := 0.35
@export var hit_marker_lifetime := 0.55
@export var red_bot_enabled := true
@export var red_bot_reaction_height := 8.5
@export var red_bot_min_fall_speed := -0.25
@export var red_bot_move_speed := 7.0

var match_manager
var players: Array = []
var balls: Array = []
var spring_trap
var floor_area: Area3D
var hud_label: Label
var ammo_label: Label
var charged_shot_label: Label
var bot_label: Label
var hit_marker_label: Label
var overview_camera: Camera3D
var dome_body: StaticBody3D
var local_camera: Camera3D
var shot_feedback_count := 0
var shot_path_count := 0
var hit_feedback_timer := 0.0
var last_scored_ball_team := 0
var point_reset_count := 0
var cap_trap_contact_cooldowns := {}

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_red_bot"):
		var key_event := event as InputEventKey
		if key_event == null or key_event.echo == false:
			set_red_bot_enabled(red_bot_enabled == false)
			get_viewport().set_input_as_handled()

func _ready() -> void:
	cone_base_height = _calculate_cone_base_height()
	_build_arena()
	_spawn_match_objects()
	_setup_match_manager()
	_update_hud()
	arena_ready.emit()

func _process(delta: float) -> void:
	if hit_feedback_timer > 0.0:
		hit_feedback_timer = maxf(0.0, hit_feedback_timer - delta)
		if hit_feedback_timer == 0.0 and hit_marker_label != null:
			hit_marker_label.text = ""
	_update_shot_feedback_lifetimes(delta)
	_update_hud()

func reset_point() -> void:
	point_reset_count += 1
	last_scored_ball_team = 0
	for player in players:
		var spawn_position := player_one_spawn if player.team_id == GameConfig.TEAM_ONE else player_two_spawn
		player.reset_player(spawn_position)
	for ball in balls:
		ball.reset_ball()
	if spring_trap != null:
		spring_trap.current_charge = 0.0
		if spring_trap.has_method("_update_visuals"):
			spring_trap._update_visuals()
	_update_hud()

func simulate_shot_from_team(team_id: int, target: Node, is_final_shot: bool = false) -> float:
	var direction := Vector3.FORWARD
	var player: Node = get_player(team_id)
	if player != null and target is Node3D:
		direction = ((target as Node3D).global_position - player.global_position).normalized()
	if target.has_method("apply_shot"):
		return target.apply_shot(direction, is_final_shot)
	if target.has_method("receive_shot_knockback"):
		var weapon = player.weapon if player != null else null
		var impulse_strength: float = weapon.get_player_knockback(is_final_shot) if weapon != null else 10.0
		target.receive_shot_knockback(direction, impulse_strength)
		return impulse_strength
	if target.has_method("charge_from_shot"):
		return target.charge_from_shot(is_final_shot)
	return 0.0

func get_player(team_id: int):
	for player in players:
		if player.team_id == team_id:
			return player
	return null

func get_ball(team_id: int):
	for ball in balls:
		if ball.team_id == team_id:
			return ball
	return null

func get_debug_state() -> Dictionary:
	var player_states := []
	for player in players:
		player_states.append(player.get_debug_state())
	var ball_states := []
	for ball in balls:
		ball_states.append(ball.get_debug_state())
	return {
		"scores": match_manager.get_debug_state() if match_manager != null else {},
		"players": player_states,
		"balls": ball_states,
		"trap": spring_trap.get_debug_state() if spring_trap != null else {},
		"red_bot_enabled": red_bot_enabled,
		"has_dome": dome_body != null,
		"shot_feedback_count": shot_feedback_count,
		"shot_path_count": shot_path_count,
		"active_shot_feedback_nodes": get_tree().get_nodes_in_group(GameConfig.SHOT_FEEDBACK_GROUP).size(),
		"point_reset_count": point_reset_count,
		"last_scored_ball_team": last_scored_ball_team
	}

func use_overview_camera() -> void:
	if overview_camera != null:
		overview_camera.current = true

func _physics_process(_delta: float) -> void:
	_update_cap_trap_contact_cooldowns(_delta)
	_check_ball_floor_loss()
	_update_red_bot(_delta)

func set_red_bot_enabled(enabled: bool) -> void:
	red_bot_enabled = enabled
	_update_hud()

func _calculate_cone_base_height() -> float:
	var run := maxf(0.0, arena_radius - cone_top_radius)
	var rise := run * tan(deg_to_rad(cone_incline_degrees))
	return clampf(dome_height - rise, floor_y + 3.0, dome_height - 1.0)

func get_frustum_incline_degrees() -> float:
	var run := maxf(0.001, arena_radius - cone_top_radius)
	var rise := dome_height - cone_base_height
	return rad_to_deg(atan(rise / run))

func _build_arena() -> void:
	_add_lighting()
	_add_overview_camera()
	_add_floor()
	_add_dome()
	_add_arena_shape_guides()
	_add_floor_loss_area()
	_add_markers()
	_add_hud()

func _spawn_match_objects() -> void:
	spring_trap = SpringTrap.new()
	spring_trap.name = "SpringTrap"
	spring_trap.setup_cap(dome_height + 0.08, cone_top_radius)
	add_child(spring_trap)
	var player_one := PlayerController.new()
	player_one.name = "PlayerBlue"
	add_child(player_one)
	player_one.setup(GameConfig.TEAM_ONE, player_one_spawn, true)
	local_camera = player_one.camera
	_connect_local_player_feedback(player_one)
	players.append(player_one)
	var player_two := PlayerController.new()
	player_two.name = "PlayerRed"
	add_child(player_two)
	player_two.setup(GameConfig.TEAM_TWO, player_two_spawn, false)
	_connect_local_player_feedback(player_two)
	players.append(player_two)
	var ball_one := TeamBall.new()
	ball_one.name = "BallBlue"
	add_child(ball_one)
	ball_one.setup(GameConfig.TEAM_ONE, ball_one_spawn)
	balls.append(ball_one)
	var ball_two := TeamBall.new()
	ball_two.name = "BallRed"
	add_child(ball_two)
	ball_two.setup(GameConfig.TEAM_TWO, ball_two_spawn)
	balls.append(ball_two)
func _setup_match_manager() -> void:
	match_manager = MatchManager.new()
	match_manager.name = "MatchManager"
	match_manager.reset_delay = 0.0
	add_child(match_manager)
	match_manager.setup(self)
	match_manager.score_changed.connect(_on_score_changed)
	match_manager.match_finished.connect(_on_match_finished)

func _add_lighting() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.04, 0.05, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62, 1.0)
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.light_energy = 2.1
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.name = "ArenaFillLight"
	fill.position = Vector3(0.0, 8.0, 0.0)
	fill.light_energy = 3.0
	fill.omni_range = 28.0
	add_child(fill)

func _add_overview_camera() -> void:
	overview_camera = Camera3D.new()
	overview_camera.name = "OverviewCamera"
	overview_camera.position = Vector3(0.0, 9.0, 19.0)
	overview_camera.fov = 68.0
	overview_camera.transform = overview_camera.transform.looking_at(Vector3(0.0, 5.4, 0.0), Vector3.UP)
	add_child(overview_camera)

func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.add_to_group(GameConfig.WALL_GROUP)
	floor_body.add_to_group(GameConfig.DOME_GROUP)
	add_child(floor_body)
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

func _add_dome() -> void:
	dome_body = StaticBody3D.new()
	dome_body.name = "Dome"
	dome_body.add_to_group(GameConfig.WALL_GROUP)
	dome_body.add_to_group(GameConfig.DOME_GROUP)
	add_child(dome_body)
	var dome_mesh := _create_cylinder_cone_mesh(10, 64)
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
	_add_cylinder_frustum_visuals(dome_body)

func _create_cylinder_cone_mesh(cone_ring_count: int, radial_segments: int) -> ArrayMesh:
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
			normals.append(_dome_normal_at(vertex))
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

func _dome_normal_at(point: Vector3) -> Vector3:
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

func _add_cylinder_frustum_visuals(parent_node: Node) -> void:
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

func _add_arena_shape_guides() -> void:
	_add_ring_marker("CylinderFrustumSeam", cone_base_height, arena_radius, Color(0.7, 0.95, 1.0, 0.7))
	_add_ring_marker("TopCapRing", dome_height, cone_top_radius, Color(1.0, 0.9, 0.3, 0.85))
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
	add_child(marker_mesh)

func _add_ring_marker(marker_name: String, y: float, radius: float, color: Color) -> void:
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
	add_child(ring)

func _add_floor_loss_area() -> void:
	floor_area = Area3D.new()
	floor_area.name = "GroundLossArea"
	floor_area.position = Vector3(0.0, ball_floor_loss_y, 0.0)
	floor_area.collision_layer = 0
	add_child(floor_area)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = arena_radius * 0.96
	shape.height = 0.2
	collision.shape = shape
	floor_area.add_child(collision)
	floor_area.body_entered.connect(_on_ground_loss_body_entered)

func _add_markers() -> void:
	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	add_child(spawn_points)
	_create_marker(spawn_points, "PlayerBlueSpawn", player_one_spawn)
	_create_marker(spawn_points, "PlayerRedSpawn", player_two_spawn)
	_create_marker(spawn_points, "BallBlueSpawn", ball_one_spawn)
	_create_marker(spawn_points, "BallRedSpawn", ball_two_spawn)

func _add_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	hud_label = Label.new()
	hud_label.name = "ScoreLabel"
	hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_label.position = Vector2(24.0, 18.0)
	hud_label.add_theme_font_size_override("font_size", 24)
	canvas.add_child(hud_label)
	ammo_label = Label.new()
	ammo_label.name = "AmmoLabel"
	ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_label.position = Vector2(24.0, 50.0)
	ammo_label.add_theme_font_size_override("font_size", 22)
	canvas.add_child(ammo_label)
	charged_shot_label = Label.new()
	charged_shot_label.name = "ChargedShotLabel"
	charged_shot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charged_shot_label.position = Vector2(24.0, 78.0)
	charged_shot_label.add_theme_font_size_override("font_size", 20)
	charged_shot_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.18, 1.0))
	canvas.add_child(charged_shot_label)
	bot_label = Label.new()
	bot_label.name = "BotLabel"
	bot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_label.position = Vector2(24.0, 106.0)
	bot_label.add_theme_font_size_override("font_size", 18)
	canvas.add_child(bot_label)
	_add_crosshair(canvas)
	hit_marker_label = Label.new()
	hit_marker_label.name = "HitMarkerLabel"
	hit_marker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hit_marker_label.position = Vector2(490.0, 394.0)
	hit_marker_label.size = Vector2(300.0, 40.0)
	hit_marker_label.add_theme_font_size_override("font_size", 20)
	canvas.add_child(hit_marker_label)

func _add_crosshair(canvas: CanvasLayer) -> void:
	var root := Control.new()
	root.name = "CrosshairRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left = 0.0
	root.offset_top = 0.0
	root.offset_right = 0.0
	root.offset_bottom = 0.0
	var horizontal := ColorRect.new()
	horizontal.name = "CrosshairHorizontal"
	horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal.color = Color(0.95, 0.98, 1.0, 0.82)
	horizontal.position = Vector2(-12.0, -1.0)
	horizontal.size = Vector2(24.0, 2.0)
	root.add_child(horizontal)
	var vertical := ColorRect.new()
	vertical.name = "CrosshairVertical"
	vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical.color = horizontal.color
	vertical.position = Vector2(-1.0, -12.0)
	vertical.size = Vector2(2.0, 24.0)
	root.add_child(vertical)
	canvas.add_child(root)

func _create_marker(parent_node: Node, marker_name: String, marker_position: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = marker_position
	parent_node.add_child(marker)

func _check_ball_floor_loss() -> void:
	if match_manager == null or match_manager.match_over:
		return
	for ball in balls:
		_check_spring_trap_cap_contact(ball)
		if ball.global_position.y <= ball_floor_loss_y and last_scored_ball_team == 0:
			last_scored_ball_team = ball.team_id
			match_manager.register_ball_grounded(ball.team_id)
			return

func _check_spring_trap_cap_contact(ball: Node) -> void:
	if spring_trap == null or ball == null or ball.get_script() != TeamBall:
		return
	if cap_trap_contact_cooldowns.has(ball.get_instance_id()):
		return
	if _is_point_on_cap(ball.global_position, ball.visible_radius) and ball.linear_velocity.y > 0.05:
		spring_trap.trigger_for_ball(ball)
		cap_trap_contact_cooldowns[ball.get_instance_id()] = 0.28

func _update_cap_trap_contact_cooldowns(delta: float) -> void:
	var expired_ids := []
	for instance_id in cap_trap_contact_cooldowns.keys():
		var remaining_time: float = float(cap_trap_contact_cooldowns[instance_id]) - delta
		if remaining_time <= 0.0:
			expired_ids.append(instance_id)
		else:
			cap_trap_contact_cooldowns[instance_id] = remaining_time
	for instance_id in expired_ids:
		cap_trap_contact_cooldowns.erase(instance_id)

func _is_point_on_cap(point: Vector3, tolerance: float = 0.0) -> bool:
	if absf(point.y - dome_height) > tolerance:
		return false
	return Vector2(point.x, point.z).length() <= cone_top_radius + tolerance

func _is_point_on_frustum_band(point: Vector3, tolerance: float = 0.0) -> bool:
	if point.y < cone_base_height - tolerance or point.y > dome_height + tolerance:
		return false
	var height_range := maxf(0.001, dome_height - cone_base_height)
	var t := clampf((point.y - cone_base_height) / height_range, 0.0, 1.0)
	var expected_radius := lerpf(arena_radius, cone_top_radius, t)
	var point_radius := Vector2(point.x, point.z).length()
	return absf(point_radius - expected_radius) <= tolerance

func _on_ground_loss_body_entered(body: Node) -> void:
	if body != null and body.get_script() == TeamBall and last_scored_ball_team == 0:
		last_scored_ball_team = body.team_id
		match_manager.register_ball_grounded(body.team_id)

func _on_score_changed(_scores: Dictionary) -> void:
	_update_hud()

func _on_match_finished(_winning_team_id: int) -> void:
	_update_hud()

func _update_hud() -> void:
	if hud_label == null or match_manager == null:
		return
	hud_label.text = "Blue %d  |  Red %d" % [match_manager.get_score(GameConfig.TEAM_ONE), match_manager.get_score(GameConfig.TEAM_TWO)]
	if ammo_label != null:
		var player: Node = get_player(GameConfig.TEAM_ONE)
		var weapon = player.weapon if player != null else null
		if weapon != null:
			var reload_text := " RELOADING" if weapon.is_reloading else ""
			var final_text := " FINAL" if weapon.ammo == 1 and weapon.final_bonus_enabled else ""
			ammo_label.text = "Ammo %d/%d%s%s" % [weapon.ammo, weapon.max_ammo, final_text, reload_text]
			if charged_shot_label != null:
				charged_shot_label.text = "CHARGED SHOT READY" if weapon.ammo == 1 and weapon.final_bonus_enabled and weapon.is_reloading == false else ""
	if bot_label != null:
		bot_label.text = "Red Bot: %s (Space)" % ["ON" if red_bot_enabled else "OFF"]

func _connect_local_player_feedback(player: Node) -> void:
	if player == null or player.weapon == null:
		return
	player.weapon.ammo_changed.connect(_on_local_ammo_changed)
	player.weapon.shot_fired.connect(_on_local_shot_fired)

func _on_local_ammo_changed(_ammo: int, _final_bonus_enabled: bool, _is_reloading: bool) -> void:
	_update_hud()

func _on_local_shot_fired(hit_node: Node, is_final_shot: bool, impulse_strength: float, ricochet_count: int, hit_position: Vector3, path_segments: Array) -> void:
	var trap_hit_position := hit_position
	if ricochet_count > 0 and path_segments.size() > 0:
		trap_hit_position = path_segments[0].get("to", hit_position)
	if spring_trap != null and _is_point_on_cap(trap_hit_position, 0.35):
		impulse_strength = spring_trap.charge_from_shot(is_final_shot)
	var feedback := "MISS"
	var color := Color(0.95, 0.95, 0.95, 1.0)
	if hit_node != null and impulse_strength > 0.0:
		feedback = "HIT"
		color = Color(0.35, 1.0, 0.55, 1.0)
	if is_final_shot:
		feedback = "FINAL " + feedback
		color = Color(1.0, 0.82, 0.22, 1.0)
	if ricochet_count > 0:
		feedback = "BANK " + feedback
		if is_final_shot == false:
			color = Color(0.2, 0.88, 1.0, 1.0)
	show_shot_feedback(feedback, color, hit_position, path_segments, ricochet_count > 0, is_final_shot)

func show_shot_feedback(feedback: String, color: Color, world_position: Vector3, path_segments: Array = [], is_bank_shot: bool = false, is_charged_shot: bool = false) -> void:
	shot_feedback_count += 1
	hit_feedback_timer = 0.5
	if hit_marker_label != null:
		hit_marker_label.text = feedback
		hit_marker_label.add_theme_color_override("font_color", color)
	_spawn_shot_path(path_segments, color, is_bank_shot, is_charged_shot)
	_spawn_world_hit_marker(world_position, color, is_bank_shot, is_charged_shot)

func _spawn_shot_path(path_segments: Array, color: Color, is_bank_shot: bool = false, is_charged_shot: bool = false) -> void:
	if path_segments.is_empty():
		return
	shot_path_count += 1
	var line_mesh := ImmediateMesh.new()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for segment in path_segments:
		line_mesh.surface_add_vertex(_nudge_path_start(segment.get("from", Vector3.ZERO)))
		line_mesh.surface_add_vertex(segment.get("to", Vector3.ZERO))
	line_mesh.surface_end()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "ShotPath%03d" % shot_path_count
	mesh_instance.add_to_group(GameConfig.SHOT_FEEDBACK_GROUP)
	mesh_instance.mesh = line_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.4 if is_charged_shot else (2.4 if is_bank_shot else 1.2)
	mesh_instance.material_override = material
	var path_lifetime := shot_path_lifetime * (2.1 if is_charged_shot else (1.65 if is_bank_shot else 1.0))
	mesh_instance.set_meta("lifetime", path_lifetime)
	mesh_instance.set_meta("remaining_lifetime", path_lifetime)
	mesh_instance.set_meta("base_alpha", color.a)
	mesh_instance.set_meta("is_bank_shot", is_bank_shot)
	mesh_instance.set_meta("is_charged_shot", is_charged_shot)
	add_child(mesh_instance)

func _spawn_world_hit_marker(world_position: Vector3, color: Color, is_bank_shot: bool = false, is_charged_shot: bool = false) -> void:
	if world_position == Vector3.ZERO:
		return
	var marker := MeshInstance3D.new()
	marker.name = "ShotFeedback%03d" % shot_feedback_count
	marker.add_to_group(GameConfig.SHOT_FEEDBACK_GROUP)
	marker.position = world_position
	var sphere := SphereMesh.new()
	sphere.radius = 0.28 if is_charged_shot else (0.2 if is_bank_shot else 0.12)
	sphere.height = 0.56 if is_charged_shot else (0.4 if is_bank_shot else 0.24)
	marker.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.8 if is_charged_shot else (1.8 if is_bank_shot else 0.8)
	marker.material_override = material
	var marker_lifetime := hit_marker_lifetime * (2.1 if is_charged_shot else (1.65 if is_bank_shot else 1.0))
	marker.set_meta("lifetime", marker_lifetime)
	marker.set_meta("remaining_lifetime", marker_lifetime)
	marker.set_meta("base_alpha", color.a)
	marker.set_meta("is_bank_shot", is_bank_shot)
	marker.set_meta("is_charged_shot", is_charged_shot)
	add_child(marker)

func _nudge_path_start(point: Vector3) -> Vector3:
	if local_camera == null:
		return point
	if point.distance_to(local_camera.global_position) > 0.08:
		return point
	return local_camera.global_position + (-local_camera.global_transform.basis.z).normalized() * shot_path_start_offset

func _update_shot_feedback_lifetimes(delta: float) -> void:
	for node in get_tree().get_nodes_in_group(GameConfig.SHOT_FEEDBACK_GROUP):
		if node.has_meta("remaining_lifetime") == false or node.has_meta("lifetime") == false:
			continue
		var lifetime: float = node.get_meta("lifetime")
		var remaining_lifetime: float = float(node.get_meta("remaining_lifetime")) - delta
		node.set_meta("remaining_lifetime", remaining_lifetime)
		if remaining_lifetime <= 0.0:
			node.queue_free()
			continue
		var alpha := clampf(remaining_lifetime / lifetime, 0.0, 1.0) * float(node.get_meta("base_alpha", 1.0))
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			var material := mesh_node.material_override as StandardMaterial3D
			if material != null:
				var color := material.albedo_color
				color.a = alpha
				material.albedo_color = color
				material.emission_energy_multiplier = maxf(0.0, alpha * 1.2)

func _update_red_bot(delta: float) -> void:
	if red_bot_enabled == false:
		return
	var red_player = get_player(GameConfig.TEAM_TWO)
	var red_ball = get_ball(GameConfig.TEAM_TWO)
	if red_player == null or red_ball == null or red_player.weapon == null:
		return
	_move_red_bot_under_ball(red_player, red_ball, delta)
	if red_player.weapon.ammo <= 0:
		red_player.weapon.request_reload()
		return
	var ball_needs_help: bool = red_ball.global_position.y < red_bot_reaction_height or red_ball.linear_velocity.y <= red_bot_min_fall_speed
	if ball_needs_help == false or red_player.weapon.can_fire() == false:
		return
	var origin: Vector3 = red_player.camera.global_position
	var direction: Vector3 = (red_ball.global_position - origin).normalized()
	red_player.weapon.try_fire(origin, direction, red_player)

func _move_red_bot_under_ball(red_player: Node, red_ball: Node, delta: float) -> void:
	var target_position := Vector3(red_ball.global_position.x, red_player.global_position.y, red_ball.global_position.z)
	red_player.global_position = red_player.global_position.move_toward(target_position, red_bot_move_speed * delta)
	var look_direction: Vector3 = red_ball.global_position - red_player.global_position
	look_direction.y = 0.0
	if look_direction.length() > 0.01:
		red_player.rotation.y = atan2(-look_direction.x, -look_direction.z)
