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
var asteroids_hit_this_level := 0
var coins_collected_this_level := 0
var bases_captured_this_level := 0
var level_start_shield := 0
var level_start_asteroid_count := 0
var turbo_time := 0.0
var ai_player: Node2D = null
var level_start_color: Color

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
		"LEVEL 1: FLY",
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
		"Press L1 a few times to zoom out all the way.",
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
		"Press R1 to zoom in.",
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
		"LEVEL 5: HARVESTERS",
		"Hold the circle button and fly over circles to build harvesters to produce resources. Accumulate 1000 resources.",
		func():
			if not player or not is_instance_valid(player):
				return false
			return World.bank.get(player.team, 0) >= 1000
	))
	
	# Level 6: Mines
	levels.append(Level.new(
		"LEVEL 6: MINES",
		"Press square to build a mine for 200 resources. Mines will heavily damage colliding enemy. Build 3 mines.",
		func():
			var walls = get_tree().get_nodes_in_group("walls")
			for wall in walls:
				if is_instance_valid(wall) and "team" in wall and wall.team == player.team:
					if not wall.has_meta("counted_for_tutorial"):
						wall.set_meta("counted_for_tutorial", true)
						walls_built_this_level += 1
			return walls_built_this_level >= 3
	))
	
	# Level 7: Turrets
	levels.append(Level.new(
		"LEVEL 7: TURRETS",
		"Press triangle to build a turret in the direction you are facing for 200 resources. Turrets shoot enemies that cross its path. Build 5 turrets.",
		func():
			var turrets = get_tree().get_nodes_in_group("turrets")
			return turrets.size() >= 5
	))
	
	# Level 8: Find asteroids
	levels.append(Level.new(
		"LEVEL 8: ASTEROIDS",
		"The nav shows the direction to asteroids. Find one and shoot it to break it up.",
		func():
			return asteroids_hit_this_level >= 1
	))
	
	# Level 9: Collect coins
	levels.append(Level.new(
		"LEVEL 9: COINS",
		"Small asteroids have a 1 in 10 chance of dropping a valuable bonus coin. Get a coin!",
		func():
			return coins_collected_this_level >= 1
	))
		# Level 10: Turbo
	levels.append(Level.new(
		"LEVEL 10: TURBO",
		"Hold L2+R2 and move to use turbo. Turbo costs more the longer you use it. Maintain turbo velocity for 1 second.",
		func():
			return turbo_time >= 1.0
	))
		# Level 11: Capture bases
	levels.append(Level.new(
		"LEVEL 11: BASES",
		"Find and capture a base by flying over it.",
		func():
			return bases_captured_this_level >= 1
	))
	
	# Level 12: Shield boost
	levels.append(Level.new(
		"LEVEL 12: SHIELD",
		"Hold X for 1 second to activate or boost your shield for 1000 resources. Boost shield to level 3.",
		func():
			if not player or not is_instance_valid(player):
				return false
			if not player.shield or not is_instance_valid(player.shield):
				return false
			var shield_level = player.shield.health
			return shield_level >= 3
	))
	
	# Level 13: Change color
	levels.append(Level.new(
		"LEVEL 13: CHANGE COLOR",
		"Press D-pad down to change your ship color.",
		func():
			if not player or not is_instance_valid(player):
				return false
			var current_color = World.team_color(player.team)
			return current_color != level_start_color
	))
	
	# Level 14: Combat
	levels.append(Level.new(
		"LEVEL 14: COMBAT",
		"Defeat the enemy player before game over.",
		func():
			# Check if AI player node exists
			if ai_player == null or not is_instance_valid(ai_player):
				return true
			# Check if AI player's Player child exists
			var ai_player_node = ai_player.get_node_or_null("Player")
			if ai_player_node == null or not is_instance_valid(ai_player_node):
				return true
			# Check if AI player has no extra lives and check if any players in their team are alive
			var players = get_tree().get_nodes_in_group("players")
			var ai_team_alive = false
			for p in players:
				if is_instance_valid(p) and "team" in p and p.team == ai_player_node.team:
					ai_team_alive = true
					break
			return not ai_team_alive
	))

	# Level 15: Complete
	levels.append(Level.new(
		"TUTORIAL COMPLETE",
		"To win a full game, capture all 4 bases or be the last of four players remaining. Press Start to pause during a game or return to the menu now.",
		func():
			return false # Never auto-complete, player must press pause
	))

func _process(delta):
	if current_level_index >= levels.size() or is_transitioning:
		return
	
	# Check for game over and return to menu
	if World.match_has_ended:
		_handle_game_over()
		return
	
	# Track turbo time for level 10 (index 9)
	if current_level_index == 9 and player and is_instance_valid(player):
		if player.turbo:
			turbo_time += delta
	
	# Track asteroid hits for level 8 (index 7)
	if current_level_index == 7:
		var current_asteroid_count = World.asteroid_count
		# If total asteroid count increased from start, asteroids were split (hit)
		if current_asteroid_count > level_start_asteroid_count:
			asteroids_hit_this_level += 1
			level_start_asteroid_count = current_asteroid_count # Update for next hit
	
	# Track coin collection for level 9 (index 8)
	if current_level_index == 8:
		var coins = get_tree().get_nodes_in_group("coins")
		for coin in coins:
			if is_instance_valid(coin) and coin.has_meta("counted_for_tutorial"):
				continue
			# Check if coin is about to be collected (very close to player)
			if player and is_instance_valid(player):
				var distance = coin.global_position.distance_to(player.global_position)
				if distance < 20.0: # Close enough to be collected soon
					coin.set_meta("counted_for_tutorial", true)
					coins_collected_this_level += 1
	
	# Track base captures for level 11 (index 10)
	if current_level_index == 10 and player and is_instance_valid(player):
		var bases = get_tree().get_nodes_in_group("bases")
		for base in bases:
			if is_instance_valid(base) and "team" in base:
				if base.team == player.team and not base.has_meta("counted_for_tutorial"):
					base.set_meta("counted_for_tutorial", true)
					bases_captured_this_level += 1
	
	var current_level = levels[current_level_index]
	if current_level.check_condition.call():
		_complete_level()
func _handle_game_over():
	if is_transitioning:
		return
	is_transitioning = true
	
	# Hide tutorial HUD
	if tutorial_hud and is_instance_valid(tutorial_hud):
		tutorial_hud.hide_level()
	
	# Wait a moment then fade to black and return to menu
	await get_tree().create_timer(1.0).timeout
	World.return_to_title_screen_with_fade()
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
	asteroids_hit_this_level = 0
	coins_collected_this_level = 0
	bases_captured_this_level = 0
	turbo_time = 0.0
	
	# Record starting shield level for shield level
	if player and is_instance_valid(player) and player.shield and is_instance_valid(player.shield):
		level_start_shield = player.shield.health
	
	# Record starting asteroid count for asteroid level
	level_start_asteroid_count = World.asteroid_count
	
	# Record starting color for color change level
	if player and is_instance_valid(player):
		level_start_color = World.team_color(player.team)
	
	# Spawn AI player for level 14 (index 13) - combat level
	if index == 13:
		var ai_scene = preload("res://ai/ai_player.tscn")
		ai_player = ai_scene.instantiate()
		get_tree().current_scene.add_child(ai_player)
		# Wait for AI player to be ready and registered
		await get_tree().process_frame
		var ai_player_node = ai_player.get_node_or_null("Player")
		if ai_player_node:
			World.set_extra_lives(ai_player_node, 0)
			print("AI player spawned for combat level with 0 extra lives")
	
	# Show game HUD starting at level 5 (index 4) - harvest resources level
	if game_hud and is_instance_valid(game_hud):
		game_hud.visible = (index >= 4)
		# Hide everything except bank when showing HUD
		if game_hud.visible:
			var control = game_hud.get_node_or_null("Control")
			if control:
				var extra_lives = control.get_node_or_null("ExtraLives")
				if extra_lives:
					# Show extra lives starting at level 14 (index 13) - combat level
					extra_lives.visible = (index >= 13)
				var base_score = control.get_node_or_null("BaseScore")
				if base_score:
					# Show base score starting at level 11 (index 10) - bases level
					base_score.visible = (index >= 10)
		var player_indicators = game_hud.get_node_or_null("PlayerIndicators")
		if player_indicators:
			# Show player indicators starting at level 8 (index 7) - asteroids level
			player_indicators.visible = (index >= 7)
	
	# Update HUD
	if tutorial_hud and is_instance_valid(tutorial_hud):
		tutorial_hud.show_level(level.title, level.message)
	
	print("Started: ", level.title)

func _complete_level():
	if is_transitioning:
		return
	is_transitioning = true
	
	print("Completed: ", levels[current_level_index].title)
	
	# Brief pause before starting next level
	await get_tree().create_timer(0.3).timeout
	
	current_level_index += 1
	if current_level_index < levels.size():
		_start_level(current_level_index)
	else:
		if tutorial_hud and is_instance_valid(tutorial_hud):
			tutorial_hud.hide_level()
		is_transitioning = false
