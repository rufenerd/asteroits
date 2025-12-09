class_name ResourceTile extends Node2D

var amount = 0
var harvester : Harvester = null

func _ready() -> void:
	add_to_group("resources")
