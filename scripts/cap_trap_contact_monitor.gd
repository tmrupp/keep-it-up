extends Node
class_name CapTrapContactMonitor

const TeamBall := preload("res://scripts/team_ball.gd")

signal trap_triggered(ball: Node, impulse_strength: float)

@export var contact_cooldown := 0.28
@export var min_upward_speed := 0.05

var spring_trap: Node
var arena_geometry: Node
var contact_cooldowns := {}

func setup(new_spring_trap: Node, new_arena_geometry: Node) -> void:
	spring_trap = new_spring_trap
	arena_geometry = new_arena_geometry

func update_cooldowns(delta: float) -> void:
	var expired_ids := []
	for instance_id in contact_cooldowns.keys():
		var remaining_time: float = float(contact_cooldowns[instance_id]) - delta
		if remaining_time <= 0.0:
			expired_ids.append(instance_id)
		else:
			contact_cooldowns[instance_id] = remaining_time
	for instance_id in expired_ids:
		contact_cooldowns.erase(instance_id)

func check_all(balls: Array) -> void:
	for ball in balls:
		check_ball(ball)

func check_ball(ball: Node) -> void:
	if spring_trap == null or arena_geometry == null or ball == null or ball.get_script() != TeamBall:
		return
	if contact_cooldowns.has(ball.get_instance_id()):
		return
	if arena_geometry.is_point_on_cap(ball.global_position, ball.visible_radius) and ball.linear_velocity.y > min_upward_speed:
		var impulse_strength: float = spring_trap.trigger_for_ball(ball)
		contact_cooldowns[ball.get_instance_id()] = contact_cooldown
		trap_triggered.emit(ball, impulse_strength)

func reset_for_point() -> void:
	contact_cooldowns.clear()

func get_debug_state() -> Dictionary:
	return {
		"contact_cooldown": contact_cooldown,
		"min_upward_speed": min_upward_speed,
		"active_cooldowns": contact_cooldowns.size(),
		"has_trap": spring_trap != null,
		"has_geometry": arena_geometry != null
	}
