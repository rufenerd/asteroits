extends AIMode
class_name BuildWall

func score(brain):
	var team = brain.player.team
	var bank = World.bank.get(team, 0)
	if bank < 200 or brain.player.velocity.length() < 50.0:
		return 0

	var bases = brain.get_tree().get_nodes_in_group("bases")
	var DEFENSE_RADIUS := 600.0
	for b in bases:
		if not is_instance_valid(b):
			continue
		if b.team != team:
			continue
		var dist_to_base = brain.player.global_position.distance_to(b.global_position)
		if dist_to_base <= 500.0:
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

			if defenses < 8:
				return int(5500 - dist_to_base)

	var s = 500
	if brain.mode == AIBrain.Mode.BASE_CAPTURE:
		s += 1500
	return s

func apply(brain, _delta):
	brain.input.build_wall = true
