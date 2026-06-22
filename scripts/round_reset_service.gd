extends Node
class_name RoundResetService

signal point_reset_completed

var players: Array = []
var balls: Array = []
var spring_trap: Node
var spawn_registry: Node
var reset_hooks: Array = []
var point_reset_count := 0

func setup(new_players: Array, new_balls: Array, new_spring_trap: Node, new_spawn_registry: Node) -> void:
	players = new_players
	balls = new_balls
	spring_trap = new_spring_trap
	spawn_registry = new_spawn_registry

func add_reset_hook(hook_owner: Node, method_name: String) -> void:
	reset_hooks.append({"owner": hook_owner, "method_name": method_name})

func reset_point() -> void:
	point_reset_count += 1
	for player in players:
		if player == null:
			continue
		var spawn_position: Vector3 = spawn_registry.get_player_spawn(player.team_id) if spawn_registry != null else player.global_position
		player.reset_for_point(spawn_position)
	for ball in balls:
		if ball != null:
			ball.reset_for_point()
	if spring_trap != null and spring_trap.has_method("reset_charge"):
		spring_trap.reset_charge()
	for hook in reset_hooks:
		var hook_owner = hook.get("owner") as Node
		var method_name: String = hook.get("method_name", "")
		if hook_owner != null and method_name != "" and hook_owner.has_method(method_name):
			hook_owner.call(method_name)
	point_reset_completed.emit()

func get_debug_state() -> Dictionary:
	return {
		"point_reset_count": point_reset_count,
		"players": players.size(),
		"balls": balls.size(),
		"has_trap": spring_trap != null,
		"has_spawn_registry": spawn_registry != null
	}