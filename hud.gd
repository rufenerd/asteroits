extends Control

@onready var amount_label: Label = $BankAmount

func _ready():
	_update_bank()
	#amount_label.add_theme_color_override("font_color", Color.YELLOW)

func _process(_delta):
	_update_bank()

func _update_bank():
	amount_label.text = str(World.bank["player"])
