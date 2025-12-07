class_name AIInput
extends PlayerInput

var target_position: Vector2
var target_aim: Vector2

var stick_smooth := 8.0
var aim_smooth := 10.0
var jitter := 0.05

func update(player: Node2D, delta: float):
	if target_position == null:
		return

	# Direction toward target
	var desired_dir = (target_position - player.global_position)
	if desired_dir.length() > 0.01:
		desired_dir = desired_dir.normalized()
	else:
		desired_dir = Vector2.ZERO

	# Smoothly interpolate move input
	move = move.lerp(desired_dir, stick_smooth * delta)

	# Add small jitter
	move += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	move = move.limit_length(1.0)

	# Aim
	if target_aim != Vector2.ZERO:
		var aim_dir = (target_aim - player.global_position).normalized()
		aim = aim.lerp(aim_dir, aim_smooth * delta)
