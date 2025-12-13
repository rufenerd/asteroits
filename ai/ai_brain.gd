extends Node
class_name AIBrain

enum Mode {UNSTICK, HARVEST, COMBAT, COLLISION_AVOIDANCE, TURRET, BASE_CAPTURE, ASTEROID}

var player: Player
var input: AIInput

var mode = Mode.HARVEST
var mode_timer = 0.0

enum BuildStrategy {SHIELD, TURRET, WALL, HORDE}
var build_strategy = BuildStrategy.SHIELD
var build_timer = 0.0
var build_strategies = {}

var nearest_enemy = null
var previous_position = null
var avoidance_cooldown = 0.0

var unstick_time = 0.0
var unstick_dir = Vector2.ZERO

var braking = false

# Helper utilities
@onready var helpers := AIHelpers.new()

# Mode instances
var modes = {}

func _ready():
	player = $"../Player"
	player.team = "ai1"
	input = AIInput.new()
	player.input = input

	modes = {
		Mode.UNSTICK: load("res://ai/modes/unstick_mode.gd").new(),
		Mode.HARVEST: load("res://ai/modes/harvest_mode.gd").new(),
		Mode.COMBAT: load("res://ai/modes/combat_mode.gd").new(),
		Mode.COLLISION_AVOIDANCE: load("res://ai/modes/collision_avoidance_mode.gd").new(),
		Mode.TURRET: load("res://ai/modes/turret_mode.gd").new(),
		Mode.BASE_CAPTURE: load("res://ai/modes/base_capture_mode.gd").new(),
		Mode.ASTEROID: load("res://ai/modes/asteroid_mode.gd").new(),
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
	nearest_enemy = AIHelpers.find_nearest_enemy(self)

	input.build_turret = false
	input.build_wall = false
	input.boost_shield = false

	choose_mode(delta)
	modes[mode].apply(self, delta)

	choose_build_strategy(delta)
	build_strategies[build_strategy].apply(self, delta)
	previous_position = player.global_position

	input.build_harvester = true


func choose_mode(delta):
	mode_timer -= delta
	if mode_timer > 0:
		return
	mode_timer = randf_range(0.3, 1.0)

	var best_score = - INF
	var best_mode = mode

	for m in modes.keys():
		var s = modes[m].score(self)
		if s > best_score:
			best_score = s
			best_mode = m

	mode = best_mode

func choose_build_strategy(delta):
	build_timer -= delta
	if build_timer > 0:
		return
	build_timer = randf_range(0.3, 1.0)

	var best_score = - INF
	var best_strategy = build_strategy

	for s in build_strategies.keys():
		var sc = build_strategies[s].score(self)
		if sc > best_score:
			best_score = sc
			best_strategy = s

	build_strategy = best_strategy
