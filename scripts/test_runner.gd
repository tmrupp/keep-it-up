extends SceneTree

const RESULT_DIR := "res://artifacts/results"
const SCREENSHOT_DIR := "res://artifacts/screenshots"
const SCREENSHOT_SIZE := Vector2i(1280, 720)
const ARENA_MANAGER_SCRIPT := preload("res://scripts/arena_manager.gd")
const GAME_CONFIG_SCRIPT := preload("res://scripts/game_config.gd")

var results: Dictionary = {
	"ok": true,
	"checks": [],
	"screenshots": []
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_ensure_output_dirs()
	var arena = ARENA_MANAGER_SCRIPT.new()
	arena.name = "ArenaUnderTest"
	root.add_child(arena)
	await process_frame
	await physics_frame
	await physics_frame
	_check("arena_has_two_players", arena.players.size() == 2, "expected two spawned players")
	_check("arena_has_two_balls", arena.balls.size() == 2, "expected two spawned team balls")
	_check("arena_has_trap", arena.spring_trap != null, "expected top spring trap")
	_run_actual_dome_smoke(arena)
	_run_hud_smoke(arena)
	_run_mouse_camera_smoke(arena)
	await _run_red_bot_smoke(arena)
	await _capture_screenshot("arena_smoke", arena)
	await _run_ball_spawn_tuning(arena)
	await _run_ball_impulse(arena)
	await _run_ball_shot_hit_area(arena)
	await _run_arena_contains_upward_ball(arena)
	_run_ground_score(arena)
	await _run_floor_threshold_score(arena)
	_run_final_shot(arena)
	_run_early_reload(arena)
	await _run_auto_reload_and_charged_visual(arena)
	await _run_shot_feedback(arena)
	await _run_ricochet_shot(arena)
	await _run_floor_ricochet_shot(arena)
	_run_wall_stun(arena)
	await _run_spring_trap(arena)
	_write_results(arena)
	quit(0 if results["ok"] else 1)

func _run_ball_impulse(arena) -> void:
	var ball = arena.get_ball(GAME_CONFIG_SCRIPT.TEAM_ONE)
	var before_velocity: Vector3 = ball.linear_velocity
	var impulse: float = ball.apply_shot(Vector3.UP, false)
	await physics_frame
	_check("ball_impulse_strength_positive", impulse > 0.0, "ball shot impulse should be positive")
	_check("ball_impulse_changes_velocity", ball.linear_velocity.y > before_velocity.y, "upward shot should increase upward velocity")

func _run_ball_shot_hit_area(arena) -> void:
	arena.set_red_bot_enabled(false)
	var player = arena.get_player(GAME_CONFIG_SCRIPT.TEAM_ONE)
	var ball = arena.get_ball(GAME_CONFIG_SCRIPT.TEAM_TWO)
	ball.global_position = Vector3(0.0, 5.0, 0.0)
	ball.linear_velocity = Vector3.ZERO
	await physics_frame
	var shot_area := ball.get_node_or_null("ShotHitArea") as Area3D
	var shot_shape: CollisionShape3D = null
	if shot_area != null:
		shot_shape = shot_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var sphere_shape: SphereShape3D = null
	if shot_shape != null:
		sphere_shape = shot_shape.shape as SphereShape3D
	_check("ball_has_enlarged_shot_area", sphere_shape != null and sphere_shape.radius > ball.visible_radius, "ball should include an invisible shot area larger than its visible radius")
	var weapon = player.weapon
	var origin := Vector3(ball.visible_radius + 0.25, ball.global_position.y, -5.0)
	var direction := Vector3(0.0, 0.0, 1.0)
	var result: Dictionary = weapon._resolve_shot(origin, direction, player)
	var hit_position: Vector3 = result.get("hit_position", Vector3.ZERO)
	_check("near_miss_hits_enlarged_ball_target", result.get("hit_node") == ball, "a shot outside the visible ball radius but inside the shot area should hit the ball")
	_check("near_miss_would_miss_visible_ball", hit_position.distance_to(ball.global_position) > ball.visible_radius, "test shot should land outside the visible ball radius")

func _run_arena_contains_upward_ball(arena) -> void:
	arena.set_red_bot_enabled(false)
	var ball = arena.get_ball(GAME_CONFIG_SCRIPT.TEAM_TWO)
	ball.global_position = Vector3(0.0, arena.dome_height - 1.4, 0.0)
	ball.linear_velocity = Vector3.UP * 38.0
	ball.angular_velocity = Vector3.ZERO
	for _frame in range(30):
		await physics_frame
	_check("arena_top_cap_contains_ball", ball.global_position.y <= arena.dome_height - ball.visible_radius * 0.35, "top cap should keep a strongly upward ball inside the arena")

func _run_actual_dome_smoke(arena) -> void:
	var dome = arena.get_node_or_null("Dome")
	_check("actual_dome_exists", dome != null, "arena should include a generated dome node")
	_check("actual_dome_is_collision_body", dome is StaticBody3D, "dome should be a StaticBody3D collision surface")
	_check("actual_dome_in_groups", dome != null and dome.is_in_group(GAME_CONFIG_SCRIPT.DOME_GROUP) and dome.is_in_group(GAME_CONFIG_SCRIPT.WALL_GROUP), "dome should be both ricochet and wall collision geometry")
	_check("actual_dome_has_mesh", dome != null and dome.get_node_or_null("MeshInstance3D") != null, "dome should have visible mesh geometry")
	_check("actual_dome_has_collision", dome != null and dome.get_node_or_null("CollisionShape3D") != null, "dome should have collision geometry")
	_check("arena_has_cylinder_visual", dome != null and dome.get_node_or_null("CylinderWallVisual") != null, "arena should visibly read as a cylinder wall")
	_check("arena_has_frustum_visual", dome != null and dome.get_node_or_null("FrustumRoofVisual") != null, "arena should visibly read as a truncated cone/frustum roof")
	_check("arena_has_seam_ring", arena.get_node_or_null("CylinderFrustumSeam") != null, "arena should show the cylinder-to-frustum seam")
	_check("arena_has_top_cap_ring", arena.get_node_or_null("TopCapRing") != null, "arena should show the capped top ring")
	_check("spring_trap_covers_cap", arena.spring_trap != null and arena.spring_trap.covers_cap, "spring trap should cover the flat top cap")
	_check("spring_trap_has_cap_visual", arena.spring_trap != null and arena.spring_trap.get_node_or_null("MeshInstance3D") != null, "spring trap should have a cap-sized visual")
	var trap_mesh: MeshInstance3D = null
	if arena.spring_trap != null:
		trap_mesh = arena.spring_trap.get_node_or_null("MeshInstance3D") as MeshInstance3D
	var trap_material: StandardMaterial3D = null
	if trap_mesh != null:
		trap_material = trap_mesh.material_override as StandardMaterial3D
	_check("spring_trap_cap_visual_translucent", trap_material != null and trap_material.albedo_color.a < 0.75, "cap spring trap should be translucent instead of an opaque clipping disk")
	var wall_normal: Vector3 = arena._dome_normal_at(Vector3(arena.arena_radius, arena.cone_base_height * 0.5, 0.0))
	var cone_normal: Vector3 = arena._dome_normal_at(Vector3((arena.arena_radius + arena.cone_top_radius) * 0.5, arena.cone_base_height + 1.0, 0.0))
	_check("arena_uses_cylinder_wall_normal", absf(wall_normal.y) < 0.01, "lower arena wall should reflect like a cylinder")
	_check("arena_uses_sloped_cone_normal", cone_normal.y > 0.35, "upper arena should reflect from a constant sloped cone surface")
	_check("arena_frustum_incline_30_degrees", absf(arena.get_frustum_incline_degrees() - 30.0) < 0.2, "frustum roof incline should be 30 degrees")
	_check("arena_frustum_reduced_footprint", arena.cone_top_radius >= arena.arena_radius * 0.45, "frustum should be smaller and less apex-like than the previous oversized cone")
	var weapon = arena.get_player(GAME_CONFIG_SCRIPT.TEAM_ONE).weapon
	var top_result: Dictionary = weapon._raycast_result(Vector3(0.0, arena.dome_height - 1.4, 0.0), Vector3.UP, arena.get_player(GAME_CONFIG_SCRIPT.TEAM_ONE))
	_check("arena_top_cap_blocks_shots", top_result.get("collider") == dome, "capped frustum top should be the first collider for upward shots instead of leaving an escape hole")

func _run_hud_smoke(arena) -> void:
	var crosshair_root := arena.get_node_or_null("HUD/CrosshairRoot") as Control
	_check("hud_has_crosshair_root", crosshair_root != null, "HUD should include centered crosshair root")
	_check("hud_crosshair_root_centered", crosshair_root != null and is_equal_approx(crosshair_root.anchor_left, 0.5) and is_equal_approx(crosshair_root.anchor_top, 0.5), "crosshair root should be anchored to viewport center")
	_check("hud_crosshair_ignores_mouse", crosshair_root != null and crosshair_root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "crosshair should not consume mouse input")
	_check("hud_has_crosshair_horizontal", arena.get_node_or_null("HUD/CrosshairRoot/CrosshairHorizontal") != null, "HUD should include horizontal crosshair")
	_check("hud_has_crosshair_vertical", arena.get_node_or_null("HUD/CrosshairRoot/CrosshairVertical") != null, "HUD should include vertical crosshair")
	_check("hud_has_ammo", arena.get_node_or_null("HUD/AmmoLabel") != null, "HUD should include ammo label")
	_check("hud_has_charged_shot_label", arena.get_node_or_null("HUD/ChargedShotLabel") != null, "HUD should include charged shot readiness label")
	_check("hud_has_bot_label", arena.get_node_or_null("HUD/BotLabel") != null, "HUD should include red bot toggle label")
	_check("hud_has_hit_marker", arena.get_node_or_null("HUD/HitMarkerLabel") != null, "HUD should include hit marker label")

func _run_mouse_camera_smoke(arena) -> void:
	var player = arena.get_player(GAME_CONFIG_SCRIPT.TEAM_ONE)
	var yaw_before: float = player.rotation.y
	var pitch_before: float = player.look_pitch
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.relative = Vector2(30.0, -18.0)
	player._input(mouse_motion)
	_check("mouse_look_changes_yaw", absf(player.rotation.y - yaw_before) > 0.001, "mouse motion should rotate active player yaw")
	_check("mouse_look_changes_pitch", absf(player.look_pitch - pitch_before) > 0.001, "mouse motion should rotate active player camera pitch")

func _run_red_bot_smoke(arena) -> void:
	_check("red_bot_toggle_action_exists", InputMap.has_action("toggle_red_bot"), "toggle_red_bot input action should exist")
	_check("red_bot_default_on", arena.red_bot_enabled, "red bot should default to enabled for manual testing")
	var toggle_event := InputEventKey.new()
	toggle_event.keycode = KEY_SPACE
	toggle_event.pressed = true
	arena._input(toggle_event)
	_check("red_bot_space_toggles_off", arena.red_bot_enabled == false, "Space should toggle red bot off")
	arena._input(toggle_event)
	_check("red_bot_space_toggles_on", arena.red_bot_enabled, "Space should toggle red bot back on")
	var red_player = arena.get_player(GAME_CONFIG_SCRIPT.TEAM_TWO)
	var red_ball = arena.get_ball(GAME_CONFIG_SCRIPT.TEAM_TWO)
	arena.set_red_bot_enabled(false)
	red_player.weapon.ammo = red_player.weapon.max_ammo
	red_player.weapon.cooldown_timer = 0.0
	red_player.weapon.final_bonus_enabled = true
	red_player.global_position = Vector3(red_ball.global_position.x, 1.2, red_ball.global_position.z)
	red_ball.global_position = Vector3(5.0, 5.0, -2.5)
	red_ball.linear_velocity = Vector3.DOWN * 4.0
	var velocity_before: float = red_ball.linear_velocity.y
	var ammo_before: int = red_player.weapon.ammo
	arena.set_red_bot_enabled(true)
	arena._update_red_bot(0.2)
	await physics_frame
	_check("red_bot_fires_to_save_ball", red_player.weapon.ammo < ammo_before, "red bot should fire when red ball is falling low")
	_check("red_bot_hits_red_ball", red_player.weapon.last_shot.get("hit_node") == red_ball, "red bot shot should target the red ball")
	_check("red_bot_adds_upward_velocity", red_ball.linear_velocity.y > velocity_before, "red bot should add upward velocity to red ball")
	arena.set_red_bot_enabled(false)

func _run_ball_spawn_tuning(arena) -> void:
	var ball = arena.get_ball(GAME_CONFIG_SCRIPT.TEAM_ONE)
	ball.reset_ball()
	var spawn_y: float = ball.spawn_position.y
	for _frame in range(60):
		await physics_frame
	_check("ball_spawn_is_higher", spawn_y >= 9.0, "balls should spawn higher than the first manual prototype")
	_check("ball_fall_is_slowed", ball.global_position.y > spawn_y - 3.0, "ball should fall slowly enough to stay readable for one second")
	_check("ball_gravity_tuned_down", ball.gravity_scale <= 0.15, "ball gravity scale should be in the very-low-gravity range")
	_check("ball_linear_damping_high", ball.linear_damp >= 0.18, "ball linear damping should be high enough to reduce chaotic arcs")

func _run_ground_score(arena) -> void:
	var red_score_before: int = arena.match_manager.get_score(GAME_CONFIG_SCRIPT.TEAM_TWO)
	arena.match_manager.register_ball_grounded(GAME_CONFIG_SCRIPT.TEAM_ONE)
	_check("ground_score_opponent_point", arena.match_manager.get_score(GAME_CONFIG_SCRIPT.TEAM_TWO) == red_score_before + 1, "red should score when blue ball falls")
	_check("ground_score_resets_point", arena.point_reset_count >= 1, "point reset should run after score")

func _run_floor_threshold_score(arena) -> void:
	var ball = arena.get_ball(GAME_CONFIG_SCRIPT.TEAM_ONE)
	var red_score_before: int = arena.match_manager.get_score(GAME_CONFIG_SCRIPT.TEAM_TWO)
	ball.global_position = Vector3(-2.0, arena.ball_floor_loss_y - 0.1, 0.0)
	ball.linear_velocity = Vector3.ZERO
	await physics_frame
	arena._check_ball_floor_loss()
	_check("floor_threshold_scores", arena.match_manager.get_score(GAME_CONFIG_SCRIPT.TEAM_TWO) == red_score_before + 1, "ball at floor-loss height should score and reset")
	_check("floor_threshold_resets_ball_high", ball.global_position.y >= ball.spawn_position.y - 0.1, "floor score should reset ball to high spawn")

func _run_final_shot(arena) -> void:
	var ball = arena.get_ball(GAME_CONFIG_SCRIPT.TEAM_TWO)
	var regular: float = ball.get_shot_impulse(false)
	var final: float = ball.get_shot_impulse(true)
	_check("final_shot_stronger", final > regular, "final shot impulse must be stronger than regular impulse")

func _run_early_reload(arena) -> void:
	var player = arena.get_player(GAME_CONFIG_SCRIPT.TEAM_ONE)
	var weapon = player.weapon
	weapon.ammo = 3
	weapon.final_bonus_enabled = true
	var started: bool = weapon.request_reload()
	weapon.finish_reload_for_tests()
	_check("early_reload_started", started, "early reload should start when ammo is partial")
	_check("early_reload_skips_bonus", weapon.final_bonus_enabled == false, "early reload should remove immediate final-shot bonus")
	_check("early_reload_refills_ammo", weapon.ammo == weapon.max_ammo, "early reload should refill ammo")

func _run_auto_reload_and_charged_visual(arena) -> void:
	var player = arena.get_player(GAME_CONFIG_SCRIPT.TEAM_ONE)
	var target_ball = arena.get_ball(GAME_CONFIG_SCRIPT.TEAM_TWO)
	var weapon = player.weapon
	weapon.ammo = 1
	weapon.final_bonus_enabled = true
	weapon.is_reloading = false
	weapon.reload_timer = 0.0
	weapon.cooldown_timer = 0.0
	target_ball.reset_ball()
	arena._update_hud()
	var charged_label := arena.get_node_or_null("HUD/ChargedShotLabel") as Label
	_check("charged_shot_ready_indicator_visible", charged_label != null and charged_label.text.contains("CHARGED"), "HUD should visibly indicate when the charged shot is ready")
	var path_before: int = arena.shot_path_count
	var origin: Vector3 = player.camera.global_position
	var direction: Vector3 = (target_ball.global_position - origin).normalized()
	var fired: bool = weapon.try_fire(origin, direction, player)
	await physics_frame
	_check("final_shot_fires", fired and weapon.last_shot.get("is_final_shot", false), "weapon should fire the charged final shot")
	_check("empty_weapon_auto_reloads", weapon.is_reloading and weapon.ammo == 0, "weapon should automatically start reloading when the final round empties it")
	_check("charged_shot_path_visual_created", arena.shot_path_count > path_before, "charged shot should create a shot path")
	_check("charged_shot_path_marked_unique", _has_charged_feedback_node(arena), "charged shot path should be uniquely marked for visual styling")
	_check("charged_shot_feedback_label", arena.hit_marker_label != null and arena.hit_marker_label.text.contains("FINAL"), "hit feedback should identify the charged shot")
	weapon.finish_reload_for_tests()

func _run_shot_feedback(arena) -> void:
	var player = arena.get_player(GAME_CONFIG_SCRIPT.TEAM_ONE)
	var target_ball = arena.get_ball(GAME_CONFIG_SCRIPT.TEAM_TWO)
	var weapon = player.weapon
	weapon.ammo = weapon.max_ammo
	weapon.cooldown_timer = 0.0
	target_ball.reset_ball()
	await physics_frame
	var feedback_before: int = arena.shot_feedback_count
	var path_before: int = arena.shot_path_count
	var origin: Vector3 = player.camera.global_position
	var direction: Vector3 = (target_ball.global_position - origin).normalized()
	var fired: bool = weapon.try_fire(origin, direction, player)
	await physics_frame
	_check("shot_feedback_fires", fired, "weapon should fire in feedback scenario")
	_check("shot_feedback_created", arena.shot_feedback_count > feedback_before, "shot feedback should be created after firing")
	_check("shot_path_visual_created", arena.shot_path_count > path_before, "shot path visual should be created after firing")
	_check("shot_feedback_hit_label", arena.hit_marker_label != null and arena.hit_marker_label.text.contains("HIT"), "hit marker should report a hit")
	_check("shot_path_debug_segment", weapon.last_shot.get("path_segments", []).size() >= 1, "last shot should record at least one path segment")
	var path_segments: Array = weapon.last_shot.get("path_segments", [])
	var first_segment_origin := Vector3(99999.0, 99999.0, 99999.0)
	if path_segments.size() > 0:
		first_segment_origin = path_segments[0].get("from", first_segment_origin)
	_check("shot_origin_matches_camera_crosshair", path_segments.size() > 0 and first_segment_origin.distance_to(player.camera.global_position) < 0.02, "shot ray should originate at the camera center behind the crosshair")
	var active_feedback_before_fade: int = arena.get_debug_state().get("active_shot_feedback_nodes", 0)
	for _frame in range(70):
		await process_frame
	arena._update_shot_feedback_lifetimes(maxf(arena.shot_path_lifetime, arena.hit_marker_lifetime) + 0.1)
	await process_frame
	await process_frame
	_check("shot_path_fades_and_disappears", arena.get_debug_state().get("active_shot_feedback_nodes", 0) < active_feedback_before_fade, "shot path and hit feedback should fade and remove themselves")

func _run_ricochet_shot(arena) -> void:
	var player = arena.get_player(GAME_CONFIG_SCRIPT.TEAM_ONE)
	var ball = arena.get_ball(GAME_CONFIG_SCRIPT.TEAM_TWO)
	var weapon = player.weapon
	weapon.ammo = weapon.max_ammo
	weapon.cooldown_timer = 0.0
	var origin := Vector3(0.0, 2.2, 8.0)
	player.global_position = origin - Vector3(0.0, 0.65, 0.0)
	var setup := await _find_ricochet_setup(arena, weapon, player, ball, origin)
	if setup.is_empty():
		_check("ricochet_setup_found", false, "could not find deterministic dome ricochet setup")
		return
	var direction: Vector3 = setup.get("direction", Vector3.FORWARD)
	var feedback_before: int = arena.shot_feedback_count
	var path_before: int = arena.shot_path_count
	arena.spring_trap.current_charge = 0.0
	var fired: bool = weapon.try_fire(origin, direction, player)
	await physics_frame
	_check("ricochet_setup_found", true, "deterministic dome ricochet setup found")
	_check("ricochet_weapon_fired", fired, "weapon should fire ricochet scenario")
	_check("ricochet_count_one", weapon.last_shot.get("ricochet_count", 0) == 1, "shot should ricochet exactly once")
	_check("ricochet_hits_ball", weapon.last_shot.get("hit_node") == ball, "ricochet should hit the target ball")
	_check("ricochet_has_two_path_segments", weapon.last_shot.get("path_segments", []).size() >= 2, "ricochet should draw pre- and post-bounce path segments")
	_check("ricochet_shot_feedback_created", arena.shot_feedback_count > feedback_before, "ricochet should create hit feedback")
	_check("ricochet_path_visual_created", arena.shot_path_count > path_before, "ricochet should create path visual")
	var bank_feedback_nodes := _get_bank_feedback_nodes(arena)
	_check("ricochet_feedback_marked_bank", bank_feedback_nodes.size() >= 2, "ricochet feedback nodes should be marked as bank-shot visuals")
	_check("ricochet_feedback_lasts_longer", _bank_feedback_lasts_longer(bank_feedback_nodes, arena.shot_path_lifetime), "bank-shot path feedback should last longer than direct shot feedback")
	_check("frustum_ricochet_does_not_charge_spring_trap", arena.spring_trap.current_charge == 0.0, "shooting the frustum roof should ricochet without charging the cap spring trap")
	weapon.cooldown_timer = 0.0
	var cap_charge_before: float = arena.spring_trap.current_charge
	var cap_fired: bool = weapon.try_fire(Vector3(0.0, arena.dome_height - 1.4, 0.0), Vector3.UP, player)
	await physics_frame
	_check("cap_shot_charges_spring_trap", cap_fired and arena.spring_trap.current_charge > cap_charge_before, "shooting the top cap should charge the spring trap")

func _run_floor_ricochet_shot(arena) -> void:
	var player = arena.get_player(GAME_CONFIG_SCRIPT.TEAM_ONE)
	var floor = arena.get_node_or_null("Floor")
	var weapon = player.weapon
	weapon.ammo = weapon.max_ammo
	weapon.cooldown_timer = 0.0
	arena.spring_trap.current_charge = 0.0
	var feedback_before: int = arena.shot_feedback_count
	var path_before: int = arena.shot_path_count
	var origin := Vector3(0.0, 4.0, 0.0)
	var fired: bool = weapon.try_fire(origin, Vector3.DOWN, player)
	await physics_frame
	var path_segments: Array = weapon.last_shot.get("path_segments", [])
	var first_hit := Vector3(99999.0, 99999.0, 99999.0)
	if path_segments.size() > 0:
		first_hit = path_segments[0].get("to", first_hit)
	_check("floor_is_ricochet_surface", floor != null and floor.is_in_group(GAME_CONFIG_SCRIPT.DOME_GROUP), "floor should be marked as a ricochet surface")
	_check("floor_ricochet_weapon_fired", fired, "weapon should fire floor ricochet scenario")
	_check("floor_ricochet_count_one", weapon.last_shot.get("ricochet_count", 0) == 1, "downward shot should ricochet once off the floor")
	_check("floor_ricochet_first_hit_floor_height", first_hit.y <= arena.floor_y + 0.2, "floor ricochet should hit the physical floor, not the ground-loss trigger")
	_check("floor_ricochet_has_two_path_segments", path_segments.size() >= 2, "floor ricochet should draw pre- and post-bounce path segments")
	_check("floor_ricochet_feedback_created", arena.shot_feedback_count > feedback_before, "floor ricochet should create hit feedback")
	_check("floor_ricochet_path_visual_created", arena.shot_path_count > path_before, "floor ricochet should create path visual")
	_check("floor_ricochet_does_not_charge_cap_trap", arena.spring_trap.current_charge == 0.0, "floor ricochet should not charge the cap spring trap")

func _find_ricochet_setup(arena, weapon, player, ball, origin: Vector3) -> Dictionary:
	var cone_steps := [0.12, 0.22, 0.32, 0.42, 0.52, 0.62, 0.72, 0.82]
	for cone_t in cone_steps:
		for segment in range(48):
			var theta := TAU * float(segment) / 48.0
			var ring_radius: float = lerpf(arena.arena_radius, arena.cone_top_radius, cone_t)
			var y: float = lerpf(arena.cone_base_height, arena.dome_height, cone_t)
			var dome_point := Vector3(cos(theta) * ring_radius, y, sin(theta) * ring_radius)
			var incoming := (dome_point - origin).normalized()
			var reflected := _reflect_direction(incoming, arena._dome_normal_at(dome_point))
			var target_position := dome_point + reflected * 4.0
			var xz_distance := Vector2(target_position.x, target_position.z).length()
			if target_position.y < 2.0 or target_position.y > arena.dome_height - 1.0 or xz_distance > arena.arena_radius - 1.0:
				continue
			ball.global_position = target_position
			ball.linear_velocity = Vector3.ZERO
			await physics_frame
			var result: Dictionary = weapon._resolve_shot(origin, incoming, player)
			if result.get("ricochet_count", 0) == 1 and result.get("hit_node") == ball:
				return {"direction": incoming, "ball_position": target_position}
	return {}

func _reflect_direction(direction: Vector3, normal: Vector3) -> Vector3:
	var safe_normal := normal.normalized()
	return (direction - 2.0 * direction.dot(safe_normal) * safe_normal).normalized()

func _get_bank_feedback_nodes(arena) -> Array:
	var bank_nodes := []
	for node in arena.get_tree().get_nodes_in_group(GAME_CONFIG_SCRIPT.SHOT_FEEDBACK_GROUP):
		if node.has_meta("is_bank_shot") and bool(node.get_meta("is_bank_shot")):
			bank_nodes.append(node)
	return bank_nodes

func _has_charged_feedback_node(arena) -> bool:
	for node in arena.get_tree().get_nodes_in_group(GAME_CONFIG_SCRIPT.SHOT_FEEDBACK_GROUP):
		if node.name.begins_with("ShotPath") and node.has_meta("is_charged_shot") and bool(node.get_meta("is_charged_shot")):
			return true
	return false

func _bank_feedback_lasts_longer(bank_nodes: Array, direct_lifetime: float) -> bool:
	for node in bank_nodes:
		if node.name.begins_with("ShotPath") and float(node.get_meta("lifetime", 0.0)) > direct_lifetime:
			return true
	return false

func _run_wall_stun(arena) -> void:
	var player = arena.get_player(GAME_CONFIG_SCRIPT.TEAM_TWO)
	player.receive_shot_knockback(Vector3.RIGHT, 4.0)
	player.register_wall_impact(player.wall_stun_speed - 1.0)
	_check("wall_stun_below_threshold_ignored", player.is_stunned() == false, "low-speed wall impact should not stun")
	player.receive_shot_knockback(Vector3.RIGHT, 20.0)
	player.register_wall_impact(player.wall_stun_speed + 1.0)
	_check("wall_stun_above_threshold_applies", player.is_stunned(), "high-speed wall impact should stun")

func _run_spring_trap(arena) -> void:
	var trap = arena.spring_trap
	var ball = arena.get_ball(GAME_CONFIG_SCRIPT.TEAM_ONE)
	ball.reset_ball()
	await physics_frame
	var charge_added: float = trap.charge_from_shot(false)
	var charge_before_trigger: float = trap.current_charge
	var velocity_before: float = ball.linear_velocity.y
	var impulse: float = trap.trigger_for_ball(ball)
	await physics_frame
	_check("spring_trap_charge_increases", charge_added > 0.0 and charge_before_trigger > 0.0, "shooting trap should add charge")
	_check("spring_trap_impulse_includes_charge", impulse > trap.base_downward_impulse, "charged trap should exceed base impulse")
	_check("spring_trap_resets_charge", trap.current_charge == 0.0, "trap charge should reset after triggering")
	_check("spring_trap_pushes_down", ball.linear_velocity.y < velocity_before, "trap should add downward velocity")
	trap.current_charge = 12.0
	ball.global_position = Vector3(arena.cone_top_radius * 0.45, arena.dome_height, 0.0)
	ball.linear_velocity = Vector3.UP * 5.0
	var cap_velocity_before: float = ball.linear_velocity.y
	arena._check_spring_trap_cap_contact(ball)
	await physics_frame
	_check("cap_spring_trap_resets_charge", trap.current_charge == 0.0, "cap spring trap should reset charge when a ball touches the cap")
	_check("cap_spring_trap_pushes_down", ball.linear_velocity.y < cap_velocity_before, "cap spring trap should push balls downward from the top cap")

func _capture_screenshot(screenshot_name: String, arena) -> void:
	arena.use_overview_camera()
	root.size = SCREENSHOT_SIZE
	await process_frame
	await physics_frame
	var image := root.get_texture().get_image()
	var nonblank := _image_has_nonblank_pixels(image)
	var has_blue := _image_has_color(image, Color(0.2, 0.55, 1.0, 1.0), 0.46)
	var has_red := _image_has_color(image, Color(1.0, 0.22, 0.16, 1.0), 0.85)
	var has_trap_yellow := _image_has_color(image, Color(0.75, 0.68, 0.25, 1.0), 0.75)
	var path := "%s/%s.png" % [SCREENSHOT_DIR, screenshot_name]
	var save_error := image.save_png(path)
	results["screenshots"].append(path)
	_check("%s_nonblank" % screenshot_name, nonblank, "screenshot should contain visible pixels")
	_check("%s_has_blue_team" % screenshot_name, has_blue, "screenshot should show blue team object")
	_check("%s_has_red_team" % screenshot_name, has_red, "screenshot should show red team object")
	_check("%s_has_trap" % screenshot_name, has_trap_yellow, "screenshot should show spring trap")
	_check("%s_saved" % screenshot_name, save_error == OK, "screenshot should save to disk")
	_check("%s_has_debug_state" % screenshot_name, arena.get_debug_state().has("balls"), "arena debug state should be available")

func _image_has_nonblank_pixels(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var width := image.get_width()
	var height := image.get_height()
	var sample_step := maxi(1, width / 32)
	var varied_pixels := 0
	var first_color := image.get_pixel(0, 0)
	for y in range(0, height, sample_step):
		for x in range(0, width, sample_step):
			var sample_color := image.get_pixel(x, y)
			var color_delta := absf(sample_color.r - first_color.r) + absf(sample_color.g - first_color.g) + absf(sample_color.b - first_color.b)
			if color_delta > 0.02:
				varied_pixels += 1
				if varied_pixels > 4:
					return true
	return false

func _image_has_color(image: Image, target_color: Color, tolerance: float) -> bool:
	if image == null or image.is_empty():
		return false
	var width := image.get_width()
	var height := image.get_height()
	var sample_step := maxi(1, width / 160)
	var matching_pixels := 0
	for y in range(0, height, sample_step):
		for x in range(0, width, sample_step):
			var sample_color := image.get_pixel(x, y)
			var delta := absf(sample_color.r - target_color.r) + absf(sample_color.g - target_color.g) + absf(sample_color.b - target_color.b)
			if delta <= tolerance:
				matching_pixels += 1
				if matching_pixels >= 1:
					return true
	return false

func _check(check_name: String, passed: bool, detail: String) -> void:
	results["checks"].append({
		"name": check_name,
		"passed": passed,
		"detail": detail
	})
	if passed == false:
		results["ok"] = false
		printerr("FAIL: %s - %s" % [check_name, detail])
	else:
		print("PASS: %s" % check_name)

func _write_results(arena) -> void:
	results["arena"] = arena.get_debug_state()
	var result_file := FileAccess.open("%s/latest.json" % RESULT_DIR, FileAccess.WRITE)
	if result_file == null:
		results["ok"] = false
		printerr("FAIL: could not open result file")
		return
	result_file.store_string(JSON.stringify(results, "\t"))
	result_file.close()

func _ensure_output_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESULT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCREENSHOT_DIR))
