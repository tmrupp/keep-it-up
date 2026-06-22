extends Area3D
class_name GroundLossMonitor

const TeamBall := preload("res://scripts/team_ball.gd")

signal ball_grounded(team_id: int, ball: Node)

@export var arena_radius := 16.0
@export var loss_y := 0.65

var last_grounded_team := 0

func setup(new_arena_radius: float, new_loss_y: float) -> void:
	arena_radius = new_arena_radius
	loss_y = new_loss_y
	name = "GroundLossArea"
	position = Vector3(0.0, loss_y, 0.0)
	collision_layer = 0
	_build_collision()
	body_entered.connect(_on_body_entered)

func reset_for_point() -> void:
	last_grounded_team = 0

func force_check(balls: Array) -> void:
	if last_grounded_team != 0:
		return
	for ball in balls:
		if ball != null and ball.get_script() == TeamBall and ball.global_position.y <= loss_y:
			_emit_ball_grounded(ball)
			return

func get_debug_state() -> Dictionary:
	return {
		"last_grounded_team": last_grounded_team,
		"loss_y": loss_y,
		"arena_radius": arena_radius
	}

func _build_collision() -> void:
	if has_node("CollisionShape3D"):
		return
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = arena_radius * 0.96
	shape.height = 0.2
	collision.shape = shape
	add_child(collision)

func _on_body_entered(body: Node) -> void:
	if body != null and body.get_script() == TeamBall and last_grounded_team == 0:
		_emit_ball_grounded(body)

func _emit_ball_grounded(ball: Node) -> void:
	last_grounded_team = ball.team_id
	ball_grounded.emit(ball.team_id, ball)