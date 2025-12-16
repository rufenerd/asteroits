extends Node2D

@onready var world_node = $World
var spawn_timer := 0.0
var players_by_peer_id := {} # peer_id -> Player node

func _ready():
	# On host, delay spawning to ensure all clients are connected
	if NetworkManager.is_host:
		spawn_timer = 0.1 # Small delay to wait for connections
	else:
		# Clients wait for RPC spawn
		pass

func _process(delta):
	if spawn_timer > 0:
		spawn_timer -= delta
		if spawn_timer <= 0:
			var peer_ids = NetworkManager.connected_peers.keys()
			peer_ids.sort()
			# Only call via RPC with call_local so it runs on all instances
			_rpc_spawn_players.rpc(peer_ids, NetworkManager.get_ai_player_count())

func spawn_players(peer_ids: Array, ai_count: int):
	var human_count = peer_ids.size()

	# Spawn human players - one for each connected peer
	for i in range(human_count):
		var human_player = preload("res://ai/human_player.tscn").instantiate()
		var player_node = human_player.get_node("Player")
		player_node.peer_id = peer_ids[i] # Assign peer ID
		player_node.team = i
		player_node.set_multiplayer_authority(1) # Host is authority
		
		# Only register on host to avoid double-registering on client
		if multiplayer.is_server():
			World.register_player(player_node)
		
		world_node.add_child(human_player)
		players_by_peer_id[peer_ids[i]] = player_node

	# Spawn AI players
	var ai_biases = [
		{"combat_bias": 1.1, "base_bias": 1.0, "asteroid_bias": 1.0},
		{"combat_bias": 1.0, "base_bias": 1.1, "asteroid_bias": 1.0},
		{"combat_bias": 1.0, "base_bias": 1.1, "asteroid_bias": 2.0}
	]

	for i in range(ai_count):
		var ai_player = preload("res://ai/ai_player.tscn").instantiate()
		var player_node = ai_player.get_node("Player")
		player_node.team = human_count + i
		player_node.set_multiplayer_authority(1)

		# Apply biases
		if i < ai_biases.size():
			if ai_biases[i].has("combat_bias"):
				ai_player.combat_bias = ai_biases[i].combat_bias
			if ai_biases[i].has("base_bias"):
				ai_player.base_bias = ai_biases[i].base_bias
			if ai_biases[i].has("asteroid_bias"):
				ai_player.asteroid_bias = ai_biases[i].asteroid_bias

		# Only register on host to avoid double-registering on client
		if multiplayer.is_server():
			World.register_player(player_node)
		
		world_node.add_child(ai_player)
		print("Spawned AI player %d with team %d" % [i, player_node.team])

@rpc("authority", "call_local")
func _rpc_spawn_players(peer_ids: Array, ai_count: int):
	spawn_players(peer_ids, ai_count)

func _apply_player_input_direct(target_peer_id: int, payload: Dictionary):
	if target_peer_id in players_by_peer_id:
		var player = players_by_peer_id[target_peer_id]
		if is_instance_valid(player) and player.has_method("_apply_network_input"):
			player._apply_network_input(payload)

@rpc("any_peer", "call_remote")
func receive_player_input(target_peer_id: int, move_x: float, move_y: float, aim_x: float, aim_y: float, turbo: bool, build_wall: bool, build_harvester: bool, build_turret: bool, boost_shield: bool):
	# This RPC is called by clients to send input to the host
	if not multiplayer.is_server():
		return
	var payload = {
		"move": Vector2(move_x, move_y),
		"aim": Vector2(aim_x, aim_y),
		"turbo": turbo,
		"build_wall": build_wall,
		"build_harvester": build_harvester,
		"build_turret": build_turret,
		"boost_shield": boost_shield,
	}
	_apply_player_input_direct(target_peer_id, payload)
