extends AIMode
class_name TurretMode

func score(brain: AIBrain) -> float:
	var turret = AIHelpers.find_nearest_turret(brain)
	if turret == null:
		return 0.0
	var d = brain.player.global_position.distance_to(turret.global_position)
	if d <= 1000.0:
		return 4000.0
	return 0.0

func apply(brain: AIBrain, _delta: float) -> void:
	var turret = AIHelpers.find_nearest_turret(brain)
	if turret == null:
		return

	brain.input.target_position = brain.player.global_position
	AIHelpers.smart_shoot(brain.player, brain.input, brain.get_viewport(), turret.global_position)
