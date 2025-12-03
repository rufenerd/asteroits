extends Node

const CELL_SIZE = 16
const NUM_CELLS_IN_ROW = 625
const BOUNDS := Rect2(0, 0, NUM_CELLS_IN_ROW * CELL_SIZE, NUM_CELLS_IN_ROW * CELL_SIZE)
const MAX_RESOURCE_START_AMOUNT = 100

var board := {}
var resources := {}

func _ready():
	initialize_clustered_resources(10, 4, 5)

func initialize_clustered_resources(num_clusters: int, min_resources: int, max_resources: int, cluster_radius: float = 5.0) -> void:
	for c in range(num_clusters):
		var cluster_center = Vector2i(
			randi() % NUM_CELLS_IN_ROW,
			randi() % NUM_CELLS_IN_ROW
		)

		var num_resources = randi() % (max_resources - min_resources + 1) + min_resources

		var R := int(cluster_radius)

		for i in range(num_resources):
			var dx = randi() % (R * 2 + 1) - R
			var dy = randi() % (R * 2 + 1) - R

			var cell = cluster_center + Vector2i(dx, dy)

			cell.x = clamp(cell.x, 0, NUM_CELLS_IN_ROW - 1)
			cell.y = clamp(cell.y, 0, NUM_CELLS_IN_ROW - 1)

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
		print(cell)
		print(resources.keys())
		return

	var snapped_pos = cell_to_world(cell)
	node.global_position = snapped_pos

	add_child(node)

	board[cell] = node

	if resources.has(cell):
		resources[cell].visible = false

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
