class_name AIBrain
extends Node

enum Mode { UNSTICK, HARVEST, COMBAT, RETREAT }

var mode := Mode.HARVEST
var player: Player
var input: AIInput

var mode_timer := 0.0

var nearest_enemy: Player = null

var previous_position = null

func _ready() -> void:
	player = $"../Player"
	player.team = "ai1"
	var ai_input = AIInput.new()
	player.input = ai_input
	input = player.input

func _physics_process(delta):
	if not is_instance_valid(player):
		return

	nearest_enemy = find_nearest_enemy()

	choose_mode(delta)

	match mode:
		Mode.UNSTICK:
			unstick_mode()
		Mode.HARVEST:
			harvest_mode()
		Mode.COMBAT:
			combat_mode()
		Mode.RETREAT:
			retreat_mode()

	previous_position = player.global_position

func choose_mode(delta):
	mode_timer -= delta
	if mode_timer > 0:
		return

	mode_timer = randf_range(0.3, 1.0)

	var unstick_score = score_unstick()
	var harvest_score = score_harvest()
	var combat_score = score_combat()
	var retreat_score = score_retreat()

	mode = Mode.HARVEST
	var best = harvest_score

	if unstick_score > best:
		mode = Mode.UNSTICK
		best = unstick_score

	if combat_score > best:
		mode = Mode.COMBAT
		best = combat_score

	if retreat_score > best:
		mode = Mode.RETREAT
		best = retreat_score

func score_unstick():
	if previous_position and player.global_position.distance_to(previous_position) < 1.0:
		return 10000
	return 0

func score_harvest():
	return clamp(1000 - World.bank[player.team], 0, 1000)

func score_combat():
	if not nearest_enemy:
		return 0
	return 800 - player.global_position.distance_to(nearest_enemy.global_position)

func score_retreat():
	return clamp(1 - player.health, 0, 1) * 2000


func harvest_mode():
	var resource = find_best_resource()
	if not resource:
		return

	get_to_with_braking(resource.global_position)

	if player.global_position.distance_to(resource.global_position) < 100:
		input.build_harvester = true
	
	shoot_at_nearest_enemy()

func combat_mode():
	if not nearest_enemy:
		return

	input.target_position = nearest_enemy.global_position
	shoot_at_nearest_enemy()

func unstick_mode():
	input.target_position = Vector2(1000, 1000).rotated(randf() * TAU)
	input.target_aim = player.global_position

func shoot_at_nearest_enemy():
	if not nearest_enemy:
		return
	smart_shoot(nearest_enemy.global_position)

func smart_shoot(target_position):
	var distance = player.global_position.distance_to(target_position)
	if distance > 1500:
		input.target_aim = player.global_position
		return

	var space_state = get_viewport().get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		player.global_position,
		target_position
	)
	query.exclude = [self, player]

	var result = space_state.intersect_ray(query)
	if result and result.collider.is_in_group("harvesters") and result.collider.team == player.team:
		input.target_aim = player.global_position
		return

	input.target_aim = target_position

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
		var dist2 = player.global_position.distance_squared_to(r.global_position)
		var score = - 1 * dist2

		if score > best_score:
			best_score = score
			best = r

	return best

func get_to_with_braking(desired_position):
	var distance = player.global_position.distance_to(desired_position)
	if distance < 100 and player.velocity.length() > 500:
		input.target_position = player.global_position
	else:
		input.target_position = desired_position
