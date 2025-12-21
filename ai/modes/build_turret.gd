extends BuildDefense
class_name BuildTurret

func score(brain):
	var team = brain.player.team
	var bank = World.bank.get(team, 0)
	# World.build charges 200 for non-harvester builds; require sufficient bank here
	if bank < 200:
		return 0

	var shield = brain.player.shield
	var shield_missing = not shield or not is_instance_valid(shield)
	if shield_missing or shield.health < 4.0:
		return 10

	if World.difficulty == World.Difficulty.EASY:
		return 0
	
	if World.difficulty == World.Difficulty.HARD:
		if randf() < 0.001:
			return 3500

	# If we're near a friendly base that lacks defenses, score highly to build there
	var base = find_base_needing_defense(brain, 20)
	if base:
		return calculate_defense_score(brain, base)

	return 0

func apply(brain, _delta):
	brain.input.build_turret = true
	var angle = (randi() % 4) * (PI / 2.0)
	brain.input.target_position = brain.player.global_position + Vector2.RIGHT.rotated(angle) * 100.0
