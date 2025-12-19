extends Node
class_name AIBrain

enum Mode {UNSTICK, HARVEST, COMBAT, COLLISION_AVOIDANCE, TURRET, BASE_CAPTURE, ASTEROID, WANDER}

var player: Player
var input: AIInput

var mode = Mode.HARVEST
var mode_timer = 0.0

# Personality multipliers (tunable per AI)
var combat_multiplier := 1.0
var base_multiplier := 1.0
var asteroid_multiplier := 1.0

enum BuildStrategy {SHIELD, TURRET, WALL, HORDE}
var build_strategy = BuildStrategy.SHIELD
var build_strategies = {}

var nearest_enemy = null
var previous_position = null
var avoidance_cooldown = 0.0

var mode_age := 0.0
var wander_cooldown := 0.0

var unstick_time = 0.0
var unstick_dir = Vector2.ZERO

var braking = false
var shoot_cooldown := 0.0

# Helper utilities
@onready var helpers := AIHelpers.new()

# Mode instances
var modes = {}

func _ready():
	player = $"../Player"
	player.team = "ai1"
	input = AIInput.new()
	player.input = input
	
	# Apply difficulty modifiers to personality multipliers
	var difficulty_mod := _get_difficulty_modifier()
	combat_multiplier *= difficulty_mod
	base_multiplier *= difficulty_mod
	asteroid_multiplier *= difficulty_mod

	modes = {
		Mode.UNSTICK: load("res://ai/modes/unstick_mode.gd").new(),
		Mode.HARVEST: load("res://ai/modes/harvest_mode.gd").new(),
		Mode.COMBAT: load("res://ai/modes/combat_mode.gd").new(),
		Mode.COLLISION_AVOIDANCE: load("res://ai/modes/collision_avoidance_mode.gd").new(),
		Mode.TURRET: load("res://ai/modes/turret_mode.gd").new(),
		Mode.BASE_CAPTURE: load("res://ai/modes/base_capture_mode.gd").new(),
		Mode.ASTEROID: load("res://ai/modes/asteroid_mode.gd").new(),
		Mode.WANDER: load("res://ai/modes/wander_mode.gd").new(),
	}

	build_strategies = {
		BuildStrategy.SHIELD: load("res://ai/modes/build_shield.gd").new(),
		BuildStrategy.TURRET: load("res://ai/modes/build_turret.gd").new(),
		BuildStrategy.WALL: load("res://ai/modes/build_wall.gd").new(),
		BuildStrategy.HORDE: load("res://ai/modes/build_horde.gd").new(),
	}

func _physics_process(delta):
	if not is_instance_valid(player):
		return

	avoidance_cooldown = max(avoidance_cooldown - delta, 0)
	wander_cooldown = max(wander_cooldown - delta, 0)
	shoot_cooldown = max(shoot_cooldown - delta, 0)
	nearest_enemy = AIHelpers.find_nearest_enemy(self)

	input.build_turret = false
	input.build_wall = false
	input.boost_shield = false
	input.turbo = false

	var prev_mode = mode
	choose_mode(delta)
	update_mode_age(delta, prev_mode)
	#print(Mode.find_key(mode))
	modes[mode].apply(self, delta)

	choose_build_strategy(delta)
	build_strategies[build_strategy].apply(self, delta)
	previous_position = player.global_position

	input.build_harvester = true


func choose_mode(delta):
	mode_timer -= delta
	if mode_timer > 0:
		return
	mode_timer = randf_range(0.5, 1.5)

	var best_score = - INF
	var best_mode = mode

	for m in modes.keys():
		var s = modes[m].score(self)
		match m:
			Mode.COMBAT:
				s += (combat_multiplier - 1.0) * 1000
				s *= combat_multiplier
			Mode.BASE_CAPTURE:
				s += (base_multiplier - 1.0) * 1000
				s *= base_multiplier
			Mode.ASTEROID:
				s += (asteroid_multiplier - 1.0) * 1000
				s *= asteroid_multiplier
		if s > best_score:
			best_score = s
			best_mode = m

	print("Chose mode: %s (score: %f)" % [Mode.find_key(best_mode), best_score])
	mode = best_mode

func update_mode_age(delta, prev_mode):
	if mode != prev_mode:
		mode_age = 0.0
	else:
		mode_age += delta

func choose_build_strategy(delta):
	var best_score = - INF
	var best_strategy = build_strategy

	for s in build_strategies.keys():
		var sc = build_strategies[s].score(self)
		if sc > best_score:
			best_score = sc
			best_strategy = s

	build_strategy = best_strategy

func _get_difficulty_modifier() -> float:
	var diff = World.difficulty
	if diff == World.Difficulty.EASY:
		return 0.5
	elif diff == World.Difficulty.HARD:
		return 1.5
	else:
		return 1.0
