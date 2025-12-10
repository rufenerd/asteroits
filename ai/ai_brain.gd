class_name AIBrain
extends Node

enum Mode { UNSTICK, HARVEST, COMBAT, RETREAT, COLLISION_AVOIDANCE, BASE_CAPTURE }

var mode := Mode.HARVEST
var player: Player
var input: AIInput

var mode_timer := 0.0

var nearest_enemy: Player = null

var previous_position = null

var avoidance_cooldown := 0.0

var unstick_time := 0.0
var unstick_dir := Vector2.ZERO

func _ready() -> void:
	player = $"../Player"
	player.team = "ai1"
	var ai_input = AIInput.new()
	player.input = ai_input
	input = player.input

func _physics_process(delta):
	if not is_instance_valid(player):
		return

	var prev_mode = mode
	avoidance_cooldown = max(avoidance_cooldown - delta, 0.0)

	nearest_enemy = find_nearest_enemy()

	choose_mode(delta)

	match mode:
		# COIN, BASE, ASTEROID, AVOID_BULLETS
		Mode.UNSTICK:
			unstick_mode()
		Mode.HARVEST:
			harvest_mode()
		Mode.COMBAT:
			combat_mode()
		Mode.RETREAT:
			retreat_mode()
		Mode.COLLISION_AVOIDANCE:
			collision_avoidance_mode()
		Mode.BASE_CAPTURE:
			base_capture_mode()

	input.boost_shield = true
	
	if prev_mode == Mode.UNSTICK and mode != Mode.UNSTICK:
		unstick_time = 0.0

	previous_position = player.global_position
	

func choose_mode(delta):
	mode_timer -= delta
	if mode_timer > 0:
		return

	mode_timer = randf_range(0.3, 1.0)

	var unstick_score = score_unstick()
	var avoid_score = score_collision_avoidance()
	var harvest_score = score_harvest()
	var combat_score = score_combat()
	var retreat_score = score_retreat()
	var base_score = score_base_capture()

	mode = Mode.HARVEST
	var best = harvest_score

	if unstick_score > best:
		mode = Mode.UNSTICK
		best = unstick_score

	if avoid_score > best:
		mode = Mode.COLLISION_AVOIDANCE
		best = avoid_score

	if combat_score > best:
		mode = Mode.COMBAT
		best = combat_score

	if retreat_score > best:
		mode = Mode.RETREAT
		best = retreat_score

	if base_score > best:
		mode = Mode.BASE_CAPTURE
		best = base_score

func score_unstick():
	if not previous_position:
		return 0

	var moved = player.global_position.distance_to(previous_position)
	if moved < 1.5 and player.velocity.length() < 30:
		return 6000
	return 0

func score_harvest():
	return clamp(1100 - World.bank[player.team], 0, 1100)

func score_combat():
	if not nearest_enemy:
		return 0
	return 1000 - player.global_position.distance_to(nearest_enemy.global_position)

func score_retreat():
	return clamp(1 - player.health, 0, 1) * 2000

func score_collision_avoidance():
	var hit = imminent_wall_collision()
	if not hit:
		return 0
	var dist = player.global_position.distance_to(hit.position)

	var score = clamp(1.0 - dist / 300.0, 0, 1) * 100000

	if mode == Mode.COLLISION_AVOIDANCE:
		score *= 0.3

	score -= avoidance_cooldown * 2000

	return score

func score_base_capture() -> float:
	var my_bases := 0
	var opponent_bases := {}

	for b in get_tree().get_nodes_in_group("bases"):
		if not is_instance_valid(b):
			continue

		if b.team == player.team:
			my_bases += 1
		else:
			if not opponent_bases.has(b.team):
				opponent_bases[b.team] = 0
			opponent_bases[b.team] += 1

	for team_id in opponent_bases.keys():
		if team_id != "neutral" and opponent_bases[team_id] >= my_bases + 2:
			return 3001

	var nearest_unowned = find_nearest_unowned_base()
	if nearest_unowned:
		var dist = player.global_position.distance_to(nearest_unowned.global_position)
		if dist < 500:
			return 2000

	if my_bases >= 3:
		if nearest_unowned:
			return 1500

	return 0


func find_nearest_unowned_base(target_team=null):
	var best = null
	var best_dist := INF

	for b in get_tree().get_nodes_in_group("bases"):
		if not is_instance_valid(b):
			continue

		if b.team == player.team:
			continue
		if target_team != null and b.team != target_team:
			continue

		var dist = player.global_position.distance_squared_to(b.global_position)
		if dist < best_dist:
			best_dist = dist
			best = b

	return best

func collision_avoidance_mode():
	var hit = imminent_wall_collision()
	if hit.is_empty():
		avoidance_cooldown = 0.4
		return

	var normal: Vector2 = hit.normal.normalized()
	var hit_dist := player.global_position.distance_to(hit.position)

	if hit_dist < 120.0:
		input.target_position = player.global_position
		input.target_aim = player.global_position
		return

	var repel_strength = clamp(1.0 - hit_dist / 300.0, 0, 1)
	var repel = normal * repel_strength * 600.0

	var tangent := Vector2(-normal.y, normal.x)

	if player.velocity.dot(tangent) < 0:
		tangent = -tangent

	var slide = tangent * 200.0 * repel_strength

	var target = player.global_position + \
		repel + \
		slide

	input.target_position = target
	input.target_aim = player.global_position

func harvest_mode():
	var resource = find_best_resource()
	if not resource:
		return
	input.build_harvester = true

	get_to_with_braking(resource.global_position)

	shoot_at_nearest_enemy()

func combat_mode():
	if not nearest_enemy:
		return

	input.target_position = nearest_enemy.global_position
	shoot_at_nearest_enemy()

func unstick_mode():
	if unstick_time <= 0.0:
		unstick_time = randf_range(0.4, 0.8)

		var base_dir: Vector2

		if player.velocity.length() > 10:
			base_dir = -player.velocity.normalized()
		else:
			base_dir = Vector2.RIGHT.rotated(player.rotation)

		unstick_dir = base_dir.rotated(randf_range(-PI / 3, PI / 3))

	input.target_position = player.global_position + unstick_dir * 400
	input.target_aim = player.global_position

	unstick_time -= get_physics_process_delta_time()

func base_capture_mode():
	var nearest_base: Base = null
	var my_bases = 0
	var opponent_bases = {}

	for b in get_tree().get_nodes_in_group("bases"):
		if not is_instance_valid(b):
			continue
		if b.team == player.team:
			my_bases += 1
		else:
			if not opponent_bases.has(b.team):
				opponent_bases[b.team] = 0
			opponent_bases[b.team] += 1

	# 1. Opponent ahead by 3+
	for team_id in opponent_bases.keys():
		if opponent_bases[team_id] >= my_bases + 3:
			nearest_base = find_nearest_unowned_base(team_id)
			break

	# 2 & 3 fallback
	if nearest_base == null:
		nearest_base = find_nearest_unowned_base()

	if nearest_base:
		get_to_with_braking(nearest_base.global_position)
		shoot_toward_base(nearest_base.global_position)

func shoot_toward_base(target_position: Vector2):
	var nearby_enemy = find_nearest_enemy()
	if nearby_enemy:
		var dist = player.global_position.distance_to(nearby_enemy.global_position)
		if dist < 800:  # arbitrary shooting distance
			smart_shoot(nearby_enemy.global_position)
			return

	smart_shoot(target_position)

func shoot_at_nearest_enemy():
	if not nearest_enemy:
		return

	smart_shoot(nearest_enemy.global_position)

func smart_shoot(aim_for_position):
	var distance = player.global_position.distance_to(aim_for_position)
	if distance > 1500:
		input.target_aim = player.global_position
		return

	var space_state = get_viewport().get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		player.global_position,
		aim_for_position
	)
	query.exclude = [self, player]

	var result = space_state.intersect_ray(query)
	if result and result.collider.is_in_group("harvesters") and result.collider.team == player.team:
		input.target_aim = player.global_position
		return

	input.target_aim = aim_for_position

func retreat_mode():
	if not nearest_enemy:
		return

	var away = (player.global_position - nearest_enemy.global_position).normalized()
	input.target_position = player.global_position + away * 500

func find_nearest_enemy() -> Player:
	var closest: Player = null
	var closest_dist := INF

	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue

		if p == player:
			continue
			
		if p.team == player.team:
			continue

		var d = player.global_position.distance_squared_to(p.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = p

	return closest

func find_best_resource():
	var best = null
	var best_score := -INF

	for r in get_tree().get_nodes_in_group("resources"):
		if not is_instance_valid(r):
			continue
		if r.harvester != null:
			continue

		var dist2 = player.global_position.distance_squared_to(r.global_position)
		var score = - 1 * dist2

		if score > best_score:
			best_score = score
			best = r

	return best


var braking = false
func get_to_with_braking(desired_position):
	var direction = desired_position - player.global_position
	var distance = direction.length()
	if distance == 0:
		return

	if braking:
		if player.velocity.length() > 0:
			input.target_position = player.global_position
			return
		else:
			braking = false

	var speed := player.velocity.length()
	var max_speed := 100.0
	var speed_limit_distance := 300.0

	var to_target = direction.normalized()

	if distance < speed_limit_distance and distance > 0.5 * speed_limit_distance and speed > max_speed:
		braking = true
		input.target_position = player.global_position
	else:
		input.target_position = player.global_position + to_target * distance

func imminent_wall_collision() -> Dictionary:
	var dir := Vector2.ZERO

	if player.velocity.length() > 50:
		dir = player.velocity.normalized()
	elif input.target_position:
		dir = (input.target_position - player.global_position).normalized()
	else:
		return {}

	var space_state = get_viewport().get_world_2d().direct_space_state
	var lookahead := 200.0
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
