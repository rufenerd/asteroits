class_name HumanPlayer extends Node2D

func _ready():
	var human_input = HumanInput.new()
	$Player.input = human_input
