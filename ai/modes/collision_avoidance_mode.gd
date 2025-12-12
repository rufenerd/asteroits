extends AIMode
class_name CollisionAvoidanceMode

func score(brain):
	var hit = AIHelpers.imminent_wall_collision(brain.player, brain.input)
	if not hit:
		return 0

	var dist = brain.player.global_position.distance_to(hit.position)
	var score = clamp(1.0 - dist / 300.0, 0, 1) * 100000

	if brain.mode == AIBrain.Mode.COLLISION_AVOIDANCE:
		score *= 0.3

	score -= brain.avoidance_cooldown * 2000
	return score

func apply(brain, delta):
	var p = brain.player
	var input = brain.input
	var hit = AIHelpers.imminent_wall_collision(brain.player, brain.input)
	if hit.is_empty():
		brain.avoidance_cooldown = 0.4
		return

	var normal: Vector2 = hit.normal.normalized()
	var hit_dist = p.global_position.distance_to(hit.position)

	if hit_dist < 600:
		input.target_position = p.global_position
		input.target_aim = hit.global_position
		return

	var repel_strength = clamp(1 - hit_dist / 300.0, 0, 1)
	var repel = normal * repel_strength * 600

	var tangent := Vector2(-normal.y, normal.x)
	if p.velocity.dot(tangent) < 0:
		tangent = -tangent

	var slide = tangent * 200 * repel_strength

	input.target_position = p.global_position + repel + slide
	input.target_aim = hit.global_position
