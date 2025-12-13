extends AIMode
class_name BuildTurret

func score(brain):
    var team = brain.player.team
    var bank = World.bank.get(team, 0)
    if bank < 10:
        return 0

    var turret_score = 0
    if brain.nearest_enemy:
        var dist = brain.player.global_position.distance_to(brain.nearest_enemy.global_position)
        turret_score = 2000 - dist
    else:
        turret_score = randi() % 300

    return turret_score + int(modes_score_bonus(brain))

func apply(brain, _delta):
    brain.input.build_turret = true

func modes_score_bonus(_brain):
    return 0