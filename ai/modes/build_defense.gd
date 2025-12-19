extends AIMode
class_name BuildDefense

const DEFENSE_RADIUS := 600.0
const BASE_CHECK_RADIUS := 500.0

## Count defenses near a position
func count_defenses_near(brain, position: Vector2, radius: float) -> int:
	var defenses := 0
	for t in brain.get_tree().get_nodes_in_group("turrets"):
		if not is_instance_valid(t):
			continue
		if t.global_position.distance_to(position) <= radius:
			defenses += 1
	for w in brain.get_tree().get_nodes_in_group("walls"):
		if not is_instance_valid(w):
			continue
		if w.global_position.distance_to(position) <= radius:
			defenses += 1
	return defenses

## Find nearest friendly base that needs defense
func find_base_needing_defense(brain, max_defenses: int) -> Node2D:
	var team = brain.player.team
	var bases = brain.get_tree().get_nodes_in_group("bases")
	
	for b in bases:
		if not is_instance_valid(b):
			continue
		if b.team != team:
			continue
		var dist_to_base = brain.player.global_position.distance_to(b.global_position)
		if dist_to_base <= BASE_CHECK_RADIUS:
			var defenses = count_defenses_near(brain, b.global_position, DEFENSE_RADIUS)
			if defenses < max_defenses:
				return b
	
	return null

## Calculate base defense score
func calculate_defense_score(brain, base: Node2D) -> int:
	var dist_to_base = brain.player.global_position.distance_to(base.global_position)
	return int(3500 - dist_to_base) + (randi() % 50)
