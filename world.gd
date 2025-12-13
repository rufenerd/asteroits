extends Node

const CELL_SIZE = 16
const NUM_CELLS_IN_ROW = 625
const BOUNDS := Rect2(0, 0, NUM_CELLS_IN_ROW * CELL_SIZE, NUM_CELLS_IN_ROW * CELL_SIZE)
const MAX_RESOURCE_START_AMOUNT = 1000
const NUM_RESOURCE_CLUSTERS = 20
const MIN_RESOURCES_IN_CLUSTER = 25
const MAX_RESOURCES_IN_CLUSTER = 50
const MAX_CLUSTER_RADIUS = 20
const NUM_BASES = 4

var asteroid_count := 0
var board = {}
var resources = {}

var bank = {}
var extra_lives = {}
var spawn_points = {}

var hud : HUD

#green 39FF14
#pink DA14FE
#blue 00F0FF
#orange FE6414
#yellow FEDA14
var colors = {"neutral": Color.WHITE}

var available_colors = ["39FF14", "DA14FE", "00F0FF", "FEDA14", "FE6414"]
var available_spawn_locations = [Vector2(400,400), Vector2(400,9600), Vector2(9600,400), Vector2(9600,9600)]

func _ready():
	initialize_clustered_resources(NUM_RESOURCE_CLUSTERS, MIN_RESOURCES_IN_CLUSTER, MAX_RESOURCES_IN_CLUSTER, MAX_CLUSTER_RADIUS)
	initialize_bases(NUM_BASES)
	spawn_initial_asteroid()

func _physics_process(delta):
	check_win_conditions()
	
func register_player(player : Player):
	if player.team in bank:
		return
	bank[player.team] = 0
	extra_lives[player.team] = 2
	spawn_points[player.team] = available_spawn_locations.pop_front()
	colors[player.team] = available_colors.pop_front()

func initialize_bases(num_bases):
	for c in range(num_bases):
		var base = preload("res://base.tscn").instantiate()
		var made_base = false
		while true:
			var cell = Vector2i(
				randi() % NUM_CELLS_IN_ROW,
				randi() % NUM_CELLS_IN_ROW
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
			var z0 = mag * cos(TAU * u2)   # Gaussian 0, mean 0, stddev 1
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

	if board.has(cell):
		return

	if node is Harvester and not resources.has(cell):
		return
		
	if not node is Harvester:
		if bank[team] < 10:
			return
		bank[team] -= 10

	var snapped_pos = cell_to_world(cell)
	node.global_position = snapped_pos

	add_child(node)

	board[cell] = node
	
	node.cell = cell

	if resources.has(cell):
		resources[cell].visible = false

func harvest(harvester):
	var resource = resources[harvester.cell]
	resource.harvester = harvester
	if resource.amount > 0:
		resources[harvester.cell].amount -= 1
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

	# --- 3. One team's World.bank is 100,000 more than any other ---
	var max_team = null
	var max_value := -INF
	for team_id in World.bank.keys():
		var val = World.bank[team_id]
		if val > max_value:
			max_value = val
			max_team = team_id

	for team_id in World.bank.keys():
		if team_id == max_team:
			continue
		if max_value - World.bank[team_id] < 100_000:
			max_team = null
			break

	if max_team != null:
		print("%s wins by having 40k more resources than any opponent!" % max_team)
		get_tree().quit()

func players():
	return get_tree().get_nodes_in_group("players")

func asteroids():
	return get_tree().get_nodes_in_group("asteroids")
