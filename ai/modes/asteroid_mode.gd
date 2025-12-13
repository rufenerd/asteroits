extends AIMode
class_name AsteroidMode

func _find_nearest_coin(brain):
	var best = null
	var best_dist := INF
	var root = brain.get_tree().current_scene
	if not root:
		return null

	# iterative DFS to avoid closure capture issues
	var stack = [root]
	while stack.size() > 0:
		var node = stack.pop_back()
		for c in node.get_children():
			if not is_instance_valid(c):
				continue
			if c is Coin:
				var d = brain.player.global_position.distance_squared_to(c.global_position)
				if d < best_dist:
					best_dist = d
					best = c
			stack.append(c)

	return best

func _find_nearest_asteroid(brain):
	var best = null
	var best_dist := INF
	for a in brain.get_tree().get_nodes_in_group("asteroids"):
		if not is_instance_valid(a):
			continue
		var d = brain.player.global_position.distance_squared_to(a.global_position)
		if d < best_dist:
			best_dist = d
			best = a
	return best

func score(brain):
	var coin = _find_nearest_coin(brain)
	if coin:
		var dist = brain.player.global_position.distance_to(coin.global_position)
		return 5000 - dist

	var ast = _find_nearest_asteroid(brain)
	if ast:
		var dist = brain.player.global_position.distance_to(ast.global_position)
		return 2000 - dist

	return 0

func apply(brain, _damagedelta):
	var player = brain.player
	var input = brain.input

	var coin = _find_nearest_coin(brain)
	if coin:
		AIHelpers.get_to_with_braking(brain, coin.global_position)

		var to_coin = (coin.global_position - player.global_position).normalized()
		var angle_offset = randf_range(-0.1, 0.1)
		var aim_direction = to_coin.rotated(angle_offset)
		var aim_for_position = player.global_position + aim_direction * 1000
		AIHelpers.smart_shoot(player, input, brain.get_viewport(), aim_for_position)
		return

	var ast = _find_nearest_asteroid(brain)
	if ast:
		input.target_position = ast.global_position
		AIHelpers.smart_shoot(player, input, brain.get_viewport(), ast.global_position)
		return

	# fallback: do nothing
