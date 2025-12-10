class_name AIPlayer extends Node2D

func _ready() -> void:
	$Player.team = "ai-" + str(randi() % 100_000_000)
	World.register_player($Player)
	$Player/Sprite2D.modulate = World.colors[$Player.team]
	$Player.global_position = World.spawn_points[$Player.team]
	$Player/Camera2D.queue_free()
