extends Area3D
class_name SpringTrap

const GameConfig := preload("res://scripts/game_config.gd")
const TeamBallScript := preload("res://scripts/team_ball.gd")

@export var base_downward_impulse := 18.0
@export var charge_per_shot := 8.0
@export var final_shot_charge_multiplier := 1.6
@export var max_charge := 42.0

var current_charge := 0.0
var material := StandardMaterial3D.new()
var covers_cap := false
var cap_height := 0.0
var cap_radius := 0.0

func setup_cap(top_height: float, radius: float) -> void:
	covers_cap = true
	cap_height = top_height
	cap_radius = radius

func _ready() -> void:
	add_to_group(GameConfig.SHOT_TARGET_GROUP)
	add_to_group("spring_traps")
	_ensure_visuals()
	body_entered.connect(_on_body_entered)
	_update_visuals()

func charge_from_shot(is_final_shot: bool) -> float:
	var added_charge := charge_per_shot * (final_shot_charge_multiplier if is_final_shot else 1.0)
	current_charge = minf(max_charge, current_charge + added_charge)
	_update_visuals()
	return added_charge

func trigger_for_ball(ball) -> float:
	var impulse_strength := base_downward_impulse + current_charge
	ball.apply_trap_impulse(impulse_strength)
	current_charge = 0.0
	_update_visuals()
	return impulse_strength

func get_debug_state() -> Dictionary:
	return {
		"base_downward_impulse": base_downward_impulse,
		"current_charge": current_charge,
		"max_charge": max_charge,
		"covers_cap": covers_cap,
		"cap_height": cap_height,
		"cap_radius": cap_radius
	}

func _on_body_entered(body: Node) -> void:
	if body != null and body.get_script() == TeamBallScript:
		trigger_for_ball(body)

func _ensure_visuals() -> void:
	if covers_cap:
		_ensure_cap_visual()
		return
	if has_node("CollisionShape3D") == false:
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = 0.85
		collision_shape.shape = sphere_shape
		add_child(collision_shape)
	if has_node("MeshInstance3D") == false:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.85
		sphere_mesh.height = 1.7
		mesh_instance.mesh = sphere_mesh
		add_child(mesh_instance)

func _update_visuals() -> void:
	var charge_ratio := current_charge / max_charge if max_charge > 0.0 else 0.0
	var alpha := 0.34 + charge_ratio * 0.28 if covers_cap else 1.0
	material.albedo_color = Color(1.0, 0.72 - charge_ratio * 0.25, 0.12, alpha)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.45 + charge_ratio * 0.4, 0.08, 1.0)
	material.emission_energy_multiplier = (0.18 + charge_ratio * 0.8) if covers_cap else (0.25 + charge_ratio * 1.25)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if covers_cap else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.85
	var mesh_node := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_node != null:
		mesh_node.material_override = material
		if covers_cap == false:
			scale = Vector3.ONE * (1.0 + charge_ratio * 0.25)

func _ensure_cap_visual() -> void:
	if has_node("MeshInstance3D") == false:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		mesh_instance.position = Vector3(0.0, cap_height, 0.0)
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = cap_radius
		cap_mesh.bottom_radius = cap_radius
		cap_mesh.height = 0.12
		cap_mesh.radial_segments = 96
		cap_mesh.rings = 1
		mesh_instance.mesh = cap_mesh
		add_child(mesh_instance)
	var mesh_node := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_node != null:
		mesh_node.material_override = material
