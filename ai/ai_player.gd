class_name AIPlayer extends Node2D

func _ready() -> void:
	$Player.team = "ai1"
	World.register_player($Player)
	$Player/Sprite2D.modulate = World.colors[$Player.team]
	$Player.global_position = World.spawn_points[$Player.team]
	$Player/Camera2D.queue_free()
