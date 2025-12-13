extends AIMode
class_name CollisionAvoidanceMode

const WALL_NOTICE := 600.0
const ASTEROID_NOTICE := 450.0
const PLAYER_NOTICE := 500.0

func score(brain):
	var hit = AIHelpers.imminent_wall_collision(brain.player, brain.input)

	var best_threat_dist := INF
	var avoid_score := 0

	if hit:
		var dist = brain.player.global_position.distance_to(hit.position)
		avoid_score = clamp(1.0 - dist / WALL_NOTICE, 0, 1) * 120000
		best_threat_dist = min(best_threat_dist, dist)

	# Check nearby asteroids with larger notice
	for a in brain.get_tree().get_nodes_in_group("asteroids"):
		if not is_instance_valid(a):
			continue
		var ad = brain.player.global_position.distance_to(a.global_position)
		if ad < ASTEROID_NOTICE:
			var ascore = clamp(1.0 - ad / ASTEROID_NOTICE, 0, 1) * 90000
			if ascore > avoid_score:
				avoid_score = ascore
				best_threat_dist = min(best_threat_dist, ad)

	# Check nearby other players (make player avoidance higher priority and earlier)
	for p in brain.get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		if p == brain.player:
			continue
		var pd = brain.player.global_position.distance_to(p.global_position)
		if pd < PLAYER_NOTICE:
			var pscore = clamp(1.0 - pd / PLAYER_NOTICE, 0, 1) * 130000
			if pscore > avoid_score:
				avoid_score = pscore
				best_threat_dist = min(best_threat_dist, pd)

	if avoid_score == 0:
		return 0

	if brain.mode == AIBrain.Mode.COLLISION_AVOIDANCE:
		avoid_score *= 0.3

	avoid_score -= brain.avoidance_cooldown * 2000
	return avoid_score


func apply(brain, _delta):
	var p = brain.player
	var input = brain.input

	# Gather threats: wall hit, nearest asteroid, nearest player
	var hit = AIHelpers.imminent_wall_collision(brain.player, brain.input)

	var threat_node = null
	var threat_pos = Vector2.ZERO
	var threat_dist := INF

	if hit:
		threat_node = hit
		threat_pos = hit.position
		threat_dist = p.global_position.distance_to(hit.position)

	for a in brain.get_tree().get_nodes_in_group("asteroids"):
		if not is_instance_valid(a):
			continue
		var ad = p.global_position.distance_to(a.global_position)
		if ad < threat_dist and ad < ASTEROID_NOTICE:
			threat_node = a
			threat_pos = a.global_position
			threat_dist = ad

	for q in brain.get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(q) or q == p:
			continue
		var qd = p.global_position.distance_to(q.global_position)
		if qd < threat_dist and qd < PLAYER_NOTICE:
			threat_node = q
			threat_pos = q.global_position
			threat_dist = qd

	if threat_node == null:
		brain.avoidance_cooldown = 0.4
		return

	# If very close, stop and aim at the threat (for situational awareness)
	if threat_dist < 150:
		input.target_position = p.global_position
		input.target_aim = threat_pos
		return

	# Compute avoidance vector away from threat
	var away = (p.global_position - threat_pos).normalized()
	var repel_strength = clamp(1 - threat_dist / WALL_NOTICE, 0, 1)
	var repel = away * repel_strength * 900

	var slide = Vector2.ZERO
	if hit:
		var normal: Vector2 = hit.normal.normalized()
		var tangent := Vector2(-normal.y, normal.x)
		if p.velocity.dot(tangent) < 0:
			tangent = - tangent
		var hit_dist = p.global_position.distance_to(hit.position)
		var slide_strength = clamp(1 - hit_dist / 300.0, 0, 1)
		slide = tangent * 200 * slide_strength

	input.target_position = p.global_position + repel + slide
	input.target_aim = threat_pos
