class_name HUD extends Control

@onready var amount_label_template: Label = $HBoxContainer/BankAmount
@export var life_icon_scene = preload("res://extra_life_icon.tscn")
@onready var extra_lives_box := $ExtraLives

@export var base_icon_scene = preload("res://base_icon.tscn")
@onready var base_score_box = $BaseScore
@export var player: Player
@onready var game_over_label: Label = $GameOverLabel
@onready var win_label: Label = $WinLabel
@onready var paused_label: Label = $PausedLabel
@onready var coin_message_label: Label = $CoinMessageLabel

var _bank_sig = ""
var _bases_sig = ""
var _coin_message_timer := 0.0
var _lives_sig = null

func _ready() -> void:
	World.hud = self
	# Ensure the HUD root fills the viewport so children can center properly
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	_bank_sig = ""
	_bases_sig = ""
	_lives_sig = null

	_setup_message_label(game_over_label)
	_setup_message_label(win_label)
	_setup_message_label(paused_label)

func _process(_delta):
	var bank_sig = _get_bank_signature()
	if bank_sig != _bank_sig:
		_bank_sig = bank_sig
		_update_bank()

	var bases_sig = _get_bases_signature()
	if bases_sig != _bases_sig:
		_bases_sig = bases_sig
		_update_base_score()

	if not player:
		return

	var lives_sig = _get_lives_signature()
	if lives_sig != _lives_sig:
		_lives_sig = lives_sig
		_update_extra_lives()

	# Handle coin message timer
	if _coin_message_timer > 0:
		_coin_message_timer -= _delta
		if _coin_message_timer <= 0:
			coin_message_label.visible = false

func show_game_over(color: Color) -> void:
	_show_message(game_over_label, color)

func show_you_win(color: Color) -> void:
	_show_message(win_label, color)

func show_paused(color: Color) -> void:
	_show_message(paused_label, color)

func hide_paused() -> void:
	if not is_instance_valid(paused_label):
		return
	paused_label.visible = false

## Helper: Set up a fullscreen centered message label
func _setup_message_label(label: Label) -> void:
	if not is_instance_valid(label):
		return
	# Fill the screen and center its text
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.visible = false

## Helper: Show a message label with color and alpha
func _show_message(label: Label, color: Color) -> void:
	if not is_instance_valid(label):
		return
	var c := color
	c.a = 0.8
	label.modulate = c
	label.visible = true

func _update_bank():
	for child in amount_label_template.get_parent().get_children():
		if child != amount_label_template:
			child.queue_free()

	for team in World.bank.keys():
		# Only show bank for teams with alive players
		var alive_players = World.players().filter(func(p): return p.team == team)
		if alive_players.size() == 0:
			continue
		var lbl := amount_label_template.duplicate()
		lbl.text = str(int(round(World.bank[team])))
		lbl.modulate = World.team_color(team)
		amount_label_template.get_parent().add_child(lbl)

func _update_extra_lives():
	var lives: int = World.extra_lives[player.team]

	for child in extra_lives_box.get_children():
		child.queue_free()

	if lives <= 0:
		extra_lives_box.visible = false
		return

	extra_lives_box.visible = true

	for i in lives:
		var icon = life_icon_scene.instantiate()
		extra_lives_box.add_child(icon)

		if icon.has_method("set_color"):
			icon.set_color(World.team_color(player.team))

func _update_base_score():
	for child in base_score_box.get_children():
		child.queue_free()
		
	for base in get_tree().get_nodes_in_group("bases"):
		var icon = base_icon_scene.instantiate()
		base_score_box.add_child(icon)
		if icon.has_method("set_color"):
			icon.set_color(World.team_color(base.team))


func _get_bank_signature() -> String:
	var parts := []
	for team in World.bank.keys():
		# Only include teams with alive players
		var alive_players = World.players().filter(func(p): return p.team == team)
		if alive_players.size() == 0:
			continue
		parts.append(str(team) + ":" + str(int(round(World.bank[team]))))
	parts.sort()
	return ",".join(parts)

func _get_bases_signature() -> String:
	var parts := []
	for base in get_tree().get_nodes_in_group("bases"):
		if not is_instance_valid(base):
			continue
		parts.append(str(base.team))
	parts.sort()
	return ",".join(parts)

func _get_lives_signature() -> String:
	if not player:
		return ""
	return str(player.team) + ":" + str(int(World.extra_lives.get(player.team, 0)))

## Show a coin pickup message for 1 second
func show_coin_message(message: String, color: Color) -> void:
	if not is_instance_valid(coin_message_label):
		return
	coin_message_label.text = message
	var c := color
	c.a = 0.8
	coin_message_label.modulate = c
	coin_message_label.visible = true
	_coin_message_timer = 2.0
