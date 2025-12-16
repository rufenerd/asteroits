extends Node

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal game_started
signal game_ended

const MAX_PLAYERS = 4
const DEFAULT_PORT = 9999

var is_host := false
var local_player_id := 0
var connected_peers := {} # peer_id -> player_team

func _ready():
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func host_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if error != OK:
		push_error("Failed to create server: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_player_id = 1
	connected_peers[1] = null # Server is peer 1
	print("Server started on port ", DEFAULT_PORT)
	return true

func connect_to_server(ip: String):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, DEFAULT_PORT)
	print("create_client returned error code: ", error, " (OK=", OK, ")")
	if error != OK:
		push_error("Failed to create client: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_host = false
	print("Connecting to server at ", ip, ":", DEFAULT_PORT)
	print("Peer connection status: ", peer.get_connection_status())
	return true

func _on_connected_to_server():
	print("Connected to server as peer ", multiplayer.get_unique_id())
	local_player_id = multiplayer.get_unique_id()

func _on_server_disconnected():
	print("Disconnected from server")
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_peer_connected(peer_id: int):
	print("Peer connected: ", peer_id)
	if is_host:
		connected_peers[peer_id] = null
	peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int):
	print("Peer disconnected: ", peer_id)
	if is_host:
		connected_peers.erase(peer_id)
	peer_disconnected.emit(peer_id)

func start_game():
	if is_host:
		_rpc_start_game.rpc()
	else:
		push_error("Only host can start game")

@rpc("authority", "call_local")
func _rpc_start_game():
	game_started.emit()
	get_tree().change_scene_to_file("res://main.tscn")

func get_human_player_count() -> int:
	# Include all connected peers (host + clients)
	return len(connected_peers)

func get_ai_player_count() -> int:
	return MAX_PLAYERS - get_human_player_count()
