class_name Wall extends Explodable

var cell : Vector2i
var team = null

func _ready():
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))
	health = 5
	add_to_group("walls")

func _on_area_entered(area):
	_handle_hit(area)

func _on_body_entered(body):
	_handle_hit(body)

func _handle_hit(target):
	if target.has_method("on_hit"):
		target.on_hit(1, global_position)

	if target is not Bullet:
		on_hit(5, global_position)
