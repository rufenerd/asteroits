extends AIMode
class_name BuildHorde

func score(brain):
	var team = brain.player.team
	var bank = World.bank.get(team, 0)
	var max_player_bank = 0
	for p in World.players():
		var other_team = p.team
		if typeof(other_team) == TYPE_STRING:
			if str(team) == other_team:
				continue
		else:
			if other_team == team:
				continue

		var p_bank = World.bank.get(other_team, 0)
		if p_bank > max_player_bank:
			max_player_bank = p_bank
	if bank - max_player_bank > 20000:
		return 5000
	return 100


func apply(brain, _delta):
	brain.input.build_turret = false
	brain.input.build_wall = false
	brain.input.build_harvester = false
	brain.input.boost_shield = false
