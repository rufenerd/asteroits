extends Node

const CELL_SIZE = 16
const NUM_CELLS_IN_ROW = 625
const BOUNDS := Rect2(0, 0, NUM_CELLS_IN_ROW * CELL_SIZE, NUM_CELLS_IN_ROW * CELL_SIZE)
const MAX_RESOURCE_START_AMOUNT = 1000
const NUM_RESOURCE_CLUSTERS = 20
const MIN_RESOURCES_IN_CLUSTER = 25
const MAX_RESOURCES_IN_CLUSTER = 50
const MAX_CLUSTER_RADIUS = 20

var asteroid_count := 0
var board = {}
var resources = {}

var bank = {}
var extra_lives = {}
var spawn_points = {}

var hud: HUD
var _net_seq := 1

func next_net_name(prefix: String) -> String:
	var name = "%s_%d" % [prefix, _net_seq]
	_net_seq += 1
	return name

#green 39FF14
#pink DA14FE
#blue 00F0FF
#orange FE6414
#yellow FEDA14
var colors = {"neutral": Color.WHITE}

var available_colors = [
	Color8(57, 255, 20), # 39FF14
	Color8(218, 20, 254), # DA14FE
	Color8(0, 240, 255), # 00F0FF
	Color8(254, 218, 20), # FEDA14
	Color8(254, 100, 20) # FE6414
]
var available_spawn_locations = [Vector2(400, 400), Vector2(400, 9600), Vector2(9600, 400), Vector2(9600, 9600)]

func _ready():
	# Only host initializes world state
	if multiplayer.is_server():
		initialize_clustered_resources(NUM_RESOURCE_CLUSTERS, MIN_RESOURCES_IN_CLUSTER, MAX_RESOURCES_IN_CLUSTER, MAX_CLUSTER_RADIUS)
		initialize_bases()
		spawn_initial_asteroid()
		# Connect to peer connected signal to sync world state to new clients
		multiplayer.peer_connected.connect(_on_peer_connected)

func _on_peer_connected(peer_id: int):
	# Send full world state to the newly connected peer
	_sync_world_state_to_peer(peer_id)

func _sync_world_state_to_peer(peer_id: int):
	# Sync all resources
	for cell in resources.keys():
		var resource = resources[cell]
		_rpc_spawn_resource.rpc_id(peer_id, resource.amount, cell)
	
	# Sync all bases
	for cell in board.keys():
		var node = board[cell]
		if node is Base:
			_rpc_spawn_base.rpc_id(peer_id, node.global_position, cell)
			if node.team != "neutral":
				_rpc_capture_base.rpc_id(peer_id, node.get_path(), node.team)
	
	# Sync asteroid if exists
	var asteroids_list = get_tree().get_nodes_in_group("asteroids")
	for asteroid in asteroids_list:
		if is_instance_valid(asteroid):
			_rpc_spawn_asteroid.rpc_id(peer_id, asteroid.global_position)

func _physics_process(delta):
	check_win_conditions()
	
func register_player(player: Player):
	if player.team in extra_lives:
		return
	bank[player.team] = 100000
	extra_lives[player.team] = 2
	spawn_points[player.team] = available_spawn_locations.pop_front()
	colors[player.team] = available_colors.pop_front()
	
	# Sync player registration to clients
	if multiplayer.is_server():
		_rpc_register_player.rpc(player.team, bank[player.team], extra_lives[player.team], spawn_points[player.team], colors[player.team])

@rpc("authority", "unreliable")
func _broadcast_player_state(team, pos: Vector2, vel: Vector2, rot: float, player_health: int, is_dying: bool):
	# Server broadcasts player state to all clients
	if multiplayer.is_server():
		return
	# Find the player with this team and update it
	for player in get_tree().get_nodes_in_group("players"):
		if player.team == team:
			player._net_position = pos
			player._net_velocity = vel
			player._net_rotation = rot
			if player.health != player_health:
				player.health = player_health
			if is_dying and not player.dying:
				player.dying = true
				player.visible = false
			break

func initialize_bases():
	var quadrants = [
		Rect2i(0, 0, NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2), # top left
		Rect2i(NUM_CELLS_IN_ROW / 2, 0, NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2), # top right
		Rect2i(0, NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2), # bottom left
		Rect2i(NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2) # bottom right
	]
	for q in quadrants:
		var base = preload("res://base.tscn").instantiate()
		while true:
			var cell = Vector2i(
				q.position.x + randi() % q.size.x,
				q.position.y + randi() % q.size.y
			)
			if not board.has(cell) and not resources.has(cell):
				board[cell] = base
				var pos = cell_to_world(cell)
				base.global_position = pos
				add_child(base)
				if multiplayer.is_server():
					_rpc_spawn_base.rpc(pos, cell)
				break
		

func initialize_clustered_resources(num_clusters: int, min_resources: int, max_resources: int, max_cluster_radius: float) -> void:
	for c in range(num_clusters):
		var cluster_radius = (MAX_CLUSTER_RADIUS / 2) + randi() % (MAX_CLUSTER_RADIUS / 2)
		
		var cluster_center = Vector2i(
			randi() % NUM_CELLS_IN_ROW,
			randi() % NUM_CELLS_IN_ROW
		)

		var num_resources = randi() % (max_resources - min_resources + 1) + min_resources

		var R := int(cluster_radius)

		for i in range(num_resources):
			# Gaussian offsets (mean 0, stddev ~ R/2, adjust as needed)
			var u1 = randf()
			var u2 = randf()
			var mag = sqrt(-2.0 * log(u1))
			var z0 = mag * cos(TAU * u2) # Gaussian 0, mean 0, stddev 1
			var z1 = mag * sin(TAU * u2)

			# Scale Gaussian to desired spread
			var dx = int(z0 * (R * 0.5))
			var dy = int(z1 * (R * 0.5))

			var cell = cluster_center + Vector2i(dx, dy)

			if cell.x < 0 or cell.y < 0 or cell.x >= NUM_CELLS_IN_ROW or cell.y >= NUM_CELLS_IN_ROW:
				continue

			var resource_amount = randi() % MAX_RESOURCE_START_AMOUNT + 1
			initialize_resource(resource_amount, cell)

func initialize_resource(amount, cell: Vector2i):
	if resources.has(cell):
		return
	var resource = preload("res://resource.tscn").instantiate()
	resource.global_position = cell_to_world(cell)
	resource.amount = amount
	resources[cell] = resource
	add_child(resource)
	
	# Sync resource spawn to clients
	if multiplayer.is_server():
		_rpc_spawn_resource.rpc(amount, cell)

func build(node, build_position, team):
	# Only host processes builds
	if not multiplayer.is_server():
		node.queue_free()
		return
		
	node.modulate = colors[team]
	var cell = world_to_cell(build_position)

	if board.has(cell):
		node.queue_free()
		return

	if node is Harvester and not resources.has(cell):
		node.queue_free()
		return
		
	if not node is Harvester:
		if bank[team] < 200:
			node.queue_free()
			return
		bank[team] -= 200
		_rpc_sync_bank.rpc(team, bank[team])

	var snapped_pos = cell_to_world(cell)
	node.global_position = snapped_pos

	add_child(node)

	board[cell] = node
	
	node.cell = cell

	if resources.has(cell):
		resources[cell].visible = false
		
	# Sync building placement to clients
	_rpc_build.rpc(node.scene_file_path, snapped_pos, team, cell)

func harvest(harvester):
	if not multiplayer.is_server():
		return
		
	var resource = resources[harvester.cell]
	resource.harvester = harvester
	if resource.amount > 0:
		resources[harvester.cell].amount -= 1
		if not harvester.team in bank:
			bank[harvester.team] = 0
		bank[harvester.team] += 1
		_rpc_sync_bank.rpc(harvester.team, bank[harvester.team])
		_rpc_update_resource.rpc(harvester.cell, resource.amount)
	else:
		resource.remove_from_group("resources")
		resource.queue_free()
		harvester.remove_from_group("harvester")
		harvester.queue_free()
		_rpc_remove_resource.rpc(harvester.cell)

func asteroid_destroyed():
	asteroid_count -= 1
	if asteroid_count <= 0:
		call_deferred("spawn_initial_asteroid")

func spawn_initial_asteroid():
	if not multiplayer.is_server():
		return
		
	var init_asteroid = preload("res://asteroid.tscn").instantiate()
	add_child(init_asteroid)
	var spawn_pos = Vector2(randi() % CELL_SIZE * NUM_CELLS_IN_ROW, randi() % CELL_SIZE * NUM_CELLS_IN_ROW)
	init_asteroid.global_position = spawn_pos
	init_asteroid.name = next_net_name("Asteroid")
	asteroid_count = 1
	_rpc_spawn_asteroid.rpc(spawn_pos, init_asteroid.name)

func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / CELL_SIZE)),
		int(floor(pos.y / CELL_SIZE))
	)

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x + 0.5) * CELL_SIZE,
		(cell.y + 0.5) * CELL_SIZE
	)

func check_win_conditions():
	# --- 1. All 4 bases owned by 1 team (not neutral) ---
	var base_counts := {}
	for b in get_tree().get_nodes_in_group("bases"):
		if not is_instance_valid(b):
			continue
		var base_team = b.team
		if typeof(base_team) == TYPE_STRING and base_team == "neutral":
			continue
		if not base_counts.has(base_team):
			base_counts[base_team] = 0
		base_counts[base_team] += 1

	for team_id in base_counts.keys():
		if base_counts[team_id] >= 4:
			print("%swinsbycontrollingall4bases!" % team_id)
			get_tree().quit()
			return

	# --- 2. Only 1 player remains ---
	var alive_players := []
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		alive_players.append(p)

	if alive_players.size() == 1:
		var winner = alive_players[0]
		print("%swinsbybeingthelastremaining!" % winner.team)
		get_tree().quit()
		return


func players():
	return get_tree().get_nodes_in_group("players")

func asteroids():
	return get_tree().get_nodes_in_group("asteroids")

func team_color(team, default := Color.WHITE) -> Color:
	# Return a Color for `team` (int or string). Accepts stored Color or hex/string.
	var raw = colors.get(team, default)
	if typeof(raw) == TYPE_STRING:
		return Color.from_string(raw, default)
	return raw

func _switch_camera_deferred(best_player):
	await get_tree().create_timer(1.0).timeout
	if best_player and is_instance_valid(best_player):
		var best_camera = best_player.get_node_or_null("Camera2D")
		if best_camera and is_instance_valid(best_camera) and best_camera.is_inside_tree():
			var current_cam = get_viewport().get_camera_2d()
			if current_cam:
				current_cam.enabled = false
			best_camera.enabled = true
			best_camera.zoom = Vector2(1, 1)
			best_camera.make_current()

# Network synchronization RPCs
@rpc("authority", "call_local", "reliable")
func _rpc_spawn_resource(amount: int, cell: Vector2i):
	if multiplayer.is_server():
		return # Already spawned locally
	if resources.has(cell):
		return
	var resource = preload("res://resource.tscn").instantiate()
	resource.global_position = cell_to_world(cell)
	resource.amount = amount
	resources[cell] = resource
	add_child(resource)

@rpc("authority", "call_local", "reliable")
func _rpc_spawn_asteroid(spawn_pos: Vector2, node_name: String):
	if multiplayer.is_server():
		return
	var init_asteroid = preload("res://asteroid.tscn").instantiate()
	add_child(init_asteroid)
	init_asteroid.global_position = spawn_pos
	init_asteroid.name = node_name
	asteroid_count = 1

@rpc("authority", "call_local", "reliable")
func _rpc_sync_bank(team, amount: int):
	if multiplayer.is_server():
		return
	bank[team] = amount

@rpc("authority", "call_local", "reliable")
func _rpc_update_resource(cell: Vector2i, new_amount: int):
	if multiplayer.is_server():
		return
	if resources.has(cell):
		resources[cell].amount = new_amount

@rpc("authority", "call_local", "reliable")
func _rpc_remove_resource(cell: Vector2i):
	if multiplayer.is_server():
		return
	if resources.has(cell):
		var resource = resources[cell]
		resource.remove_from_group("resources")
		resource.queue_free()
		resources.erase(cell)

@rpc("authority", "call_local", "reliable")
func _rpc_build(scene_path: String, position: Vector2, team, cell: Vector2i):
	if multiplayer.is_server():
		return
	var node = load(scene_path).instantiate()
	node.modulate = colors[team]
	node.global_position = position
	add_child(node)
	board[cell] = node
	node.cell = cell
	if resources.has(cell):
		resources[cell].visible = false

@rpc("authority", "call_local", "reliable")
func _rpc_spawn_base(position: Vector2, cell: Vector2i):
	if multiplayer.is_server():
		return
	var base = preload("res://base.tscn").instantiate()
	base.global_position = position
	board[cell] = base
	add_child(base)

@rpc("authority", "call_local", "reliable")
func _rpc_register_player(team, bank_amount: int, lives: int, spawn_pos: Vector2, color: Color):
	if multiplayer.is_server():
		return
	bank[team] = bank_amount
	extra_lives[team] = lives
	spawn_points[team] = spawn_pos
	colors[team] = color

@rpc("authority", "call_local", "reliable")
func _rpc_spawn_bullet(pos: Vector2, dir: Vector2, bullet_speed: float, bullet_team, node_name: String):
	if multiplayer.is_server():
		return
	var bullet = preload("res://bullet.tscn").instantiate()
	bullet.team = bullet_team
	bullet.direction = dir
	bullet.speed = bullet_speed
	bullet.global_position = pos
	bullet.name = node_name
	var team_col: Variant = colors.get(bullet_team, Color.WHITE)
	var c: Color
	if typeof(team_col) == TYPE_STRING:
		c = Color.from_string(team_col, Color.WHITE)
	else:
		c = team_col
	bullet.modulate = c.lerp(Color.WHITE, 0.3) * 2.5
	add_child(bullet)

@rpc("authority", "call_local", "reliable")
func _rpc_capture_base(base_path: NodePath, new_team):
	if multiplayer.is_server():
		return
	var base = get_node_or_null(base_path)
	if base and base is Base:
		base.team = new_team
		if colors.has(new_team):
			base.visual.modulate = team_color(new_team)

@rpc("authority", "call_local", "reliable")
func _rpc_destroy_bullet_by_name(node_name: String):
	if multiplayer.is_server():
		return
	var bullet = get_node_or_null(node_name)
	if bullet:
		bullet.queue_free()

@rpc("authority", "call_local", "reliable")
func _rpc_destroy_asteroid(asteroid_path: NodePath):
	if multiplayer.is_server():
		return
	var asteroid = get_node_or_null(asteroid_path)
	if asteroid:
		asteroid.queue_free()

@rpc("authority", "call_local", "reliable")
func _rpc_spawn_child_asteroid(pos: Vector2, child_radius: float, child_mass: float, lin_vel: Vector2, ang_vel: float, node_name: String):
	if multiplayer.is_server():
		return
	var child = preload("res://asteroid.tscn").instantiate()
	child.radius = child_radius
	child.mass = child_mass
	child.global_position = pos
	child.linear_velocity = lin_vel
	child.angular_velocity = ang_vel
	child.name = node_name
	add_child(child)
