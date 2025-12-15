extends AIMode
class_name HarvestMode

func score(brain):
	return 1000 + clamp(1100 - World.bank[brain.player.team], 0, 1100)

func apply(brain, _delta):
	var resource = AIHelpers.find_best_resource(brain)
	if not resource or not is_instance_valid(resource):
		return

	brain.input.build_harvester = true
	AIHelpers.get_to_with_braking(brain, resource.global_position)

	if brain.nearest_enemy:
		AIHelpers.smart_shoot(brain.player, brain.input, brain.get_viewport(), brain.nearest_enemy.global_position)
