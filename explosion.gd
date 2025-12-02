extends Node2D

@export var target_frame := 3
var target_node: Node = null

func _ready():
	var anim = $AnimatedSprite2D
	anim.speed_scale = 3.0 
	anim.play("explode")
	anim.connect("frame_changed", Callable(self, "_on_frame_changed"))
	anim.connect("animation_finished", Callable(self, "_on_anim_finished"))

func _on_frame_changed():
	if $AnimatedSprite2D.frame == target_frame and target_node:
		target_node.queue_free()

func _on_anim_finished():
	queue_free()
