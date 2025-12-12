extends Node
class_name AIBrain

enum Mode { UNSTICK, HARVEST, COMBAT, COLLISION_AVOIDANCE, BASE_CAPTURE }

var player: Player
var input: AIInput

var mode = Mode.HARVEST
var mode_timer = 0.0

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
		Mode.BASE_CAPTURE: load("res://ai/modes/base_capture_mode.gd").new(),
	}

func _physics_process(delta):
	if not is_instance_valid(player):
		return

	avoidance_cooldown = max(avoidance_cooldown - delta, 0)
	nearest_enemy = AIHelpers.find_nearest_enemy(self)

	choose_mode(delta)
	modes[mode].apply(self, delta)

	input.boost_shield = true
	previous_position = player.global_position

func choose_mode(delta):
	mode_timer -= delta
	if mode_timer > 0:
		return
	mode_timer = randf_range(0.3, 1.0)

	var best_score = -INF
	var best_mode = mode

	for m in modes.keys():
		var s = modes[m].score(self)
		if s > best_score:
			best_score = s
			best_mode = m

	mode = best_mode
