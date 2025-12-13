class_name HUD extends Control

@onready var amount_label_template: Label = $HBoxContainer/BankAmount
@export var life_icon_scene = preload("res://extra_life_icon.tscn")
@onready var extra_lives_box := $ExtraLives

@export var base_icon_scene = preload("res://base_icon.tscn")
@onready var base_score_box = $BaseScore
@export var player : Player

func _ready() -> void:
	World.hud = self

func _process(_delta):
	_update_bank()
	_update_base_score()
	if not player:
		return
	_update_extra_lives()

func _update_bank():
	for child in amount_label_template.get_parent().get_children():
		if child != amount_label_template:
			child.queue_free()

	for team in World.bank.keys():
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
