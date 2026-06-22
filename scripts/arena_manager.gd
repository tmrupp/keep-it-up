extends Node3D
class_name ArenaManager

const GameConfig := preload("res://scripts/game_config.gd")
const PlayerController := preload("res://scripts/player_controller.gd")
const TeamBall := preload("res://scripts/team_ball.gd")
const SpringTrap := preload("res://scripts/spring_trap.gd")
const MatchManager := preload("res://scripts/match_manager.gd")
const HUDController := preload("res://scripts/hud_controller.gd")
const ShotFeedbackController := preload("res://scripts/shot_feedback_controller.gd")
const KeeperBotController := preload("res://scripts/keeper_bot_controller.gd")
const ArenaGeometry := preload("res://scripts/arena_geometry.gd")
const SpawnRegistry := preload("res://scripts/spawn_registry.gd")
const RoundResetService := preload("res://scripts/round_reset_service.gd")
const GroundLossMonitor := preload("res://scripts/ground_loss_monitor.gd")
const CapTrapContactMonitor := preload("res://scripts/cap_trap_contact_monitor.gd")

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
var arena_geometry
var spawn_registry
var round_reset_service
var ground_loss_monitor
var cap_trap_contact_monitor
var hud_controller
var shot_feedback_controller
var keeper_bot_controller
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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_red_bot"):
		var key_event := event as InputEventKey
		if key_event == null or key_event.echo == false:
			set_red_bot_enabled(red_bot_enabled == false)
			get_viewport().set_input_as_handled()

func _ready() -> void:
	_build_arena()
	_spawn_match_objects()
	_setup_match_manager()
	_update_hud()
	arena_ready.emit()

func _process(delta: float) -> void:
	_update_shot_feedback_lifetimes(delta)
	_update_hud()

func reset_point() -> void:
	if round_reset_service != null:
		round_reset_service.reset_point()
		point_reset_count = round_reset_service.point_reset_count
	else:
		point_reset_count += 1
		last_scored_ball_team = 0
		for player in players:
			var spawn_position := player_one_spawn if player.team_id == GameConfig.TEAM_ONE else player_two_spawn
			player.reset_for_point(spawn_position)
		for ball in balls:
			ball.reset_for_point()
		if spring_trap != null:
			spring_trap.reset_charge()
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
		"red_bot": keeper_bot_controller.get_debug_state() if keeper_bot_controller != null else {},
		"spawns": spawn_registry.get_debug_state() if spawn_registry != null else {},
		"reset": round_reset_service.get_debug_state() if round_reset_service != null else {},
		"ground_loss": ground_loss_monitor.get_debug_state() if ground_loss_monitor != null else {},
		"cap_trap_contact": cap_trap_contact_monitor.get_debug_state() if cap_trap_contact_monitor != null else {},
		"has_dome": dome_body != null,
		"shot_feedback_count": _get_shot_feedback_count(),
		"shot_path_count": _get_shot_path_count(),
		"active_shot_feedback_nodes": get_tree().get_nodes_in_group(GameConfig.SHOT_FEEDBACK_GROUP).size(),
		"point_reset_count": point_reset_count,
		"last_scored_ball_team": last_scored_ball_team
	}

func use_overview_camera() -> void:
	if overview_camera != null:
		overview_camera.current = true

func _physics_process(_delta: float) -> void:
	if cap_trap_contact_monitor != null:
		cap_trap_contact_monitor.update_cooldowns(_delta)
	_check_ball_floor_loss()
	_update_red_bot(_delta)

func set_red_bot_enabled(enabled: bool) -> void:
	red_bot_enabled = enabled
	if keeper_bot_controller != null:
		keeper_bot_controller.set_enabled(enabled)
	_update_hud()

func _calculate_cone_base_height() -> float:
	if arena_geometry != null:
		return arena_geometry.calculate_cone_base_height()
	var run := maxf(0.0, arena_radius - cone_top_radius)
	var rise := run * tan(deg_to_rad(cone_incline_degrees))
	return clampf(dome_height - rise, floor_y + 3.0, dome_height - 1.0)

func get_frustum_incline_degrees() -> float:
	if arena_geometry != null:
		return arena_geometry.get_frustum_incline_degrees()
	var run := maxf(0.001, arena_radius - cone_top_radius)
	var rise := dome_height - cone_base_height
	return rad_to_deg(atan(rise / run))

func get_arena_normal_at(point: Vector3) -> Vector3:
	if arena_geometry != null:
		return arena_geometry.get_surface_normal_at(point)
	return _dome_normal_at(point)

func is_point_on_cap(point: Vector3, tolerance: float = 0.0) -> bool:
	if arena_geometry != null:
		return arena_geometry.is_point_on_cap(point, tolerance)
	return _is_point_on_cap(point, tolerance)

func is_point_on_frustum_band(point: Vector3, tolerance: float = 0.0) -> bool:
	if arena_geometry != null:
		return arena_geometry.is_point_on_frustum_band(point, tolerance)
	return _is_point_on_frustum_band(point, tolerance)

func check_ball_loss_for_tests() -> void:
	_check_ball_floor_loss()

func check_spring_trap_cap_contact_for_tests(ball: Node) -> void:
	_check_spring_trap_cap_contact(ball)

func update_red_bot_for_tests(delta: float) -> void:
	_update_red_bot(delta)

func refresh_hud() -> void:
	_update_hud()

func update_shot_feedback_lifetimes_for_tests(delta: float) -> void:
	_update_shot_feedback_lifetimes(delta)

func _build_arena() -> void:
	spawn_registry = SpawnRegistry.new()
	spawn_registry.name = "SpawnRegistry"
	spawn_registry.setup(player_one_spawn, player_two_spawn, ball_one_spawn, ball_two_spawn)
	add_child(spawn_registry)
	arena_geometry = ArenaGeometry.new()
	arena_geometry.name = "ArenaGeometry"
	arena_geometry.setup(arena_radius, dome_height, cone_top_radius, cone_incline_degrees, floor_y)
	add_child(arena_geometry)
	cone_base_height = arena_geometry.cone_base_height
	arena_geometry.build(self)
	spawn_registry.add_markers(self)
	overview_camera = arena_geometry.overview_camera
	dome_body = arena_geometry.dome_body
	_add_floor_loss_area()
	_add_hud()

func _spawn_match_objects() -> void:
	spring_trap = SpringTrap.new()
	spring_trap.name = "SpringTrap"
	spring_trap.setup_cap(dome_height + 0.08, cone_top_radius)
	add_child(spring_trap)
	_setup_cap_trap_contact_monitor()
	var player_one := PlayerController.new()
	player_one.name = "PlayerBlue"
	add_child(player_one)
	player_one.setup(GameConfig.TEAM_ONE, player_one_spawn, true)
	local_camera = player_one.camera
	if shot_feedback_controller != null:
		shot_feedback_controller.local_camera = local_camera
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
	_setup_keeper_bot(player_two, ball_two)
	_setup_round_reset_service()

func _setup_round_reset_service() -> void:
	round_reset_service = RoundResetService.new()
	round_reset_service.name = "RoundResetService"
	round_reset_service.setup(players, balls, spring_trap, spawn_registry)
	round_reset_service.add_reset_hook(ground_loss_monitor, "reset_for_point")
	round_reset_service.add_reset_hook(cap_trap_contact_monitor, "reset_for_point")
	round_reset_service.point_reset_completed.connect(_on_point_reset_completed)
	add_child(round_reset_service)

func _setup_cap_trap_contact_monitor() -> void:
	cap_trap_contact_monitor = CapTrapContactMonitor.new()
	cap_trap_contact_monitor.name = "CapTrapContactMonitor"
	cap_trap_contact_monitor.setup(spring_trap, arena_geometry)
	add_child(cap_trap_contact_monitor)

func _setup_keeper_bot(red_player: Node, red_ball: Node) -> void:
	keeper_bot_controller = KeeperBotController.new()
	keeper_bot_controller.name = "KeeperBotController"
	keeper_bot_controller.enabled = red_bot_enabled
	keeper_bot_controller.reaction_height = red_bot_reaction_height
	keeper_bot_controller.min_fall_speed = red_bot_min_fall_speed
	keeper_bot_controller.move_speed = red_bot_move_speed
	keeper_bot_controller.setup(red_player, red_ball)
	keeper_bot_controller.enabled_changed.connect(_on_keeper_bot_enabled_changed)
	add_child(keeper_bot_controller)

func _setup_match_manager() -> void:
	match_manager = MatchManager.new()
	match_manager.name = "MatchManager"
	match_manager.reset_delay = 0.0
	add_child(match_manager)
	match_manager.setup(self)
	match_manager.set_reset_target(round_reset_service)
	match_manager.score_changed.connect(_on_score_changed)
	match_manager.match_finished.connect(_on_match_finished)

func _on_point_reset_completed() -> void:
	last_scored_ball_team = 0
	point_reset_count = round_reset_service.point_reset_count if round_reset_service != null else point_reset_count

func _dome_normal_at(point: Vector3) -> Vector3:
	if arena_geometry != null:
		return arena_geometry.get_surface_normal_at(point)
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

func _add_floor_loss_area() -> void:
	ground_loss_monitor = GroundLossMonitor.new()
	ground_loss_monitor.setup(arena_radius, ball_floor_loss_y)
	ground_loss_monitor.ball_grounded.connect(_on_ball_grounded)
	add_child(ground_loss_monitor)
	floor_area = ground_loss_monitor

func _add_hud() -> void:
	hud_controller = HUDController.new()
	hud_controller.setup()
	add_child(hud_controller)
	hud_label = hud_controller.score_label
	ammo_label = hud_controller.ammo_label
	charged_shot_label = hud_controller.charged_shot_label
	bot_label = hud_controller.bot_label
	hit_marker_label = hud_controller.hit_marker_label
	shot_feedback_controller = ShotFeedbackController.new()
	shot_feedback_controller.name = "ShotFeedbackController"
	shot_feedback_controller.shot_path_lifetime = shot_path_lifetime
	shot_feedback_controller.hit_marker_lifetime = hit_marker_lifetime
	shot_feedback_controller.shot_path_start_offset = shot_path_start_offset
	shot_feedback_controller.local_camera = local_camera
	add_child(shot_feedback_controller)

func _check_ball_floor_loss() -> void:
	if match_manager == null or match_manager.match_over:
		return
	if cap_trap_contact_monitor != null:
		cap_trap_contact_monitor.check_all(balls)
	if ground_loss_monitor != null:
		ground_loss_monitor.force_check(balls)

func _check_spring_trap_cap_contact(ball: Node) -> void:
	if cap_trap_contact_monitor != null:
		cap_trap_contact_monitor.check_ball(ball)

func _is_point_on_cap(point: Vector3, tolerance: float = 0.0) -> bool:
	if arena_geometry != null:
		return arena_geometry.is_point_on_cap(point, tolerance)
	if absf(point.y - dome_height) > tolerance:
		return false
	return Vector2(point.x, point.z).length() <= cone_top_radius + tolerance

func _is_point_on_frustum_band(point: Vector3, tolerance: float = 0.0) -> bool:
	if arena_geometry != null:
		return arena_geometry.is_point_on_frustum_band(point, tolerance)
	if point.y < cone_base_height - tolerance or point.y > dome_height + tolerance:
		return false
	var height_range := maxf(0.001, dome_height - cone_base_height)
	var t := clampf((point.y - cone_base_height) / height_range, 0.0, 1.0)
	var expected_radius := lerpf(arena_radius, cone_top_radius, t)
	var point_radius := Vector2(point.x, point.z).length()
	return absf(point_radius - expected_radius) <= tolerance

func _on_ball_grounded(team_id: int, _ball: Node) -> void:
	if match_manager == null or match_manager.match_over or last_scored_ball_team != 0:
		return
	last_scored_ball_team = team_id
	match_manager.register_ball_grounded(team_id)

func _on_score_changed(_scores: Dictionary) -> void:
	_update_hud()

func _on_match_finished(_winning_team_id: int) -> void:
	_update_hud()

func _on_keeper_bot_enabled_changed(enabled: bool) -> void:
	red_bot_enabled = enabled
	_update_hud()

func _update_hud() -> void:
	if hud_controller == null or match_manager == null:
		return
	hud_controller.set_score(match_manager.get_score(GameConfig.TEAM_ONE), match_manager.get_score(GameConfig.TEAM_TWO))
	var player: Node = get_player(GameConfig.TEAM_ONE)
	var weapon = player.weapon if player != null else null
	if weapon != null:
		hud_controller.set_weapon_state(weapon.ammo, weapon.max_ammo, weapon.final_bonus_enabled, weapon.is_reloading)
	hud_controller.set_bot_enabled(red_bot_enabled)

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
	if hud_controller != null:
		hud_controller.show_hit_text(feedback, color)
	if shot_feedback_controller != null:
		shot_feedback_controller.show_shot_feedback(feedback, color, world_position, path_segments, is_bank_shot, is_charged_shot)
	_sync_shot_feedback_counters()

func _spawn_shot_path(path_segments: Array, color: Color, is_bank_shot: bool = false, is_charged_shot: bool = false) -> void:
	if shot_feedback_controller != null:
		shot_feedback_controller._spawn_shot_path(path_segments, color, is_bank_shot, is_charged_shot)
		_sync_shot_feedback_counters()

func _spawn_world_hit_marker(world_position: Vector3, color: Color, is_bank_shot: bool = false, is_charged_shot: bool = false) -> void:
	if shot_feedback_controller != null:
		shot_feedback_controller._spawn_world_hit_marker(world_position, color, is_bank_shot, is_charged_shot)

func _nudge_path_start(point: Vector3) -> Vector3:
	if shot_feedback_controller != null:
		return shot_feedback_controller._nudge_path_start(point)
	return point

func _update_shot_feedback_lifetimes(delta: float) -> void:
	if shot_feedback_controller != null:
		shot_feedback_controller.update_lifetimes(delta)
		_sync_shot_feedback_counters()

func _sync_shot_feedback_counters() -> void:
	shot_feedback_count = _get_shot_feedback_count()
	shot_path_count = _get_shot_path_count()

func _get_shot_feedback_count() -> int:
	if shot_feedback_controller == null:
		return shot_feedback_count
	return shot_feedback_controller.shot_feedback_count

func _get_shot_path_count() -> int:
	if shot_feedback_controller == null:
		return shot_path_count
	return shot_feedback_controller.shot_path_count

func _update_red_bot(delta: float) -> void:
	if keeper_bot_controller != null:
		keeper_bot_controller.update_bot(delta)
		red_bot_enabled = keeper_bot_controller.is_enabled()

func _move_red_bot_under_ball(red_player: Node, red_ball: Node, delta: float) -> void:
	if keeper_bot_controller == null:
		return
	keeper_bot_controller.player = red_player
	keeper_bot_controller.ball = red_ball
	keeper_bot_controller.update_bot(delta)
