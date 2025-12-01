extends Node2D

@export var speed := 400.0
@export var lifetime := 0.7 # seconds
var direction := Vector2.RIGHT
var time_alive := 0.0

func _physics_process(delta):
	position += direction * speed * delta

	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
