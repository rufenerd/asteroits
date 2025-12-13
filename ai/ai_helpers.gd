extends Node
class_name AIHelpers

static func _closest_in_list(position: Vector2, nodes: Array, predicate = null):
	var best = null
	var best_dist := INF
	for n in nodes:
		if predicate != null:
			if predicate is Callable:
				if not predicate.call(n):
					continue
			else:
				continue
		if not is_instance_valid(n):
			continue
		var d = position.distance_squared_to(n.global_position)
		if d < best_dist:
			best_dist = d
			best = n
	return best


static func find_nearest_enemy(brain) -> Player:
	var player = brain.player
	var nodes = brain.get_tree().get_nodes_in_group("players")
	return _closest_in_list(player.global_position, nodes, func(n):
		if n == player:
			return false
		if n.team == player.team:
			return false
		return true
	)


static func find_best_resource(brain):
	var player = brain.player
	var nodes = brain.get_tree().get_nodes_in_group("resources")
	return _closest_in_list(player.global_position, nodes, func(r):
		if r.harvester != null:
			return false
		return true
	)


static func get_to_with_braking(brain, desired_position):
	var player = brain.player
	var input = brain.input

	var direction = desired_position - player.global_position
	var distance = direction.length()
	if distance == 0:
		return

	if brain.braking:
		if player.velocity.length() > 0:
			input.target_position = player.global_position
			return
		else:
			brain.braking = false

	var speed = player.velocity.length()
	var max_speed := 100.0
	var speed_limit_distance := 300.0

	var to_target = direction.normalized()

	if distance < speed_limit_distance and distance > 0.5 * speed_limit_distance and speed > max_speed:
		brain.braking = true
		input.target_position = player.global_position
	else:
		input.target_position = player.global_position + to_target * distance


static func imminent_wall_collision(player: Player, input):
	var dir := Vector2.ZERO

	if player.velocity.length() > 50:
		dir = player.velocity.normalized()
	elif input.target_position:
		dir = (input.target_position - player.global_position).normalized()
	else:
		return {}

	var space_state = player.get_viewport().get_world_2d().direct_space_state
	var lookahead := 400.0
	var angles := [-0.35, 0.0, 0.35]

	var best_hit := {}

	for angle in angles:
		var ray_dir = dir.rotated(angle)
		var origin = player.global_position + ray_dir * 5.0

		var query := PhysicsRayQueryParameters2D.create(
			origin,
			origin + ray_dir * lookahead
		)
		query.exclude = [player]
		query.collide_with_areas = true
		query.collide_with_bodies = false

		var result = space_state.intersect_ray(query)

		if result and result.collider.is_in_group("walls"):
			if best_hit.is_empty() or result.position.distance_squared_to(player.global_position) < best_hit.position.distance_squared_to(player.global_position):
				best_hit = result

	return best_hit


static func find_nearest_unowned_base(player: Node2D, bases: Array) -> Node2D:
	return _closest_in_list(player.global_position, bases, func(b):
		if b.team == player.team:
			return false
		return true
	)


static func smart_shoot(player, input, viewport, aim_for_position):
	var distance = player.global_position.distance_to(aim_for_position)
	if distance > 1500:
		input.target_aim = player.global_position
		return
	
	var space_state = viewport.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(player.global_position, aim_for_position)
	query.exclude = [player]
	var result = space_state.intersect_ray(query)
	if result and result.collider.is_in_group("harvesters") and result.collider.team == player.team:
			input.target_aim = player.global_position
			return
	
	input.target_aim = aim_for_position


static func find_nearest_turret(brain):
	var player = brain.player
	var nodes = brain.get_tree().get_nodes_in_group("turrets")

	return _closest_in_list(player.global_position, nodes, func(t):
		if t.team == player.team:
			return false
		return true
	)
