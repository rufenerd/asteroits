extends Node

const CELL_SIZE = 16
const NUM_CELLS_IN_ROW = 625
const BOUNDS := Rect2(0, 0, NUM_CELLS_IN_ROW * CELL_SIZE, NUM_CELLS_IN_ROW * CELL_SIZE)
const MAX_RESOURCE_START_AMOUNT = 1000
const NUM_RESOURCE_CLUSTERS = 20
const MIN_RESOURCES_IN_CLUSTER = 25
const MAX_RESOURCES_IN_CLUSTER = 50
const MAX_CLUSTER_RADIUS = 20
const STARTING_RESOURCES = 0

var asteroid_count := 0
var board = {}
var resources = {}

var bank = {}
var extra_lives = {}
var spawn_points = {}

enum Difficulty {EASY, NORMAL, HARD}

var hud: HUD
var spectator_mode := false
var player_order: Array = []
var game_over_ai_buffed := false
var is_paused := false
var difficulty := Difficulty.HARD

#green 39FF14
#pink DA14FE
#blue 00F0FF
#orange FE6414
#yellow FEDA14
var colors = {"neutral": Color.WHITE}

var available_colors = [
	Color8(57, 255, 20), # 39FF14
	Color8(218, 20, 254), # DA14FE
	Color8(0, 240, 255), # 00F0FF
	Color8(254, 218, 20), # FEDA14
	Color8(254, 100, 20) # FE6414
]
var available_spawn_locations = [Vector2(400, 400), Vector2(400, 9600), Vector2(9600, 400), Vector2(9600, 9600)]

func _ready():
	# Allow World to always process (including when paused) so unpause works
	# But child nodes will be pausable by default
	process_mode = PROCESS_MODE_ALWAYS
	
	initialize_clustered_resources(NUM_RESOURCE_CLUSTERS, MIN_RESOURCES_IN_CLUSTER, MAX_RESOURCES_IN_CLUSTER, MAX_CLUSTER_RADIUS)
	initialize_bases()
	spawn_initial_asteroid()

func _physics_process(delta):
	# Don't run game logic when paused
	if is_paused:
		return
	check_win_conditions()
	# In spectator mode, inputs are handled in _input/_unhandled_input.

func _unhandled_input(event):
	if not spectator_mode:
		return
	if event.is_action_pressed("boost_shield"):
		_switch_camera_next()

func _input(event):
	# Handle pause first - input events fire even when paused
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return

	# Rotate all team colors on demand (active during play or spectator)
	if event.is_action_pressed("rotate_colors"):
		rotate_colors()
		apply_team_colors()
		get_viewport().set_input_as_handled()
		return
	
	# Also listen in _input to ensure we catch inputs even if some UI consumes them.
	if not spectator_mode:
		return
	if event.is_action_pressed("boost_shield"):
		_switch_camera_next()
	
func register_player(player: Player):
	if player.team in extra_lives:
		return
	bank[player.team] = STARTING_RESOURCES
	extra_lives[player.team] = 2
	spawn_points[player.team] = available_spawn_locations.pop_front()
	colors[player.team] = available_colors.pop_front()
	# Track stable player order for camera handoff indices
	if not player_order.has(player):
		player_order.append(player)

func initialize_bases():
	var quadrants = [
		Rect2i(0, 0, NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2), # top left
		Rect2i(NUM_CELLS_IN_ROW / 2, 0, NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2), # top right
		Rect2i(0, NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2), # bottom left
		Rect2i(NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2, NUM_CELLS_IN_ROW / 2) # bottom right
	]
	for q in quadrants:
		var base = preload("res://base.tscn").instantiate()
		while true:
			var cell = Vector2i(
				q.position.x + randi() % q.size.x,
				q.position.y + randi() % q.size.y
			)
			if not board.has(cell) and not resources.has(cell):
				board[cell] = base
				base.global_position = cell_to_world(cell)
				base.process_mode = PROCESS_MODE_PAUSABLE
				add_child(base)
				break
		

func initialize_clustered_resources(num_clusters: int, min_resources: int, max_resources: int, max_cluster_radius: float) -> void:
	for c in range(num_clusters):
		var cluster_radius = (MAX_CLUSTER_RADIUS / 2) + randi() % (MAX_CLUSTER_RADIUS / 2)
		
		var cluster_center = Vector2i(
			randi() % NUM_CELLS_IN_ROW,
			randi() % NUM_CELLS_IN_ROW
		)

		var num_resources = randi() % (max_resources - min_resources + 1) + min_resources

		var R := int(cluster_radius)

		for i in range(num_resources):
			# Gaussian offsets (mean 0, stddev ~ R/2, adjust as needed)
			var u1 = randf()
			var u2 = randf()
			var mag = sqrt(-2.0 * log(u1))
			var z0 = mag * cos(TAU * u2) # Gaussian 0, mean 0, stddev 1
			var z1 = mag * sin(TAU * u2)

			# Scale Gaussian to desired spread
			var dx = int(z0 * (R * 0.5))
			var dy = int(z1 * (R * 0.5))

			var cell = cluster_center + Vector2i(dx, dy)

			if cell.x < 0 or cell.y < 0 or cell.x >= NUM_CELLS_IN_ROW or cell.y >= NUM_CELLS_IN_ROW:
				continue

			var resource_amount = randi() % MAX_RESOURCE_START_AMOUNT + 1
			initialize_resource(resource_amount, cell)

func initialize_resource(amount, cell: Vector2i):
	if resources.has(cell):
		return
	var resource = preload("res://resource.tscn").instantiate()
	resource.global_position = cell_to_world(cell)
	resource.amount = amount
	resources[cell] = resource
	resource.process_mode = PROCESS_MODE_PAUSABLE
	add_child(resource)

func build(node, build_position, team):
	node.modulate = colors[team]
	var cell = world_to_cell(build_position)

	if _is_inside_base_area(build_position):
		node.queue_free()
		return

	if board.has(cell):
		node.queue_free()
		return

	if node is Harvester and not resources.has(cell):
		node.queue_free()
		return
		
	if not node is Harvester:
		if bank[team] < 200:
			node.queue_free()
			return
		bank[team] -= 200

	var snapped_pos = cell_to_world(cell)
	node.global_position = snapped_pos

	node.process_mode = PROCESS_MODE_PAUSABLE
	add_child(node)

	board[cell] = node
	
	node.cell = cell

	if resources.has(cell):
		resources[cell].visible = false


func _is_inside_base_area(world_pos: Vector2) -> bool:
	# Check if position is within a base's collision radius
	for base in get_tree().get_nodes_in_group("bases"):
		if not is_instance_valid(base):
			continue
		var collision_shape = base.get_node_or_null("CollisionShape2D")
		if not collision_shape:
			continue
		var dist = world_pos.distance_to(collision_shape.global_position)
		var base_radius = 19.0 # CircleShape2D radius from base.tscn
		if dist < base_radius:
			return true
	return false

func harvest(harvester):
	var resource = resources[harvester.cell]
	resource.harvester = harvester
	if resource.amount > 0:
		resources[harvester.cell].amount -= 1
		if not harvester.team in bank:
			bank[harvester.team] = 0
		bank[harvester.team] += 1
	else:
		resource.remove_from_group("resources")
		resource.queue_free()
		harvester.remove_from_group("harvester")
		harvester.queue_free()

func asteroid_destroyed():
	asteroid_count -= 1
	if asteroid_count <= 0:
		call_deferred("spawn_initial_asteroid")

func spawn_initial_asteroid():
	var init_asteroid = preload("res://asteroid.tscn").instantiate()
	init_asteroid.process_mode = PROCESS_MODE_PAUSABLE
	var x = (randi() % NUM_CELLS_IN_ROW) * CELL_SIZE + randf_range(0, CELL_SIZE)
	var y = (randi() % NUM_CELLS_IN_ROW) * CELL_SIZE + randf_range(0, CELL_SIZE)
	init_asteroid.global_position = Vector2(x, y)
	add_child(init_asteroid)
	asteroid_count = 1

func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / CELL_SIZE)),
		int(floor(pos.y / CELL_SIZE))
	)

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x + 0.5) * CELL_SIZE,
		(cell.y + 0.5) * CELL_SIZE
	)

func check_win_conditions():
	# --- 1. All 4 bases owned by 1 team (not neutral) ---
	var base_counts := {}
	for b in get_tree().get_nodes_in_group("bases"):
		if not is_instance_valid(b):
			continue
		if b.team == "neutral":
			continue
		if not base_counts.has(b.team):
			base_counts[b.team] = 0
		base_counts[b.team] += 1

	for team_id in base_counts.keys():
		if base_counts[team_id] >= 4:
			print("%s wins by controlling all 4 bases!" % team_id)
			_call_victory_and_quit(team_id)
			return

	# --- 2. Only 1 player remains ---
	var alive_players := []
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		alive_players.append(p)

	if alive_players.size() == 1:
		var winner = alive_players[0]
		print("%s wins by being the last remaining!" % winner.team)
		_call_victory_and_quit(winner.team)
		return


func players():
	return get_tree().get_nodes_in_group("players")

func asteroids():
	return get_tree().get_nodes_in_group("asteroids")

func team_color(team: String, default := Color.WHITE) -> Color:
	# Return a Color for `team`. Accepts stored Color or hex/string.
	var raw = colors.get(team, default)
	if typeof(raw) == TYPE_STRING:
		return Color.from_string(raw, default)
	return raw

func _switch_camera_deferred(best_player):
	await get_tree().create_timer(1.0).timeout
	if best_player and is_instance_valid(best_player):
		var best_camera = best_player.get_node_or_null("Camera2D")
		if best_camera and is_instance_valid(best_camera) and best_camera.is_inside_tree():
			var current_cam = get_viewport().get_camera_2d()
			if current_cam:
				current_cam.enabled = false
			best_camera.enabled = true
			best_camera.zoom = Vector2(1, 1)
			best_camera.make_current()
# Show victory overlay (for human team) then quit after short delay
func _call_victory_and_quit(winning_team: String) -> void:
	# Enable spectator camera toggling at match end
	spectator_mode = true
	
	if hud and is_instance_valid(hud) and hud.player and is_instance_valid(hud.player):
		var player_team_color = team_color(hud.player.team)
		if hud.player.team == winning_team:
			hud.show_you_win(player_team_color)
		else:
			hud.show_game_over(player_team_color)
	
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()


# No longer using timed handoff; spectator toggling is always available after game over.


func _switch_camera_immediate(target_player):
	if not target_player or not is_instance_valid(target_player):
		return
	var cam = target_player.get_node_or_null("Camera2D")
	if not cam or not is_instance_valid(cam) or not cam.is_inside_tree():
		return
	var current_cam = get_viewport().get_camera_2d()
	if current_cam:
		current_cam.enabled = false
	cam.enabled = true
	cam.zoom = Vector2(1, 1)
	cam.make_current()

func _switch_camera_next():
	var alive_players := _alive_players_in_order()
	if alive_players.is_empty():
		return
	var current_cam = get_viewport().get_camera_2d()
	var current_index := -1
	for i in range(alive_players.size()):
		var p = alive_players[i]
		var cam = p.get_node_or_null("Camera2D")
		if cam and is_instance_valid(cam) and cam == current_cam:
			current_index = i
			break
	var next_index = (current_index + 1) % alive_players.size()
	var target = alive_players[next_index]
	_switch_camera_immediate(target)

func game_over(team: String) -> void:
	spectator_mode = true
	if hud:
		hud.show_game_over(team_color(team))
	if not game_over_ai_buffed:
		_buff_richest_ai_combat()
		game_over_ai_buffed = true

func _buff_richest_ai_combat():
	# Pick the richest alive AI and give it a massive combat multiplier
	var richest_p: Player = null
	var richest_bank := -INF
	for p in players():
		if not is_instance_valid(p):
			continue
		var parent = p.get_parent()
		if parent and parent is AIPlayer:
			var p_bank = bank.get(p.team, 0)
			if p_bank > richest_bank:
				richest_bank = p_bank
				richest_p = p
	if richest_p == null:
		return
	var richest_parent = richest_p.get_parent()
	var brain = richest_parent.get_node_or_null("AIBrain")
	if brain and is_instance_valid(brain):
		brain.combat_multiplier = 99.0
		print("Buffed AI combat multiplier for team ", richest_p.team, " with bank ", richest_bank)

func _alive_players_in_order() -> Array:
	var result: Array = []
	for p in player_order:
		if is_instance_valid(p) and p.is_in_group("players"):
			result.append(p)
	return result

func toggle_pause() -> void:
	is_paused = !is_paused
	# Use pause the scene tree properly
	get_tree().paused = is_paused
	print("Pause toggled: ", is_paused, " - Tree paused: ", get_tree().paused)
	if hud:
		if is_paused:
			var color = Color.WHITE
			if hud.player and is_instance_valid(hud.player):
				color = team_color(hud.player.team)
			hud.show_paused(color)
		else:
			hud.hide_paused()


# === Convenience methods for cleaner access ===

## Get bank for a player's team
func get_bank(player: Player) -> int:
	return bank.get(player.team, 0)

## Set bank for a player's team
func set_bank(player: Player, amount: int) -> void:
	bank[player.team] = amount

## Add to bank for a player's team
func add_bank(player: Player, amount: int) -> void:
	bank[player.team] = bank.get(player.team, 0) + amount

## Get team color for a player
func get_team_color(player: Player) -> Color:
	return team_color(player.team)

## Get extra lives for a player's team
func get_extra_lives(player: Player) -> int:
	return extra_lives.get(player.team, 0)

## Set extra lives for a player's team
func set_extra_lives(player: Player, amount: int) -> void:
	extra_lives[player.team] = amount


# === Team color rotation ===

## Rotate assigned team colors together with unassigned available colors as one ring.
## Keeps "neutral" unchanged. Applies new colors and then updates live nodes.
func rotate_colors() -> void:
	# Gather active team ids preferring stable camera order, then fill any missing
	var team_ids: Array[String] = []
	for p in _alive_players_in_order():
		if p and is_instance_valid(p):
			if not team_ids.has(p.team) and p.team != "neutral":
				team_ids.append(p.team)
	# Ensure all live teams are included even if not in player_order
	for lp in players():
		if not is_instance_valid(lp):
			continue
		if lp.team == "neutral":
			continue
		if not team_ids.has(lp.team):
			team_ids.append(lp.team)

	if team_ids.is_empty() and available_colors.is_empty():
		return

	# Build a single palette: assigned (by team order) + remaining available colors
	var palette: Array = []
	for t in team_ids:
		palette.append(colors.get(t, Color.WHITE))
	for c in available_colors:
		palette.append(c)

	if palette.is_empty():
		return

	# Shuffle entire palette instead of rotating
	if palette.size() > 1:
		palette.shuffle()

	# Reassign colors back to teams then leftover back to available_colors
	for i in range(team_ids.size()):
		colors[team_ids[i]] = palette[i]
	available_colors = palette.slice(team_ids.size(), palette.size())

## Apply current team colors to all live nodes that cache modulate
func apply_team_colors() -> void:
	# Players and their shields
	for p in players():
		if not is_instance_valid(p):
			continue
		var col := team_color(p.team)
		# Set on root as fallback in case scene differs
		if "modulate" in p:
			p.modulate = col
		var sprite := p.get_node_or_null("Sprite2D")
		if sprite and is_instance_valid(sprite):
			sprite.modulate = col
			if "self_modulate" in sprite:
				sprite.self_modulate = col
		if p.shield and is_instance_valid(p.shield):
			p.shield.modulate = col
			var ss = p.shield.get("sprite") if p.shield else null
			if ss and is_instance_valid(ss):
				ss.modulate = col
				if "self_modulate" in ss:
					ss.self_modulate = col

	# Bases (skip neutral)
	for b in get_tree().get_nodes_in_group("bases"):
		if not is_instance_valid(b):
			continue
		if not ("team" in b) or b.team == "neutral":
			continue
		var b_sprite = b.get_node_or_null("Sprite2D")
		if b_sprite and is_instance_valid(b_sprite):
			b_sprite.modulate = team_color(b.team)

	# Structures built by teams
	for group_name in ["walls", "turrets", "harvesters"]:
		for n in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(n):
				continue
			if not ("team" in n) or n.team == null:
				continue
			n.modulate = team_color(n.team)

	# Bullets (in-flight) - match tint used at spawn
	for b in get_tree().get_nodes_in_group("bullets"):
		if not is_instance_valid(b):
			continue
		if not ("team" in b) or b.team == null:
			continue
		var base_col := team_color(b.team)
		var tint := base_col.lerp(Color.WHITE, 0.3) * 2.5
		if "modulate" in b:
			b.modulate = tint
		var bs := b.get_node_or_null("Sprite2D")
		if bs and is_instance_valid(bs):
			bs.modulate = base_col
