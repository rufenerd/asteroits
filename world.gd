extends Node

const CELL_SIZE = 16
const NUM_CELLS_IN_ROW = 625
const BOUNDS := Rect2(0, 0, NUM_CELLS_IN_ROW * CELL_SIZE, NUM_CELLS_IN_ROW * CELL_SIZE)
const MAX_RESOURCE_START_AMOUNT = 1000
const NUM_RESOURCE_CLUSTERS = 20
const MIN_RESOURCES_IN_CLUSTER = 25
const MAX_RESOURCES_IN_CLUSTER = 50
const MAX_CLUSTER_RADIUS = 20
const STARTING_RESOURCES = 0

var asteroid_count := 0
var board = {}
var resources = {}

var bank = {}
var extra_lives = {}
var spawn_points = {}

var hud: HUD
var spectator_mode := false
var player_order: Array = []

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
	initialize_clustered_resources(NUM_RESOURCE_CLUSTERS, MIN_RESOURCES_IN_CLUSTER, MAX_RESOURCES_IN_CLUSTER, MAX_CLUSTER_RADIUS)
	initialize_bases()
	spawn_initial_asteroid()

func _physics_process(delta):
	check_win_conditions()
	# In spectator mode, inputs are handled in _input/_unhandled_input.

func _unhandled_input(event):
	if not spectator_mode:
		return
	if event.is_action_pressed("boost_shield"):
		_switch_camera_next()

func _input(event):
	# Also listen in _input to ensure we catch inputs even if some UI consumes them.
	if not spectator_mode:
		return
	if event.is_action_pressed("boost_shield"):
		_switch_camera_next()
	
func register_player(player: Player):
	if player.team in extra_lives:
		return
	bank[player.team] = STARTING_RESOURCES
	extra_lives[player.team] = 0
	spawn_points[player.team] = available_spawn_locations.pop_front()
	colors[player.team] = available_colors.pop_front()
	# Track stable player order for camera handoff indices
	if not player_order.has(player):
		player_order.append(player)

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
				base.global_position = cell_to_world(cell)
				add_child(base)
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

func build(node, build_position, team):
	node.modulate = colors[team]
	var cell = world_to_cell(build_position)

	if _is_inside_base_area(build_position):
		node.queue_free()
		return

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

	var snapped_pos = cell_to_world(cell)
	node.global_position = snapped_pos

	add_child(node)

	board[cell] = node
	
	node.cell = cell

	if resources.has(cell):
		resources[cell].visible = false


func _is_inside_base_area(world_pos: Vector2) -> bool:
	# Check if position is within a base's collision radius
	for base in get_tree().get_nodes_in_group("bases"):
		if not is_instance_valid(base):
			continue
		var collision_shape = base.get_node_or_null("CollisionShape2D")
		if not collision_shape:
			continue
		var dist = world_pos.distance_to(collision_shape.global_position)
		var base_radius = 19.0 # CircleShape2D radius from base.tscn
		if dist < base_radius:
			return true
	return false

func harvest(harvester):
	var resource = resources[harvester.cell]
	resource.harvester = harvester
	if resource.amount > 0:
		resources[harvester.cell].amount -= 1
		if not harvester.team in bank:
			bank[harvester.team] = 0
		bank[harvester.team] += 1
	else:
		resource.remove_from_group("resources")
		resource.queue_free()
		harvester.remove_from_group("harvester")
		harvester.queue_free()

func asteroid_destroyed():
	asteroid_count -= 1
	if asteroid_count <= 0:
		call_deferred("spawn_initial_asteroid")

func spawn_initial_asteroid():
	var init_asteroid = preload("res://asteroid.tscn").instantiate()
	add_child(init_asteroid)
	init_asteroid.global_position = Vector2(randi() % CELL_SIZE * NUM_CELLS_IN_ROW, randi() % CELL_SIZE * NUM_CELLS_IN_ROW)
	asteroid_count = 1

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
		if b.team == "neutral":
			continue
		if not base_counts.has(b.team):
			base_counts[b.team] = 0
		base_counts[b.team] += 1

	for team_id in base_counts.keys():
		if base_counts[team_id] >= 4:
			print("%s wins by controlling all 4 bases!" % team_id)
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
		print("%s wins by being the last remaining!" % winner.team)
		get_tree().quit()
		return


func players():
	return get_tree().get_nodes_in_group("players")

func asteroids():
	return get_tree().get_nodes_in_group("asteroids")

func team_color(team: String, default := Color.WHITE) -> Color:
	# Return a Color for `team`. Accepts stored Color or hex/string.
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


# No longer using timed handoff; spectator toggling is always available after game over.


func _switch_camera_immediate(target_player):
	if not target_player or not is_instance_valid(target_player):
		return
	var cam = target_player.get_node_or_null("Camera2D")
	if not cam or not is_instance_valid(cam) or not cam.is_inside_tree():
		return
	var current_cam = get_viewport().get_camera_2d()
	if current_cam:
		current_cam.enabled = false
	cam.enabled = true
	cam.zoom = Vector2(1, 1)
	cam.make_current()

func _switch_camera_next():
	var alive_players := _alive_players_in_order()
	if alive_players.is_empty():
		return
	var current_cam = get_viewport().get_camera_2d()
	var current_index := -1
	for i in range(alive_players.size()):
		var p = alive_players[i]
		var cam = p.get_node_or_null("Camera2D")
		if cam and is_instance_valid(cam) and cam == current_cam:
			current_index = i
			break
	var next_index = (current_index + 1) % alive_players.size()
	var target = alive_players[next_index]
	_switch_camera_immediate(target)

func enter_spectator_mode():
	spectator_mode = true

func _alive_players_in_order() -> Array:
	var result: Array = []
	for p in player_order:
		if is_instance_valid(p) and p.is_in_group("players"):
			result.append(p)
	return result
