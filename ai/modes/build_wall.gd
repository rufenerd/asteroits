extends BuildDefense
class_name BuildWall

func score(brain):
	var team = brain.player.team
	var bank = World.bank.get(team, 0)
	if bank < 200 or brain.player.velocity.length() < 50.0:
		return 0

	# Check for base needing defense (fewer walls needed than turrets)
	var base = find_base_needing_defense(brain, 8)
	if base:
		return calculate_defense_score(brain, base)

	# Random wall placement
	if randf() < 0.001:
		return 3500
	return 0

func apply(brain, _delta):
	brain.input.build_wall = true
