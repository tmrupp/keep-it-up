extends Node
class_name ShotResolver

const GameConfig := preload("res://scripts/game_config.gd")

func resolve(origin: Vector3, direction: Vector3, owner_player: Node, shot_range: float, max_ricochets: int, ricochet_origin_offset: float) -> Dictionary:
	var current_origin := origin
	var current_direction := direction.normalized()
	var ricochet_count := 0
	var path_segments: Array = []
	for _shot_segment in range(max_ricochets + 1):
		var result := raycast_result(current_origin, current_direction, owner_player, shot_range)
		if result.is_empty():
			var end_position := current_origin + current_direction * shot_range
			path_segments.append({"from": current_origin, "to": end_position})
			return {
				"hit_node": null,
				"hit_direction": current_direction,
				"hit_position": end_position,
				"ricochet_count": ricochet_count,
				"path_segments": path_segments
			}
		var collider := get_effective_hit_node(result.get("collider") as Node)
		var hit_position: Vector3 = result.get("position", current_origin)
		var hit_normal: Vector3 = result.get("normal", Vector3.UP)
		path_segments.append({"from": current_origin, "to": hit_position})
		if collider != null and is_ricochet_surface(collider) and ricochet_count < max_ricochets:
			ricochet_count += 1
			current_direction = reflect_direction(current_direction, hit_normal)
			current_origin = hit_position + current_direction * ricochet_origin_offset
			continue
		return {
			"hit_node": collider,
			"hit_direction": current_direction,
			"hit_position": hit_position,
			"ricochet_count": ricochet_count,
			"path_segments": path_segments
		}
	return {
		"hit_node": null,
		"hit_direction": current_direction,
		"hit_position": current_origin + current_direction * shot_range,
		"ricochet_count": ricochet_count,
		"path_segments": path_segments
	}

func raycast_result(origin: Vector3, direction: Vector3, owner_player: Node, shot_range: float) -> Dictionary:
	var world := get_viewport().world_3d
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * shot_range)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if owner_player is CollisionObject3D:
		query.exclude = [owner_player.get_rid()]
	return world.direct_space_state.intersect_ray(query)

func is_ricochet_surface(node: Node) -> bool:
	return node != null and node.is_in_group(GameConfig.DOME_GROUP)

func get_effective_hit_node(node: Node) -> Node:
	if node == null:
		return null
	if node.has_meta("shot_target_node"):
		var target = node.get_meta("shot_target_node")
		if target is Node:
			return target
	return node

func reflect_direction(direction: Vector3, normal: Vector3) -> Vector3:
	var safe_normal := normal.normalized()
	if safe_normal == Vector3.ZERO:
		return direction.normalized()
	return (direction - 2.0 * direction.dot(safe_normal) * safe_normal).normalized()