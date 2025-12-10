class_name HUD extends Control

@onready var amount_label: Label = $BankAmount
@export var life_icon_scene = preload("res://extra_life_icon.tscn")
@onready var extra_lives_box := $ExtraLives
@export var player : Player


func _process(_delta):
	if not World.hud:
		World.hud = self
	_update_bank()
	_update_extra_lives()

func _update_bank():
	if player and player.team in World.bank:
		amount_label.text = str(int(round(World.bank[player.team])))
		amount_label.modulate = World.colors[player.team]

func _update_extra_lives():
	if not player:
		return
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

		# Color it
		if icon.has_method("set_color"):
			icon.set_color(World.colors[player.team])
