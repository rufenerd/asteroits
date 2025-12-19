extends AIMode
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

	# If we're near a friendly base that lacks defenses, score highly to build there
	var bases = brain.get_tree().get_nodes_in_group("bases")
	var DEFENSE_RADIUS := 600.0
	for b in bases:
		if not is_instance_valid(b):
			continue
		if b.team != team:
			continue
		var dist_to_base = brain.player.global_position.distance_to(b.global_position)
		if dist_to_base <= 500.0:
			# count turrets + walls near the base
			var defenses := 0
			for t in brain.get_tree().get_nodes_in_group("turrets"):
				if not is_instance_valid(t):
					continue
				if t.global_position.distance_to(b.global_position) <= DEFENSE_RADIUS:
					defenses += 1
			for w in brain.get_tree().get_nodes_in_group("walls"):
				if not is_instance_valid(w):
					continue
				if w.global_position.distance_to(b.global_position) <= DEFENSE_RADIUS:
					defenses += 1

			if defenses < 20:
				return int(3500 - dist_to_base) + 50 % randi()

	return 0

func apply(brain, _delta):
	brain.input.build_turret = true
	var angle = (randi() % 4) * (PI / 2.0)
	brain.input.target_position = brain.player.global_position + Vector2.RIGHT.rotated(angle) * 100.0
