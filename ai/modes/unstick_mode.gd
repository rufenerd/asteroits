extends AIMode
class_name UnstickMode

func score(brain):
	var prev = brain.previous_position
	if not prev:
		return 0
	var moved = brain.player.global_position.distance_to(prev)
	if moved < 0.5 and brain.player.velocity.length() < 30:
		return 6000
	return 0

func apply(brain, delta):
	var p = brain.player
	var input = brain.input

	if brain.unstick_time <= 0.0:
		brain.unstick_time = randf_range(0.4, 0.8)
		brain.unstick_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

	input.target_position = p.global_position + brain.unstick_dir * 400
	input.target_aim = p.global_position
	brain.unstick_time -= delta
