extends CharacterBody2D

@export var deadzone := 0.2
@export var max_speed := 400.0
@export var acceleration := 800.0
@export var friction := 800.0  
@export var max_turn_speed := 5.0
@export var turn_accel := 50.0

@export var bullet_scene: PackedScene
@export var fire_cooldown := 0.2 # seconds between shots
var fire_timer := 0.0
var angular_velocity := 0.0

func _physics_process(delta):
	var input_vector = Vector2(
		Input.get_axis("left_stick_left", "left_stick_right"),
		Input.get_axis("left_stick_up", "left_stick_down")
	)

	var stick_active := input_vector.length() >= deadzone
	if stick_active:
		input_vector = input_vector.normalized()

	var forward := Vector2.RIGHT.rotated(rotation)

	if stick_active:
		velocity = velocity.move_toward(forward * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	_update_rotation_from_input(input_vector, delta)

	var aim_vector := Vector2(
		Input.get_axis("aim_left", "aim_right"),
		Input.get_axis("aim_up", "aim_down")
	)

	move_and_slide()
	
	if aim_vector.length() > deadzone:
		fire_timer -= delta
		if fire_timer <= 0.0:
			shoot_bullet(aim_vector)
			fire_timer = fire_cooldown


func _update_rotation_from_input(input_vector: Vector2, delta: float) -> void:
	if input_vector.length() < deadzone:
		angular_velocity = 0.0
		return

	input_vector = input_vector.normalized()
	var target_angle = input_vector.angle()
	var angle_diff = wrapf(target_angle - rotation, -PI, PI)

	var desired_speed = clamp(angle_diff * 8.0, -max_turn_speed, max_turn_speed)

	angular_velocity = move_toward(
		angular_velocity,
		desired_speed,
		turn_accel * delta
	)

	rotation += angular_velocity * delta

func shoot_bullet(aim_vector: Vector2):
	var bullet = bullet_scene.instantiate()

	var direction = aim_vector.normalized()
	bullet.direction = direction
	
	bullet.speed += acceleration

	var nose_offset := Vector2(8, 0).rotated(direction.angle())
	bullet.global_position = global_position + nose_offset

	get_parent().add_child(bullet)
