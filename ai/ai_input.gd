class_name AIInput
extends PlayerInput

var target_position: Vector2
var target_aim: Vector2

var jitter := 0.0
var aim_smooth := 5.0

func update(player: Node2D, delta: float):
	if target_position == null:
		return

	# Direction toward target
	var desired_dir = (target_position - player.global_position)
	if desired_dir.length() > 0.01:
		desired_dir = desired_dir.normalized()
	else:
		desired_dir = Vector2.ZERO

	move = desired_dir

	# Add small jitter
	move += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	move = move.limit_length(1.0)

	# Aim
	if target_aim != Vector2.ZERO:
		var aim_dir = (target_aim - player.global_position).normalized()
		aim = aim.lerp(aim_dir, aim_smooth * delta)
