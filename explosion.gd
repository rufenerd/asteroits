extends Node2D

@export var target_frames := 3     # how many frames to show total
var frame_count := 0
var target_node: Node = null
var killing := false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	rotation = randf() * TAU

	anim.speed_scale = 3.0
	anim.play("explode")

	# Important: NO freeing directly from frame_changed
	anim.frame_changed.connect(_on_frame_changed)

func _on_frame_changed():
	if killing:
		return

	frame_count += 1

	if frame_count >= target_frames:
		killing = true

		# optional payload (damage, cleanup, etc.)
		if target_node:
			target_node.queue_free()
			target_node = null

		# stop drawing this frame
		visible = false

		# free safely AFTER rendering
		call_deferred("queue_free")
