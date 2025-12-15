extends AIMode
class_name BuildShield

func score(brain):
	var team = brain.player.team
	var bank = World.bank.get(team, 0)
	var shield_missing = not brain.player.shield or not is_instance_valid(brain.player.shield)
	var boost_score = 0
	if bank >= 1000 and shield_missing:
		boost_score = 3000
	elif bank >= 1000 and brain.player.shield.health > 3:
		if randf() < 0.001:
			boost_score = 3000
		else:
			boost_score = 0
	elif bank >= 1000:
		boost_score = 1500
	return boost_score + int(modes_score_bonus(brain))

func apply(brain, _delta):
	brain.input.boost_shield = true

func modes_score_bonus(_brain):
	return 0
