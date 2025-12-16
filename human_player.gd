class_name HumanPlayer extends Node2D

func _ready():
	var player = get_node_or_null("Player")
	if player:
		var my_id = multiplayer.get_unique_id()
		print("HumanPlayer._ready() - player.peer_id=%d, my_id=%d, team=%d" % [player.peer_id, my_id, player.team])
		# Only attach human input if this client owns this player
		if player.peer_id == my_id:
			var human_input = HumanInput.new()
			player.input = human_input
			print("  -> Attached HumanInput")
		else:
			print("  -> Did NOT attach (not mine)")

func _process(delta: float) -> void:
	var player = get_node_or_null("Player")
	if not player or not is_instance_valid(player):
		return

	# Only track HUD for this client's own player
	if player.peer_id == multiplayer.get_unique_id() and World.hud and not World.hud.player:
		World.hud.player = player
