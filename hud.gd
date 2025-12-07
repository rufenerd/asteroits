extends Control

@onready var amount_label: Label = $BankAmount
@export var life_icon_scene = preload("res://extra_life_icon.tscn")
@onready var extra_lives_box := $ExtraLives

func _ready():
	_update_bank()
	_update_extra_lives()

func _process(_delta):
	_update_bank()
	_update_extra_lives()

func _update_bank():
	amount_label.text = str(World.bank["player"])
	amount_label.modulate = World.colors["player"]

func _update_extra_lives():
	var lives: int = World.extra_lives["player"]

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
			icon.set_color(World.colors["player"])
