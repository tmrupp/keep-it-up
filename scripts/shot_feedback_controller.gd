extends Node3D
class_name ShotFeedbackController

const GameConfig := preload("res://scripts/game_config.gd")

@export var shot_path_lifetime := 0.75
@export var hit_marker_lifetime := 0.55
@export var shot_path_start_offset := 0.35

var local_camera: Camera3D
var shot_feedback_count := 0
var shot_path_count := 0

func show_shot_feedback(feedback: String, color: Color, world_position: Vector3, path_segments: Array = [], is_bank_shot: bool = false, is_charged_shot: bool = false) -> void:
	shot_feedback_count += 1
	_spawn_shot_path(path_segments, color, is_bank_shot, is_charged_shot)
	_spawn_world_hit_marker(world_position, color, is_bank_shot, is_charged_shot)

func update_lifetimes(delta: float) -> void:
	for node in get_tree().get_nodes_in_group(GameConfig.SHOT_FEEDBACK_GROUP):
		if node.has_meta("remaining_lifetime") == false or node.has_meta("lifetime") == false:
			continue
		var lifetime: float = node.get_meta("lifetime")
		var remaining_lifetime: float = float(node.get_meta("remaining_lifetime")) - delta
		node.set_meta("remaining_lifetime", remaining_lifetime)
		if remaining_lifetime <= 0.0:
			node.queue_free()
			continue
		var alpha := clampf(remaining_lifetime / lifetime, 0.0, 1.0) * float(node.get_meta("base_alpha", 1.0))
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			var material := mesh_node.material_override as StandardMaterial3D
			if material != null:
				var material_color := material.albedo_color
				material_color.a = alpha
				material.albedo_color = material_color
				material.emission_energy_multiplier = maxf(0.0, alpha * 1.2)

func get_debug_state() -> Dictionary:
	return {
		"shot_feedback_count": shot_feedback_count,
		"shot_path_count": shot_path_count,
		"active_shot_feedback_nodes": get_tree().get_nodes_in_group(GameConfig.SHOT_FEEDBACK_GROUP).size()
	}

func _spawn_shot_path(path_segments: Array, color: Color, is_bank_shot: bool = false, is_charged_shot: bool = false) -> void:
	if path_segments.is_empty():
		return
	shot_path_count += 1
	var line_mesh := ImmediateMesh.new()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for segment in path_segments:
		line_mesh.surface_add_vertex(_nudge_path_start(segment.get("from", Vector3.ZERO)))
		line_mesh.surface_add_vertex(segment.get("to", Vector3.ZERO))
	line_mesh.surface_end()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "ShotPath%03d" % shot_path_count
	mesh_instance.add_to_group(GameConfig.SHOT_FEEDBACK_GROUP)
	mesh_instance.mesh = line_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.4 if is_charged_shot else (2.4 if is_bank_shot else 1.2)
	mesh_instance.material_override = material
	var path_lifetime := shot_path_lifetime * (2.1 if is_charged_shot else (1.65 if is_bank_shot else 1.0))
	mesh_instance.set_meta("lifetime", path_lifetime)
	mesh_instance.set_meta("remaining_lifetime", path_lifetime)
	mesh_instance.set_meta("base_alpha", color.a)
	mesh_instance.set_meta("is_bank_shot", is_bank_shot)
	mesh_instance.set_meta("is_charged_shot", is_charged_shot)
	add_child(mesh_instance)

func _spawn_world_hit_marker(world_position: Vector3, color: Color, is_bank_shot: bool = false, is_charged_shot: bool = false) -> void:
	if world_position == Vector3.ZERO:
		return
	var marker := MeshInstance3D.new()
	marker.name = "ShotFeedback%03d" % shot_feedback_count
	marker.add_to_group(GameConfig.SHOT_FEEDBACK_GROUP)
	marker.position = world_position
	var sphere := SphereMesh.new()
	sphere.radius = 0.28 if is_charged_shot else (0.2 if is_bank_shot else 0.12)
	sphere.height = 0.56 if is_charged_shot else (0.4 if is_bank_shot else 0.24)
	marker.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.8 if is_charged_shot else (1.8 if is_bank_shot else 0.8)
	marker.material_override = material
	var marker_lifetime := hit_marker_lifetime * (2.1 if is_charged_shot else (1.65 if is_bank_shot else 1.0))
	marker.set_meta("lifetime", marker_lifetime)
	marker.set_meta("remaining_lifetime", marker_lifetime)
	marker.set_meta("base_alpha", color.a)
	marker.set_meta("is_bank_shot", is_bank_shot)
	marker.set_meta("is_charged_shot", is_charged_shot)
	add_child(marker)

func _nudge_path_start(point: Vector3) -> Vector3:
	if local_camera == null:
		return point
	if point.distance_to(local_camera.global_position) > 0.08:
		return point
	return local_camera.global_position + (-local_camera.global_transform.basis.z).normalized() * shot_path_start_offset