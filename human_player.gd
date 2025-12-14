class_name HumanPlayer extends Node2D

func _ready():
	var player = get_node_or_null("Player")
	if player:
		var human_input = HumanInput.new()
		player.input = human_input
		World.register_player(player)

func _process(delta: float) -> void:
	var player = get_node_or_null("Player")
	if not player or not is_instance_valid(player):
		return

	if World.hud and not World.hud.player:
		World.hud.player = player
