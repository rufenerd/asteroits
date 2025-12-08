extends Node2D

@export var total_frames := 3
var target_node: Node = null
var frame_count := 0

func _ready():
	rotation = randf() * TAU
	var anim = $AnimatedSprite2D
	anim.speed_scale = 3.0

	anim.play("explode")
	anim.connect("frame_changed", Callable(self, "_on_frame_changed"))
	anim.connect("animation_finished", Callable(self, "_on_anim_finished"))
	anim.sprite_frames.set_animation_loop("explode", false)

func _on_frame_changed():
	frame_count += 1
	if frame_count >= total_frames and target_node:
		target_node.queue_free()
		target_node = null  # avoid double-freeing
		$AnimatedSprite2D.queue_free()
		queue_free()
