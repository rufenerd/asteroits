extends AIMode
class_name RandomMode

var wander_dir := Vector2.ZERO
var wander_time := 0.0

func score(brain):
	# Trigger more often the longer we've stayed in the current mode, but respect a cooldown.
	if brain.wander_cooldown > 0.0:
		return 0
	return clamp(brain.mode_age * 600.0, 0, 30200)

func apply(brain, delta):
	var p = brain.player
	var input = brain.input

	# Start a wander if we don't have one active
	if wander_time <= 0.0 or wander_dir == Vector2.ZERO:
		wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		wander_time = randf_range(0.8, 1.6)

	# Compute a far target in the chosen direction and clamp to map bounds
	var target = p.global_position + wander_dir * 2000.0
	var b = World.BOUNDS
	target.x = clamp(target.x, b.position.x + 32.0, b.position.x + b.size.x - 32.0)
	target.y = clamp(target.y, b.position.y + 32.0, b.position.y + b.size.y - 32.0)
	input.target_position = target
	input.target_aim = p.global_position

	wander_time -= delta

	# End conditions: timer expired or we're at the edge
	var near_edge = _near_bounds(p.global_position, World.BOUNDS, 48.0)
	if wander_time <= 0.0 or near_edge:
		wander_time = 0.0
		wander_dir = Vector2.ZERO
		brain.wander_cooldown = 3.0
		brain.mode_timer = 0.0  # force quick re-eval next frame

func _near_bounds(pos: Vector2, rect: Rect2, margin: float) -> bool:
	return pos.x < rect.position.x + margin \
		or pos.x > rect.position.x + rect.size.x - margin \
		or pos.y < rect.position.y + margin \
		or pos.y > rect.position.y + rect.size.y - margin
