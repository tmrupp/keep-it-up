extends Node
class_name KeeperBotController

signal enabled_changed(enabled: bool)

@export var enabled := true
@export var reaction_height := 8.5
@export var min_fall_speed := -0.25
@export var move_speed := 7.0

var player: Node
var ball: Node

func setup(new_player: Node, new_ball: Node) -> void:
	player = new_player
	ball = new_ball

func set_enabled(new_enabled: bool) -> void:
	if enabled == new_enabled:
		return
	enabled = new_enabled
	enabled_changed.emit(enabled)

func is_enabled() -> bool:
	return enabled

func update_bot(delta: float) -> void:
	if enabled == false:
		return
	if player == null or ball == null or player.weapon == null:
		return
	_move_under_ball(delta)
	if player.weapon.ammo <= 0:
		player.weapon.request_reload()
		return
	var ball_needs_help: bool = ball.global_position.y < reaction_height or ball.linear_velocity.y <= min_fall_speed
	if ball_needs_help == false or player.weapon.can_fire() == false:
		return
	var origin: Vector3 = player.camera.global_position
	var direction: Vector3 = (ball.global_position - origin).normalized()
	player.weapon.try_fire(origin, direction, player)

func get_debug_state() -> Dictionary:
	return {
		"enabled": enabled,
		"reaction_height": reaction_height,
		"min_fall_speed": min_fall_speed,
		"move_speed": move_speed,
		"has_player": player != null,
		"has_ball": ball != null
	}

func _move_under_ball(delta: float) -> void:
	var target_position := Vector3(ball.global_position.x, player.global_position.y, ball.global_position.z)
	player.global_position = player.global_position.move_toward(target_position, move_speed * delta)
	var look_direction: Vector3 = ball.global_position - player.global_position
	look_direction.y = 0.0
	if look_direction.length() > 0.01:
		player.rotation.y = atan2(-look_direction.x, -look_direction.z)