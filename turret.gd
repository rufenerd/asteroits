extends Node2D

@export var bullet_scene: PackedScene

@export
var fire_cooldown = 0.5

var fire_timer = 0.0

func _physics_process(delta):
	fire_timer -= delta
	if fire_timer <= 0.0:
		shoot_bullet()
		fire_timer = fire_cooldown

func shoot_bullet():
	var bullet = bullet_scene.instantiate()
	bullet.direction = Vector2.RIGHT.rotated(rotation)
	bullet.global_position = global_position

	get_parent().add_child(bullet)
