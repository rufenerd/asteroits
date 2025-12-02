class_name Explodable extends Node2D

func on_hit():
	var explosion = preload("res://Explosion.tscn").instantiate()
	explosion.global_position = global_position
	explosion.target_node = self
	get_tree().current_scene.add_child(explosion)
