extends Node
class_name NetworkManager

signal host_started(transport: String, bind_address: String, port: int)
signal join_started(transport: String, url: String)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connected_to_server
signal server_disconnected
signal network_failed(reason: String)

const TRANSPORT_LOCAL := "local"
const TRANSPORT_WEBSOCKET := "websocket"

@export var default_websocket_port := 7000
@export var default_websocket_bind_address := "*"
@export var default_websocket_url := "ws://127.0.0.1:7000"

var transport := TRANSPORT_LOCAL
var role := "local"
var peer: MultiplayerPeer
var last_error := OK
var last_error_message := ""
var connected_peer_ids: Array[int] = []

func _ready() -> void:
	_connect_multiplayer_signals()
	start_local()

func start_local() -> void:
	disconnect_from_match(false)
	transport = TRANSPORT_LOCAL
	role = "local"
	last_error = OK
	last_error_message = ""
	multiplayer.multiplayer_peer = null

func host_websocket(port: int = -1, bind_address: String = "") -> Error:
	if OS.has_feature("web"):
		return _fail(ERR_UNAVAILABLE, "Browser builds cannot host the native WebSocket server for Option A")
	disconnect_from_match(false)
	var server_port := default_websocket_port if port <= 0 else port
	var server_bind_address := default_websocket_bind_address if bind_address == "" else bind_address
	var websocket_peer := WebSocketMultiplayerPeer.new()
	var error := websocket_peer.create_server(server_port, server_bind_address)
	if error != OK:
		return _fail(error, "Could not start WebSocket server on %s:%d" % [server_bind_address, server_port])
	peer = websocket_peer
	multiplayer.multiplayer_peer = peer
	transport = TRANSPORT_WEBSOCKET
	role = "host"
	last_error = OK
	last_error_message = ""
	host_started.emit(transport, server_bind_address, server_port)
	return OK

func join_websocket(url: String = "") -> Error:
	disconnect_from_match(false)
	var target_url := default_websocket_url if url == "" else url
	var websocket_peer := WebSocketMultiplayerPeer.new()
	var error := websocket_peer.create_client(target_url)
	if error != OK:
		return _fail(error, "Could not start WebSocket client for %s" % target_url)
	peer = websocket_peer
	multiplayer.multiplayer_peer = peer
	transport = TRANSPORT_WEBSOCKET
	role = "client"
	last_error = OK
	last_error_message = ""
	join_started.emit(transport, target_url)
	return OK

func host_lan(port: int = -1) -> Error:
	return host_websocket(port)

func join_lan(address: String = "127.0.0.1", port: int = -1) -> Error:
	var client_port := default_websocket_port if port <= 0 else port
	return join_websocket("ws://%s:%d" % [address, client_port])

func disconnect_from_match(emit_signal: bool = true) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	connected_peer_ids.clear()
	if emit_signal:
		server_disconnected.emit()
	transport = TRANSPORT_LOCAL
	role = "local"

func is_host() -> bool:
	return role == "host"

func is_client() -> bool:
	return role == "client"

func is_networked() -> bool:
	return role != "local"

func get_connection_status() -> int:
	if multiplayer.multiplayer_peer == null:
		return MultiplayerPeer.CONNECTION_DISCONNECTED
	return multiplayer.multiplayer_peer.get_connection_status()

func get_debug_state() -> Dictionary:
	return {
		"transport": transport,
		"role": role,
		"is_host": is_host(),
		"is_client": is_client(),
		"is_networked": is_networked(),
		"connection_status": get_connection_status(),
		"unique_id": multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0,
		"connected_peer_ids": connected_peer_ids.duplicate(),
		"default_websocket_port": default_websocket_port,
		"default_websocket_url": default_websocket_url,
		"last_error": last_error,
		"last_error_message": last_error_message
	}

func _connect_multiplayer_signals() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected) == false:
		multiplayer.peer_connected.connect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected) == false:
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server) == false:
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed) == false:
		multiplayer.connection_failed.connect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected) == false:
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(peer_id: int) -> void:
	if connected_peer_ids.has(peer_id) == false:
		connected_peer_ids.append(peer_id)
	peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	connected_peer_ids.erase(peer_id)
	peer_disconnected.emit(peer_id)

func _on_connected_to_server() -> void:
	connected_to_server.emit()

func _on_connection_failed() -> void:
	_fail(ERR_CANT_CONNECT, "Connection failed")

func _on_server_disconnected() -> void:
	connected_peer_ids.clear()
	server_disconnected.emit()
	transport = TRANSPORT_LOCAL
	role = "local"
	peer = null

func _fail(error: Error, message: String) -> Error:
	last_error = error
	last_error_message = message
	network_failed.emit(message)
	return error