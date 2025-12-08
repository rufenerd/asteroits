class_name AIPlayer extends Node2D

func _ready() -> void:
	$Player.team = "ai1"
	$Player/Sprite2D.modulate = World.colors[$Player.team]
	$Player.global_position = Vector2(1960, 660)
	$Player/Camera2D.queue_free()
