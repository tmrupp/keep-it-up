extends RefCounted
class_name GameConfig

const TEAM_ONE := 1
const TEAM_TWO := 2
const PLAYER_GROUP := "players"
const BALL_GROUP := "team_balls"
const WALL_GROUP := "arena_walls"
const DOME_GROUP := "arena_dome"
const SHOT_TARGET_GROUP := "shot_targets"
const SHOT_FEEDBACK_GROUP := "shot_feedback"

static func opponent_team(team_id: int) -> int:
	return TEAM_TWO if team_id == TEAM_ONE else TEAM_ONE

static func team_color(team_id: int) -> Color:
	if team_id == TEAM_ONE:
		return Color(0.2, 0.55, 1.0, 1.0)
	return Color(1.0, 0.22, 0.16, 1.0)

static func team_name(team_id: int) -> String:
	return "Blue" if team_id == TEAM_ONE else "Red"
