extends Node

const CELL_SIZE = 16
const NUM_CELLS_IN_ROW = 625
const BOUNDS := Rect2(0, 0, NUM_CELLS_IN_ROW * CELL_SIZE, NUM_CELLS_IN_ROW * CELL_SIZE)
const MAX_RESOURCE_START_AMOUNT = 300
const NUM_RESOURCE_CLUSTERS = 20
const MIN_RESOURCES_IN_CLUSTER = 25
const MAX_RESOURCES_IN_CLUSTER = 50
const MAX_CLUSTER_RADIUS = 20

var board = {}
var resources = {}
var bank = { "player": 0 }

func _ready():
	initialize_clustered_resources(NUM_RESOURCE_CLUSTERS, MIN_RESOURCES_IN_CLUSTER, MAX_RESOURCES_IN_CLUSTER, MAX_CLUSTER_RADIUS)

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

func build(node, build_position):
	var cell = world_to_cell(build_position)

	if board.has(cell):
		return

	if node is Harvester and not resources.has(cell):
		return
		
	if not node is Harvester:
		if bank["player"] < 10:
			return
		bank["player"] -= 10

	var snapped_pos = cell_to_world(cell)
	node.global_position = snapped_pos

	add_child(node)

	board[cell] = node
	
	node.cell = cell

	if resources.has(cell):
		resources[cell].visible = false

func harvest(harvester):
	var resource = resources[harvester.cell]
	if resource.amount > 0:
		resources[harvester.cell].amount -= 1
		bank["player"] += 1 #TODO generic keys
	else:
		harvester.queue_free()

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
