extends Node

const CELL_SIZE = 16
const BOUNDS := Rect2(0, 0, 10_000, 10_000)

var board := {}

func build(node, build_position):
	var cell = world_to_cell(build_position)

	if World.board.has(cell):
		return

	var snapped_pos = cell_to_world(cell)
	node.global_position = snapped_pos

	get_parent().add_child(node)

	World.board[cell] = node

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
