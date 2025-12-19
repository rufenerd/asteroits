extends AIMode
class_name CombatMode

func score(brain):
	if not brain.nearest_enemy:
		return 0

	var core_score = (3000 * brain.player.weapon_level)
	if World.get_bank(brain.player) > 20000:
		return core_score
	return core_score  - brain.player.global_position.distance_to(brain.nearest_enemy.global_position)

func apply(brain, delta):
	if not brain.nearest_enemy:
		return

	brain.input.target_position = brain.nearest_enemy.global_position
	AIHelpers.smart_shoot(brain, brain.nearest_enemy.global_position)
