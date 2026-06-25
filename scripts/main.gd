extends Node3D

const ArenaManager := preload("res://scripts/arena_manager.gd")
const NetworkManager := preload("res://scripts/network_manager.gd")

@export var websocket_port := 7000
@export var websocket_bind_address := "*"
@export var websocket_join_url := "ws://127.0.0.1:7000"

var arena
var network_manager

func _ready() -> void:
	network_manager = NetworkManager.new()
	network_manager.name = "NetworkManager"
	network_manager.default_websocket_port = websocket_port
	network_manager.default_websocket_bind_address = websocket_bind_address
	network_manager.default_websocket_url = websocket_join_url
	add_child(network_manager)
	arena = ArenaManager.new()
	arena.name = "Arena"
	add_child(arena)
	arena.setup_network(network_manager)
	_apply_network_command_line()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("host_game"):
		var key_event := event as InputEventKey
		if key_event == null or key_event.echo == false:
			host_websocket_match()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("join_game"):
		var key_event := event as InputEventKey
		if key_event == null or key_event.echo == false:
			join_websocket_match(websocket_join_url)
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("disconnect_game"):
		var key_event := event as InputEventKey
		if key_event == null or key_event.echo == false:
			disconnect_match()
			get_viewport().set_input_as_handled()

func host_websocket_match(port: int = -1) -> Error:
	var target_port := websocket_port if port <= 0 else port
	return network_manager.host_websocket(target_port, websocket_bind_address)

func join_websocket_match(url: String = "") -> Error:
	var target_url := websocket_join_url if url == "" else url
	return network_manager.join_websocket(target_url)

func disconnect_match() -> void:
	network_manager.disconnect_from_match()

func get_debug_state() -> Dictionary:
	return {
		"network": network_manager.get_debug_state() if network_manager != null else {},
		"arena": arena.get_debug_state() if arena != null else {}
	}

func _apply_network_command_line() -> void:
	var args := OS.get_cmdline_args()
	var should_host := args.has("--host-websocket")
	var join_url := ""
	for arg in args:
		if arg.begins_with("--websocket-port="):
			websocket_port = int(arg.get_slice("=", 1))
			if network_manager != null:
				network_manager.default_websocket_port = websocket_port
		if arg.begins_with("--websocket-url="):
			websocket_join_url = arg.get_slice("=", 1)
			if network_manager != null:
				network_manager.default_websocket_url = websocket_join_url
		if arg.begins_with("--join-websocket="):
			join_url = arg.get_slice("=", 1)
	if should_host:
		host_websocket_match(websocket_port)
	elif join_url != "":
		join_websocket_match(join_url)
