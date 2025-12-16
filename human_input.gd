class_name HumanInput
extends PlayerInput

func update(_player, _delta):
	# Only process input if the window is focused
	if _player and not _player.get_window().has_focus():
		move = Vector2.ZERO
		aim = Vector2.ZERO
		turbo = false
		build_wall = false
		build_harvester = false
		build_turret = false
		boost_shield = false
		return
	
	move = Vector2(
		Input.get_axis("left_stick_left", "left_stick_right"),
		Input.get_axis("left_stick_up", "left_stick_down")
	)

	aim = Vector2(
		Input.get_axis("aim_left", "aim_right"),
		Input.get_axis("aim_up", "aim_down")
	)

	turbo = Input.is_action_pressed("turbo") and Input.is_action_pressed("turbo_2")

	build_wall = Input.is_action_pressed("build_wall")
	build_harvester = Input.is_action_pressed("build_harvester")
	build_turret = Input.is_action_pressed("build_turret")
	boost_shield = Input.is_action_pressed("boost_shield")
