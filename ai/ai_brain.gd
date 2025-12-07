class_name AIBrain
extends Node

enum Mode { HARVEST, COMBAT, RETREAT }

var mode := Mode.HARVEST
var player: Player
var input: AIInput

var mode_timer := 0.0

var nearest_enemy: Player = null

func _ready() -> void:
	player = $"../Player"
	player.team = "ai1"
	var ai_input = AIInput.new()
	player.input = ai_input
	input = player.input

func _physics_process(delta):
	if not is_instance_valid(player):
		return

	var nearest_enemy = find_nearest_enemy()
	choose_mode(delta)

	match mode:
		Mode.HARVEST:
			harvest_mode()
		Mode.COMBAT:
			combat_mode()
		Mode.RETREAT:
			retreat_mode()

func choose_mode(delta):
	mode_timer -= delta
	if mode_timer > 0:
		return

	mode_timer = randf_range(0.3, 1.0)

	var harvest_score = score_harvest()
	var combat_score = score_combat()
	var retreat_score = score_retreat()

	mode = Mode.HARVEST
	var best = harvest_score

	if combat_score > best:
		mode = Mode.COMBAT
		best = combat_score

	if retreat_score > best:
		mode = Mode.RETREAT
	
func score_harvest():
	return clamp(1000 - World.bank[player.team], 0, 1000)

func score_combat():
	var enemy = find_nearest_enemy()
	if not enemy:
		return 0
	return 800 - player.global_position.distance_to(enemy.global_position)

func score_retreat():
	return clamp(1 - player.health, 0, 1) * 2000


func harvest_mode():
	var resource = find_best_resource()
	if not resource:
		return

	input.target_position = resource.global_position
	input.target_aim = Vector2.ZERO

	if player.global_position.distance_to(resource.global_position) < 100:
		input.build_harvester = true

func combat_mode():
	var enemy = find_nearest_enemy()
	if not enemy:
		return

	input.target_position = enemy.global_position
	input.target_aim = enemy.global_position

func retreat_mode():
	var threat = find_nearest_enemy()
	if not threat:
		return

	var away = (player.global_position - threat.global_position).normalized()
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
