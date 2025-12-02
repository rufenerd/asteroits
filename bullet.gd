extends Area2D

@export var speed := 200.0
@export var lifetime := 1.0
var direction := Vector2.RIGHT
var time_alive := 0.0

var previous_position: Vector2

var damage = 1

func _ready():
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))
	previous_position = global_position

func _on_area_entered(area):
	_handle_hit(area)

func _on_body_entered(body):
	_handle_hit(body)

func _handle_hit(target):
	if target.has_method("on_hit"):
		target.on_hit(damage)
	queue_free()

func _physics_process(delta):
	var velocity = direction * speed
	var new_position = global_position + velocity * delta

	var space = get_world_2d().direct_space_state
	
	var query = PhysicsRayQueryParameters2D.new()
	query.from = previous_position
	query.to = new_position
	query.exclude = [self]
	query.collision_mask = collision_mask
	var result = space.intersect_ray(query)

	if result:
		var hit = result.collider
		if hit.has_method("on_hit"):
			hit.on_hit(damage)
		queue_free()
		return

	global_position = new_position
	previous_position = new_position

	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
