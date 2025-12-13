class_name HumanPlayer extends Node2D

func _ready():
	var human_input = HumanInput.new()
	$Player.input = human_input
	World.register_player($Player)

func _process(delta: float) -> void:
	if not is_instance_valid($Player):
		return

	if World.hud and not World.hud.player:
		World.hud.player = $Player
