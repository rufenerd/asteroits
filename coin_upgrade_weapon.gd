class_name CoinUpgradeWeapon extends Coin

func apply(player: Player):
	player.upgrade_weapon()
	if World.hud and World.hud.player == player:
		World.hud.show_coin_message("WEAPON SYSTEMS UPGRADED", World.team_color(player.team))
