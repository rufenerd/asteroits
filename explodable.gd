class_name Explodable extends Node2D

var health = 1

func on_hit(damage, _origin):
	health -= damage

	if health <= 0:
		var explosion = preload("res://explosion.tscn").instantiate()
		explosion.global_position = global_position
		explosion.target_node = self
		get_tree().current_scene.add_child(explosion)
	else:
		var damaged =  preload("res://damaged.tscn").instantiate()
		damaged.global_position = global_position
		get_tree().current_scene.add_child(damaged)
