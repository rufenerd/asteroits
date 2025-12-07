class_name CoinUResources extends Coin

func apply(player : Player):
	World.bank[player.team] += 10000
