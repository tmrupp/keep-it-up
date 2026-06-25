extends CharacterBody3D
class_name PlayerController

const GameConfig := preload("res://scripts/game_config.gd")
const WeaponController := preload("res://scripts/weapon_controller.gd")

@export var team_id := GameConfig.TEAM_ONE
@export var move_speed := 8.5
@export var air_control := 0.55
@export var low_gravity := 5.8
@export var jump_velocity := 7.0
@export var mouse_sensitivity := 0.0025
@export var knockback_damping := 4.0
@export var wall_stun_speed := 13.0
@export var stun_duration := 1.1
@export var capture_mouse := true

var stun_timer := 0.0
var knockback_watch_timer := 0.0
var look_pitch := 0.0
var display_color := Color.WHITE
var local_control_enabled := true
var command_target: Node = null

@onready var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D
@onready var weapon = get_node_or_null("WeaponController")

func _ready() -> void:
	add_to_group(GameConfig.PLAYER_GROUP)
	add_to_group(GameConfig.SHOT_TARGET_GROUP)
	display_color = GameConfig.team_color(team_id)
	_ensure_nodes()
	if capture_mouse and is_inside_tree():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if _accepts_local_input() == false:
		return
	if event is InputEventMouseMotion and camera != null:
		rotate_y(-event.relative.x * mouse_sensitivity)
		look_pitch = clampf(look_pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
		camera.rotation.x = look_pitch
	if Input.is_action_just_pressed("fire"):
		try_fire()
	if Input.is_action_just_pressed("reload"):
		try_reload()
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _accepts_local_input() -> bool:
	return local_control_enabled and camera != null and camera.current

func _physics_process(delta: float) -> void:
	if knockback_watch_timer > 0.0:
		knockback_watch_timer = maxf(0.0, knockback_watch_timer - delta)
	if stun_timer > 0.0:
		stun_timer = maxf(0.0, stun_timer - delta)
		velocity.x = move_toward(velocity.x, 0.0, knockback_damping * delta)
		velocity.z = move_toward(velocity.z, 0.0, knockback_damping * delta)
	elif local_control_enabled:
		_apply_movement(delta)
	velocity.y -= low_gravity * delta
	var previous_velocity := velocity
	move_and_slide()
	_check_slide_stun(previous_velocity)

func setup(new_team_id: int, spawn_position: Vector3, active_camera: bool) -> void:
	team_id = new_team_id
	display_color = GameConfig.team_color(team_id)
	global_position = spawn_position
	_ensure_nodes()
	set_active_camera(active_camera)
	set_local_control_enabled(active_camera)

func reset_player(spawn_position: Vector3) -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	stun_timer = 0.0
	knockback_watch_timer = 0.0
	if weapon != null:
		weapon.ammo = weapon.max_ammo
		weapon.final_bonus_enabled = true
		weapon.is_reloading = false
		weapon.reload_timer = 0.0

func reset_for_point(spawn_position: Vector3) -> void:
	reset_player(spawn_position)

func set_active_camera(active: bool) -> void:
	_ensure_nodes()
	if camera != null:
		camera.current = active

func set_local_control_enabled(enabled: bool) -> void:
	local_control_enabled = enabled

func set_command_target(new_command_target: Node) -> void:
	command_target = new_command_target

func try_fire() -> bool:
	if stun_timer > 0.0 or weapon == null or camera == null:
		return false
	if command_target != null and command_target.has_method("request_local_fire"):
		return command_target.request_local_fire(self)
	return weapon.try_fire_from_camera(camera, self)

func try_reload() -> bool:
	if weapon == null:
		return false
	if command_target != null and command_target.has_method("request_local_reload"):
		return command_target.request_local_reload(self)
	return weapon.request_reload()

func receive_shot_knockback(direction: Vector3, impulse_strength: float) -> void:
	velocity += direction.normalized() * impulse_strength
	knockback_watch_timer = 0.65

func register_wall_impact(impact_speed: float) -> void:
	if knockback_watch_timer > 0.0 and impact_speed >= wall_stun_speed:
		stun_timer = stun_duration
		knockback_watch_timer = 0.0

func is_stunned() -> bool:
	return stun_timer > 0.0

func get_debug_state() -> Dictionary:
	return {
		"team_id": team_id,
		"position": _vector_to_array(global_position),
		"velocity": _vector_to_array(velocity),
		"stun_timer": stun_timer,
		"local_control_enabled": local_control_enabled,
		"weapon": weapon.get_debug_state() if weapon != null else {}
	}

func get_network_state() -> Dictionary:
	return {
		"team_id": team_id,
		"position": global_position,
		"velocity": velocity,
		"rotation_y": rotation.y,
		"look_pitch": look_pitch,
		"stun_timer": stun_timer,
		"knockback_watch_timer": knockback_watch_timer,
		"weapon_ammo": weapon.ammo if weapon != null else 0,
		"weapon_final_bonus_enabled": weapon.final_bonus_enabled if weapon != null else false,
		"weapon_is_reloading": weapon.is_reloading if weapon != null else false,
		"weapon_reload_timer": weapon.reload_timer if weapon != null else 0.0,
		"weapon_cooldown_timer": weapon.cooldown_timer if weapon != null else 0.0
	}

func apply_network_state(state: Dictionary) -> void:
	global_position = state.get("position", global_position)
	velocity = state.get("velocity", velocity)
	rotation.y = state.get("rotation_y", rotation.y)
	look_pitch = state.get("look_pitch", look_pitch)
	if camera != null:
		camera.rotation.x = look_pitch
	stun_timer = state.get("stun_timer", stun_timer)
	knockback_watch_timer = state.get("knockback_watch_timer", knockback_watch_timer)
	if weapon != null:
		weapon.ammo = int(state.get("weapon_ammo", weapon.ammo))
		weapon.final_bonus_enabled = bool(state.get("weapon_final_bonus_enabled", weapon.final_bonus_enabled))
		weapon.is_reloading = bool(state.get("weapon_is_reloading", weapon.is_reloading))
		weapon.reload_timer = float(state.get("weapon_reload_timer", weapon.reload_timer))
		weapon.cooldown_timer = float(state.get("weapon_cooldown_timer", weapon.cooldown_timer))

func _apply_movement(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := global_transform.basis
	var wish_direction := (basis.x * input_vector.x + basis.z * input_vector.y).normalized()
	var control := 1.0 if is_on_floor() else air_control
	if wish_direction.length() > 0.0:
		velocity.x = move_toward(velocity.x, wish_direction.x * move_speed, move_speed * control * delta * 5.0)
		velocity.z = move_toward(velocity.z, wish_direction.z * move_speed, move_speed * control * delta * 5.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * control * delta * 2.2)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * control * delta * 2.2)
	if Input.is_action_just_pressed("float_jump") and is_on_floor():
		velocity.y = jump_velocity

func _check_slide_stun(previous_velocity: Vector3) -> void:
	if knockback_watch_timer <= 0.0:
		return
	for slide_index in get_slide_collision_count():
		var collision := get_slide_collision(slide_index)
		var collider := collision.get_collider() as Node
		if collider != null and collider.is_in_group(GameConfig.WALL_GROUP):
			register_wall_impact(previous_velocity.length())
			return

func _ensure_nodes() -> void:
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.position = Vector3(0.0, 0.65, 0.0)
		add_child(camera)
	if weapon == null:
		weapon = WeaponController.new()
		weapon.name = "WeaponController"
		add_child(weapon)
	if has_node("CollisionShape3D") == false:
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var capsule_shape := CapsuleShape3D.new()
		capsule_shape.radius = 0.38
		capsule_shape.height = 1.55
		collision_shape.shape = capsule_shape
		add_child(collision_shape)
	if has_node("MeshInstance3D") == false:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = 0.38
		capsule_mesh.height = 1.55
		mesh_instance.mesh = capsule_mesh
		add_child(mesh_instance)
	var mesh_node := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_node != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = display_color
		mesh_node.material_override = material

func _vector_to_array(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]
