extends Node
class_name SpawnRegistry

const GameConfig := preload("res://scripts/game_config.gd")

@export var player_one_spawn := Vector3(-5.0, 1.2, 5.0)
@export var player_two_spawn := Vector3(5.0, 1.2, -5.0)
@export var ball_one_spawn := Vector3(-5.0, 9.5, 2.5)
@export var ball_two_spawn := Vector3(5.0, 9.5, -2.5)

func setup(new_player_one_spawn: Vector3, new_player_two_spawn: Vector3, new_ball_one_spawn: Vector3, new_ball_two_spawn: Vector3) -> void:
	player_one_spawn = new_player_one_spawn
	player_two_spawn = new_player_two_spawn
	ball_one_spawn = new_ball_one_spawn
	ball_two_spawn = new_ball_two_spawn

func add_markers(parent_node: Node) -> void:
	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	parent_node.add_child(spawn_points)
	_create_marker(spawn_points, "PlayerBlueSpawn", player_one_spawn)
	_create_marker(spawn_points, "PlayerRedSpawn", player_two_spawn)
	_create_marker(spawn_points, "BallBlueSpawn", ball_one_spawn)
	_create_marker(spawn_points, "BallRedSpawn", ball_two_spawn)

func get_player_spawn(team_id: int) -> Vector3:
	return player_one_spawn if team_id == GameConfig.TEAM_ONE else player_two_spawn

func get_ball_spawn(team_id: int) -> Vector3:
	return ball_one_spawn if team_id == GameConfig.TEAM_ONE else ball_two_spawn

func get_debug_state() -> Dictionary:
	return {
		"player_one_spawn": _vector_to_array(player_one_spawn),
		"player_two_spawn": _vector_to_array(player_two_spawn),
		"ball_one_spawn": _vector_to_array(ball_one_spawn),
		"ball_two_spawn": _vector_to_array(ball_two_spawn)
	}

func _create_marker(parent_node: Node, marker_name: String, marker_position: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = marker_position
	parent_node.add_child(marker)

func _vector_to_array(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]