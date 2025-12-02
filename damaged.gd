extends Node2D

func _ready():
	rotation = randf() * TAU
	var anim = $AnimatedSprite2D
	anim.speed_scale = 3.0 
	anim.play("damaged")
	anim.connect("animation_finished", Callable(self, "_on_anim_finished"))

func _on_anim_finished():
	queue_free()
