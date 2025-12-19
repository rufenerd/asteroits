extends AIMode
class_name HarvestMode

func score(brain):
	return 100 + 10.0 * clamp(1100 - World.get_bank(brain.player), 0, 1100)

func apply(brain, _delta):
	var resource = AIHelpers.find_best_resource(brain)

	if not resource or not is_instance_valid(resource):
		return

	brain.input.build_harvester = true
	AIHelpers.get_to_with_braking(brain, resource.global_position)

	if brain.nearest_enemy:
		AIHelpers.smart_shoot(brain, brain.nearest_enemy.global_position)
