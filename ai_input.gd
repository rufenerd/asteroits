class_name AIInput
extends PlayerInput

var target_position: Vector2
var target_aim: Vector2

var stick_smooth := 8.0
var aim_smooth := 10.0
var jitter := 0.05

func update(player: Node2D, delta: float):
	var desired = (target_position - player.global_position)
	if desired.length() > 1.0:
		desired = desired.normalized()

	move = move.lerp(desired, stick_smooth * delta)
	move += Vector2(
		randf_range(-jitter, jitter),
		randf_range(-jitter, jitter)
	)
	move = move.limit_length(1.0)

	if target_aim != Vector2.ZERO:
		var aim_dir = (target_aim - player.global_position).normalized()
		aim = aim.lerp(aim_dir, aim_smooth * delta)

	fire = aim.length() > 0.2
