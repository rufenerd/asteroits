class_name Coin extends Area2D

func _ready():
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_area_entered(area):
	_handle_hit(area)

func _on_body_entered(body):
	_handle_hit(body)

func _handle_hit(target):
	if target is Player:
		apply(target)
		queue_free()

func apply(player: Player):
	pass
	
