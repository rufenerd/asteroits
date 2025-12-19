class_name CoinExtraLife extends Coin

func apply(player: Player):
	World.extra_lives[player.team] += 1
	if World.hud and World.hud.player == player:
		World.hud.show_coin_message("EXTRA LIFE", World.team_color(player.team))
