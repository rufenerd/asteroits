extends AIMode
class_name BaseCaptureMode

func score(brain):
	var p = brain.player
	var my_bases = 0
	var opponents = {}

	var bases = brain.get_tree().get_nodes_in_group("bases")
	for b in bases:
		if not is_instance_valid(b):
			continue
		if b.team == p.team:
			my_bases += 1
		else:
			opponents[b.team] = opponents.get(b.team, 0) + 1

	for team_id in opponents.keys():
		if team_id != "neutral" and opponents[team_id] >= my_bases + 2:
			return 3001

	var nearest_unowned = AIHelpers.find_nearest_unowned_base(brain.player, bases)
	if nearest_unowned:
		var dist = p.global_position.distance_to(nearest_unowned.global_position)
		if dist < 500:
			return 2000

	if my_bases >= 3 and nearest_unowned:
		return 1500

	return 0

func apply(brain, delta):
	var bases = brain.get_tree().get_nodes_in_group("bases")
	var nearest_base = AIHelpers.find_nearest_unowned_base(brain.player, bases)
	if nearest_base:
		AIHelpers.get_to_with_braking(brain, nearest_base.global_position)
		brain.input.target_aim = brain.player.global_position
