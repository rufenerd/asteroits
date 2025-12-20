class_name TutorialManager extends Node

class Level:
	var title: String
	var message: String
	var check_condition: Callable
	
	func _init(p_title: String, p_message: String, p_check: Callable):
		title = p_title
		message = p_message
		check_condition = p_check

var levels: Array[Level] = []
var current_level_index := 0
var tutorial_hud: Control
var player: Player
var level_start_time := 0.0
var level_start_position := Vector2.ZERO
var is_transitioning := false

# Level-specific tracking
var bullets_fired_this_level := 0
var walls_built_this_level := 0
var harvesters_built_this_level := 0
var level_start_bank := 0

func _ready():
	process_mode = PROCESS_MODE_PAUSABLE
	# Wait one frame for player to be ready
	await get_tree().process_frame
	_find_player()
	_find_hud()
	_setup_levels()
	_start_level(0)

func _find_player():
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		player = players[0]

func _find_hud():
	# Find TutorialHUD in the scene
	var parent = get_parent()
	if parent:
		var hud_layer = parent.get_node_or_null("TutorialHUDLayer")
		if hud_layer:
			tutorial_hud = hud_layer.get_node_or_null("TutorialHUD")

func _setup_levels():
	# Level 1: Fly around
	levels.append(Level.new(
		"LEVEL 1: FLY AROUND",
		"Use the left stick to fly around.",
		func():
			var time_elapsed = Time.get_ticks_msec() / 1000.0 - level_start_time
			if time_elapsed < 10.0:
				return false
			if not player or not is_instance_valid(player):
				return false
			var distance = player.global_position.distance_to(level_start_position)
			return distance > 100.0
	))
	
	# Level 2: Shoot
	levels.append(Level.new(
		"LEVEL 2: SHOOT",
		"Use the right stick to aim and shoot. Fire 5 shots.",
		func():
			# Count new bullets created during this level
			var current_bullets = get_tree().get_nodes_in_group("bullets")
			for bullet in current_bullets:
				if is_instance_valid(bullet) and "team" in bullet and bullet.team == player.team:
					if not bullet.has_meta("counted_for_tutorial"):
						bullet.set_meta("counted_for_tutorial", true)
						bullets_fired_this_level += 1
			return bullets_fired_this_level >= 5
	))
	
	# Level 3: Build a wall
	levels.append(Level.new(
		"LEVEL 3: BUILD A WALL",
		"Press Z to build a wall. Build 3 walls.",
		func():
			var walls = get_tree().get_nodes_in_group("walls")
			for wall in walls:
				if is_instance_valid(wall) and "team" in wall and wall.team == player.team:
					if not wall.has_meta("counted_for_tutorial"):
						wall.set_meta("counted_for_tutorial", true)
						walls_built_this_level += 1
			return walls_built_this_level >= 3
	))
	
	# Level 4: Harvest resources
	levels.append(Level.new(
		"LEVEL 4: HARVEST RESOURCES",
		"Press C over resource tiles to build harvesters. Gain 100 resources.",
		func():
			if not player or not is_instance_valid(player):
				return false
			var player_bank = World.bank.get(player.team, 0)
			var gained = player_bank - level_start_bank
			return gained >= 100
	))
	
	# Level 5: Complete
	levels.append(Level.new(
		"TUTORIAL COMPLETE",
		"You've learned the basics! Press Pause to return to menu.",
		func():
			return false  # Never auto-complete, player must press pause
	))

func _process(delta):
	if current_level_index >= levels.size() or is_transitioning:
		return
	
	var current_level = levels[current_level_index]
	if current_level.check_condition.call():
		_complete_level()

func _start_level(index: int):
	if index >= levels.size():
		return
	
	current_level_index = index
	var level = levels[index]
	is_transitioning = false
	
	# Record starting state
	level_start_time = Time.get_ticks_msec() / 1000.0
	if player and is_instance_valid(player):
		level_start_position = player.global_position
		level_start_bank = World.bank.get(player.team, 0)
	
	# Reset level-specific counters
	bullets_fired_this_level = 0
	walls_built_this_level = 0
	harvesters_built_this_level = 0
	
	# Update HUD
	if tutorial_hud and is_instance_valid(tutorial_hud):
		tutorial_hud.show_level(level.title, level.message)
	
	print("Started: ", level.title)

func _complete_level():
	if is_transitioning:
		return
	is_transitioning = true
	
	print("Completed: ", levels[current_level_index].title)
	
	# Wait a moment before starting next level
	await get_tree().create_timer(1.5).timeout
	
	current_level_index += 1
	if current_level_index < levels.size():
		_start_level(current_level_index)
	else:
		if tutorial_hud and is_instance_valid(tutorial_hud):
			tutorial_hud.hide_level()
		is_transitioning = false
