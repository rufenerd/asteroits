class_name CoinUResources extends Coin

func apply(player: Player):
	World.bank[player.team] += 10000
	if World.hud and World.hud.player == player:
		World.hud.show_coin_message("+10,000", World.team_color(player.team))
