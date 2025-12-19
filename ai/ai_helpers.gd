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


static func is_aligned_with_target(player: Player, target_position: Vector2, threshold := 0.95) -> bool:
	var direction_to_target = (target_position - player.global_position).normalized()
	var player_forward = Vector2.RIGHT.rotated(player.rotation)
	return direction_to_target.dot(player_forward) > threshold


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
	var aligned = is_aligned_with_target(player, desired_position)

	# Add steering error based on difficulty
	var steering_target = desired_position
	var diff = World.difficulty
	if diff == World.Difficulty.EASY:
		# Add significant steering error
		var error = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		steering_target += error
	# Normal and Hard have perfect steering
	
	if distance < speed_limit_distance and distance > 0.5 * speed_limit_distance and speed > max_speed and not aligned:
		brain.braking = true
		input.target_position = player.global_position
	else:
		input.target_position = player.global_position + (steering_target - player.global_position).normalized() * distance


static func imminent_wall_collision(brain):
	var player = brain.player
	var input = brain.input
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


static func find_nearest_unowned_base(brain) -> Node2D:
	var player = brain.player
	var bases = brain.get_tree().get_nodes_in_group("bases")
	return _closest_in_list(player.global_position, bases, func(b):
		if b.team == player.team:
			return false
		return true
	)


static func smart_shoot(brain, aim_for_position):
	var player = brain.player
	var input = brain.input
	var viewport = brain.get_viewport()
	
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
	
	# Adjust aim based on difficulty
	var aim_pos = aim_for_position
	var diff = World.difficulty
	
	if diff == World.Difficulty.EASY:
		# Large aiming error
		var error_angle = randf_range(-0.3, 0.3) # ~17 degrees
		var dir = (aim_pos - player.global_position).normalized()
		var error_offset = dir.rotated(error_angle) * distance * 0.2
		aim_pos += error_offset
	elif diff == World.Difficulty.HARD:
		# Predictive leading - iteratively calculate intercept point
		if result and result.collider and result.collider.is_in_group("players"):
			var target = result.collider
			var target_pos = target.global_position
			var target_velocity = target.velocity if "velocity" in target else Vector2.ZERO
			var bullet_speed = 1000.0
			
			if target_velocity != Vector2.ZERO:
				# Iteratively solve for intercept point (up to 5 iterations for accuracy)
				var predicted_pos = target_pos
				for i in range(5):
					var to_predicted = predicted_pos - player.global_position
					var dist_to_predicted = to_predicted.length()
					if dist_to_predicted < 1.0:
						break
					var time_to_impact = dist_to_predicted / bullet_speed
					predicted_pos = target_pos + target_velocity * time_to_impact
				
				aim_pos = predicted_pos
	
	# Handle shoot cooldown for EASY difficulty
	if diff == World.Difficulty.EASY:
		if brain.shoot_cooldown <= 0:
			input.target_aim = aim_pos
			brain.shoot_cooldown = 0.8 # 800ms between shots
		else:
			# Cooldown active - prevent firing by aiming at self
			input.target_aim = player.global_position
	else:
		input.target_aim = aim_pos # Normal and Hard shoot freely

static func find_nearest_turret(brain):
	var player = brain.player
	var nodes = brain.get_tree().get_nodes_in_group("turrets")

	return _closest_in_list(player.global_position, nodes, func(t):
		if t.team == player.team:
			return false
		return true
	)
