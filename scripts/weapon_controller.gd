extends Node
class_name WeaponController

const GameConfig := preload("res://scripts/game_config.gd")
const ShotResolver := preload("res://scripts/shot_resolver.gd")

signal ammo_changed(ammo: int, final_bonus_enabled: bool, is_reloading: bool)
signal shot_fired(hit_node: Node, is_final_shot: bool, impulse_strength: float, ricochet_count: int, hit_position: Vector3, path_segments: Array)

@export var max_ammo := 6
@export var fire_cooldown := 0.22
@export var reload_duration := 0.8
@export var shot_range := 90.0
@export var player_knockback := 10.0
@export var final_player_knockback_multiplier := 1.75
@export var max_ricochets := 1
@export var ricochet_origin_offset := 0.08
@export var auto_reload_when_empty := true

var ammo := 6
var final_bonus_enabled := true
var is_reloading := false
var reload_timer := 0.0
var cooldown_timer := 0.0
var last_shot: Dictionary = {}
var shot_resolver

func _ready() -> void:
	ammo = max_ammo
	_ensure_shot_resolver()
	_emit_ammo_changed()

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(0.0, cooldown_timer - delta)
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload(false)

func can_fire() -> bool:
	return ammo > 0 and is_reloading == false and cooldown_timer <= 0.0

func try_fire_from_camera(camera: Camera3D, owner_player: Node) -> bool:
	if camera == null:
		return false
	return try_fire(camera.global_position, -camera.global_transform.basis.z, owner_player)

func try_fire(origin: Vector3, direction: Vector3, owner_player: Node) -> bool:
	if can_fire() == false:
		return false
	var normalized_direction := direction.normalized()
	var is_final_shot := ammo == 1 and final_bonus_enabled
	ammo -= 1
	cooldown_timer = fire_cooldown
	var shot_result := _resolve_shot(origin, normalized_direction, owner_player)
	var hit_node := _get_effective_hit_node(shot_result.get("hit_node") as Node)
	var hit_direction: Vector3 = shot_result.get("hit_direction", normalized_direction)
	var ricochet_count: int = shot_result.get("ricochet_count", 0)
	var hit_position: Vector3 = shot_result.get("hit_position", origin + normalized_direction * shot_range)
	var path_segments: Array = shot_result.get("path_segments", [])
	var impulse_strength := 0.0
	if hit_node != null:
		impulse_strength = _apply_hit(hit_node, hit_direction, is_final_shot)
	last_shot = {
		"hit_node": hit_node,
		"hit_node_name": hit_node.name if hit_node != null else "",
		"hit_direction": hit_direction,
		"hit_position": hit_position,
		"path_segments": path_segments,
		"is_final_shot": is_final_shot,
		"impulse_strength": impulse_strength,
		"ricochet_count": ricochet_count
	}
	shot_fired.emit(hit_node, is_final_shot, impulse_strength, ricochet_count, hit_position, path_segments)
	if auto_reload_when_empty and ammo <= 0:
		request_reload()
	else:
		_emit_ammo_changed()
	return true

func request_reload() -> bool:
	if is_reloading or ammo == max_ammo:
		return false
	if ammo > 0:
		final_bonus_enabled = false
	is_reloading = true
	reload_timer = reload_duration
	_emit_ammo_changed()
	return true

func finish_reload_for_tests() -> void:
	_finish_reload(false)

func get_player_knockback(is_final_shot: bool) -> float:
	return player_knockback * (final_player_knockback_multiplier if is_final_shot else 1.0)

func preview_shot(origin: Vector3, direction: Vector3, owner_player: Node) -> Dictionary:
	return _resolve_shot(origin, direction.normalized(), owner_player)

func preview_raycast(origin: Vector3, direction: Vector3, owner_player: Node) -> Dictionary:
	return _raycast_result(origin, direction.normalized(), owner_player)

func get_debug_state() -> Dictionary:
	return {
		"ammo": ammo,
		"max_ammo": max_ammo,
		"final_bonus_enabled": final_bonus_enabled,
		"is_reloading": is_reloading,
		"auto_reload_when_empty": auto_reload_when_empty,
		"cooldown_timer": cooldown_timer,
		"reload_timer": reload_timer,
		"last_shot": _get_serializable_last_shot()
	}

func _finish_reload(preserve_bonus_state: bool) -> void:
	if preserve_bonus_state == false and ammo <= 0:
		final_bonus_enabled = true
	ammo = max_ammo
	is_reloading = false
	reload_timer = 0.0
	_emit_ammo_changed()

func _resolve_shot(origin: Vector3, direction: Vector3, owner_player: Node) -> Dictionary:
	return _ensure_shot_resolver().resolve(origin, direction.normalized(), owner_player, shot_range, max_ricochets, ricochet_origin_offset)

func _raycast_result(origin: Vector3, direction: Vector3, owner_player: Node) -> Dictionary:
	return _ensure_shot_resolver().raycast_result(origin, direction.normalized(), owner_player, shot_range)

func _is_ricochet_surface(node: Node) -> bool:
	return _ensure_shot_resolver().is_ricochet_surface(node)

func _get_effective_hit_node(node: Node) -> Node:
	return _ensure_shot_resolver().get_effective_hit_node(node)

func _reflect_direction(direction: Vector3, normal: Vector3) -> Vector3:
	return _ensure_shot_resolver().reflect_direction(direction, normal)

func _ensure_shot_resolver():
	if shot_resolver == null:
		shot_resolver = ShotResolver.new()
		shot_resolver.name = "ShotResolver"
		add_child(shot_resolver)
	return shot_resolver

func _apply_hit(hit_node: Node, direction: Vector3, is_final_shot: bool) -> float:
	if hit_node.has_method("apply_shot"):
		return hit_node.apply_shot(direction, is_final_shot)
	if hit_node.has_method("receive_shot_knockback"):
		var impulse_strength := get_player_knockback(is_final_shot)
		hit_node.receive_shot_knockback(direction, impulse_strength)
		return impulse_strength
	if hit_node.has_method("charge_from_shot"):
		return hit_node.charge_from_shot(is_final_shot)
	return 0.0

func _emit_ammo_changed() -> void:
	ammo_changed.emit(ammo, final_bonus_enabled, is_reloading)

func _get_serializable_last_shot() -> Dictionary:
	if last_shot.is_empty():
		return {}
	var serializable_segments := []
	for segment in last_shot.get("path_segments", []):
		serializable_segments.append({
			"from": _vector_to_array(segment.get("from", Vector3.ZERO)),
			"to": _vector_to_array(segment.get("to", Vector3.ZERO))
		})
	return {
		"hit_node_name": last_shot.get("hit_node_name", ""),
		"hit_direction": _vector_to_array(last_shot.get("hit_direction", Vector3.ZERO)),
		"hit_position": _vector_to_array(last_shot.get("hit_position", Vector3.ZERO)),
		"path_segments": serializable_segments,
		"is_final_shot": last_shot.get("is_final_shot", false),
		"impulse_strength": last_shot.get("impulse_strength", 0.0),
		"ricochet_count": last_shot.get("ricochet_count", 0)
	}

func _vector_to_array(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]
