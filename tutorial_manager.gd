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
var game_hud: CanvasLayer
var player: Player
var level_start_time := 0.0
var level_start_position := Vector2.ZERO
var is_transitioning := false

# Level-specific tracking
var bullets_fired_this_level := 0
var walls_built_this_level := 0
var harvesters_built_this_level := 0
var level_start_bank := 0
var level_start_zoom := 0.0

func _ready():
	process_mode = PROCESS_MODE_PAUSABLE
	# Wait one frame for player to be ready
	await get_tree().process_frame
	_find_player()
	_find_hud()
	_find_game_hud()
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

func _find_game_hud():
	# Find the game HUD in the scene - it's a CanvasLayer
	var parent = get_parent()
	if parent:
		game_hud = parent.get_node_or_null("HUD")

func _setup_levels():
	# Level 1: Fly around
	levels.append(Level.new(
		"LEVEL 1: FLY AROUND",
		"Use the left stick to fly around.",
		func():
			var time_elapsed = Time.get_ticks_msec() / 1000.0 - level_start_time
			if time_elapsed < 2.0:
				return false
			if not player or not is_instance_valid(player):
				return false
			var distance = player.global_position.distance_to(level_start_position)
			return distance > 200.0
	))
	
	# Level 2: Shoot
	levels.append(Level.new(
		"LEVEL 2: SHOOT",
		"Use the right stick to aim and shoot.",
		func():
			# Count new bullets created during this level
			var current_bullets = get_tree().get_nodes_in_group("bullets")
			for bullet in current_bullets:
				if is_instance_valid(bullet) and "team" in bullet and bullet.team == player.team:
					if not bullet.has_meta("counted_for_tutorial"):
						bullet.set_meta("counted_for_tutorial", true)
						bullets_fired_this_level += 1
			return bullets_fired_this_level >= 10
	))


	# Level 3: Zoom out
	levels.append(Level.new(
		"LEVEL 3: ZOOM OUT",
		"Press '.' (period) or L1 to zoom out all the way.",
		func():
			if not player or not is_instance_valid(player):
				return false
			var camera = player.get_node_or_null("Camera2D")
			if not camera or not is_instance_valid(camera):
				return false
			var current_zoom = camera.zoom.x
			if current_zoom <= 1.0:
				print("Level 3 complete - zoomed out to: ", current_zoom)
				return true
			return false
	))
	
	# Level 4: Zoom in
	levels.append(Level.new(
		"LEVEL 4: ZOOM IN",
		"Press ',' (comma) or R1 to zoom in once.",
		func():
			if not player or not is_instance_valid(player):
				return false
			var camera = player.get_node_or_null("Camera2D")
			if not camera or not is_instance_valid(camera):
				return false
			var current_zoom = camera.zoom.x
			if current_zoom > level_start_zoom:
				print("Level 4 complete - zoomed in to: ", current_zoom, " from: ", level_start_zoom)
				return true
			return false
	))
	
	# Level 5: Harvest resources
	levels.append(Level.new(
		"LEVEL 5: HARVEST RESOURCES",
		"Hold the circle button and fly over circles to build harvesters to gain resources. Gain 1000 resources.",
		func():
			if not player or not is_instance_valid(player):
				return false
			var player_bank = World.bank.get(player.team, 0)
			var gained = player_bank - level_start_bank
			return gained >= 1000
	))
	
	# Level 6: Build walls
	levels.append(Level.new(
		"LEVEL 6: BUILD WALLS",
		"Press square to build a wall for 200 resources. Build 3 walls.",
		func():
			var walls = get_tree().get_nodes_in_group("walls")
			for wall in walls:
				if is_instance_valid(wall) and "team" in wall and wall.team == player.team:
					if not wall.has_meta("counted_for_tutorial"):
						wall.set_meta("counted_for_tutorial", true)
						walls_built_this_level += 1
			return walls_built_this_level >= 3
	))
	
	# Level 7: Build turrets
	levels.append(Level.new(
		"LEVEL 7: BUILD TURRETS",
		"Press triangle to build a turret in the direction you are facing for 200 resources. Build 5 (and keep) turrets.",
		func():
			var turrets = get_tree().get_nodes_in_group("turrets")
			return turrets.size() >= 5
	))

	# Level 8: Complete
	levels.append(Level.new(
		"TUTORIAL COMPLETE",
		"You've learned the basics! Press Pause to return to menu.",
		func():
			return false # Never auto-complete, player must press pause
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
		var camera = player.get_node_or_null("Camera2D")
		if camera and is_instance_valid(camera):
			level_start_zoom = camera.zoom.x
			print("Level ", index, " started with zoom: ", level_start_zoom)
	
	# Reset level-specific counters
	bullets_fired_this_level = 0
	walls_built_this_level = 0
	harvesters_built_this_level = 0
	
	# Show game HUD starting at level 5 (index 4) - harvest resources level
	if game_hud and is_instance_valid(game_hud):
		game_hud.visible = (index >= 4)
		# Hide everything except bank when showing HUD
		if game_hud.visible:
			var control = game_hud.get_node_or_null("Control")
			if control:
				var extra_lives = control.get_node_or_null("ExtraLives")
				if extra_lives:
					extra_lives.visible = false
				var base_score = control.get_node_or_null("BaseScore")
				if base_score:
					base_score.visible = false
		var player_indicators = game_hud.get_node_or_null("PlayerIndicators")
		if player_indicators:
			player_indicators.visible = false
	
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
