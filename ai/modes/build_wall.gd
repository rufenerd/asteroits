extends AIMode
class_name BuildWall

func score(brain):
    var team = brain.player.team
    var bank = World.bank.get(team, 0)
    if bank < 10:
        return 0

    var s = 500
    if brain.mode == AIBrain.Mode.BASE_CAPTURE:
        s += 1500
    return s

func apply(brain, _delta):
    brain.input.build_wall = true
