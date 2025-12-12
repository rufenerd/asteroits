extends AIMode
class_name UnstickMode

func score(brain):
	var prev = brain.previous_position
	if not prev:
		return 0
	var moved = brain.player.global_position.distance_to(prev)
	if moved < 1.5 and brain.player.velocity.length() < 30:
		return 6000
	return 0

func apply(brain, delta):
	var p = brain.player
	var input = brain.input

	if brain.unstick_time <= 0.0:
		brain.unstick_time = randf_range(0.4, 0.8)

		var base_dir: Vector2
		if p.velocity.length() > 10:
			base_dir = -p.velocity.normalized()
		else:
			base_dir = Vector2.RIGHT.rotated(p.rotation)

		brain.unstick_dir = base_dir.rotated(randf_range(-PI/3, PI/3))

	input.target_position = p.global_position + brain.unstick_dir * 400
	input.target_aim = p.global_position
	brain.unstick_time -= delta
