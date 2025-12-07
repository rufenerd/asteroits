class_name CoinExtraLife extends Coin

func apply(player : Player):
	World.extra_lives[player.team] += 1
