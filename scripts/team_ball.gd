extends RigidBody3D
class_name TeamBall

const GameConfig := preload("res://scripts/game_config.gd")

@export var team_id := GameConfig.TEAM_ONE
@export var shot_impulse := 18.0
@export var final_shot_multiplier := 1.8
@export var trap_multiplier := 1.0
@export var ball_gravity_scale := 0.1
@export var ball_mass := 1.35
@export var ball_linear_damp := 0.28
@export var start_sleeping := false
@export var visible_radius := 0.55
@export var shot_hit_radius := 0.95

var spawn_position := Vector3.ZERO
var display_color := Color.WHITE

func _ready() -> void:
	gravity_scale = ball_gravity_scale
	mass = ball_mass
	linear_damp = ball_linear_damp
	angular_damp = 0.1
	continuous_cd = true
	sleeping = start_sleeping
	add_to_group(GameConfig.BALL_GROUP)
	add_to_group(GameConfig.SHOT_TARGET_GROUP)
	if spawn_position == Vector3.ZERO:
		spawn_position = global_position
	_ensure_visuals()

func setup(new_team_id: int, new_spawn_position: Vector3) -> void:
	team_id = new_team_id
	spawn_position = new_spawn_position
	display_color = GameConfig.team_color(team_id)
	global_position = spawn_position
	_reset_motion()
	_ensure_visuals()

func reset_ball() -> void:
	global_position = spawn_position
	_reset_motion()

func apply_shot(direction: Vector3, is_final_shot: bool) -> float:
	var impulse_strength := get_shot_impulse(is_final_shot)
	apply_central_impulse(direction.normalized() * impulse_strength)
	return impulse_strength

func apply_trap_impulse(impulse_strength: float) -> void:
	apply_central_impulse(Vector3.DOWN * impulse_strength * trap_multiplier)

func get_shot_impulse(is_final_shot: bool) -> float:
	return shot_impulse * (final_shot_multiplier if is_final_shot else 1.0)

func get_debug_state() -> Dictionary:
	return {
		"team_id": team_id,
		"spawn_position": _vector_to_array(spawn_position),
		"position": _vector_to_array(global_position),
		"velocity": _vector_to_array(linear_velocity),
		"speed": linear_velocity.length(),
		"gravity_scale": gravity_scale,
		"linear_damp": linear_damp
	}

func _reset_motion() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false

func _ensure_visuals() -> void:
	if has_node("CollisionShape3D") == false:
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = visible_radius
		collision_shape.shape = sphere_shape
		add_child(collision_shape)
	if has_node("ShotHitArea") == false:
		var shot_area := Area3D.new()
		shot_area.name = "ShotHitArea"
		shot_area.add_to_group(GameConfig.SHOT_TARGET_GROUP)
		shot_area.set_meta("shot_target_node", self)
		var shot_collision := CollisionShape3D.new()
		shot_collision.name = "CollisionShape3D"
		var shot_shape := SphereShape3D.new()
		shot_shape.radius = shot_hit_radius
		shot_collision.shape = shot_shape
		shot_area.add_child(shot_collision)
		add_child(shot_area)
	if has_node("MeshInstance3D") == false:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = visible_radius
		sphere_mesh.height = visible_radius * 2.0
		mesh_instance.mesh = sphere_mesh
		add_child(mesh_instance)
	var mesh_node := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_node != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = display_color
		material.roughness = 0.35
		material.metallic = 0.05
		mesh_node.material_override = material

func _vector_to_array(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]
