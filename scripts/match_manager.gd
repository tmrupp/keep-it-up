extends Node
class_name MatchManager

const GameConfig := preload("res://scripts/game_config.gd")

signal score_changed(scores: Dictionary)
signal point_reset
signal match_finished(winning_team_id: int)

@export var target_score := 5
@export var reset_delay := 0.8

var scores := {
	GameConfig.TEAM_ONE: 0,
	GameConfig.TEAM_TWO: 0
}
var arena: Node = null
var reset_target: Node = null
var match_over := false

func setup(new_arena: Node) -> void:
	arena = new_arena
	_emit_score()

func set_reset_target(new_reset_target: Node) -> void:
	reset_target = new_reset_target

func register_ball_grounded(fallen_team_id: int) -> void:
	if match_over:
		return
	var scoring_team := GameConfig.opponent_team(fallen_team_id)
	scores[scoring_team] += 1
	_emit_score()
	if scores[scoring_team] >= target_score:
		match_over = true
		match_finished.emit(scoring_team)
		return
	if reset_delay <= 0.0:
		reset_point_now()
	else:
		await get_tree().create_timer(reset_delay).timeout
		reset_point_now()

func reset_match() -> void:
	scores[GameConfig.TEAM_ONE] = 0
	scores[GameConfig.TEAM_TWO] = 0
	match_over = false
	reset_point_now()
	_emit_score()

func reset_point_now() -> void:
	if reset_target != null and reset_target.has_method("reset_point"):
		reset_target.reset_point()
	elif arena != null and arena.has_method("reset_point"):
		arena.reset_point()
	point_reset.emit()

func get_score(team_id: int) -> int:
	return int(scores.get(team_id, 0))

func get_debug_state() -> Dictionary:
	return {
		"team_one": get_score(GameConfig.TEAM_ONE),
		"team_two": get_score(GameConfig.TEAM_TWO),
		"target_score": target_score,
		"match_over": match_over
	}

func _emit_score() -> void:
	score_changed.emit(scores.duplicate())
