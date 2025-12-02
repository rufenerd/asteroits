extends Area2D

@export var speed := 200.0
@export var lifetime := 1.0
var direction := Vector2.RIGHT
var time_alive := 0.0

func _ready():
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_area_entered(area):
	_handle_hit(area)

func _on_body_entered(body):
	_handle_hit(body)

func _handle_hit(target):
	if target.has_method("on_hit"):
		target.on_hit()
	queue_free()

func _physics_process(delta):
	position += direction * speed * delta

	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
