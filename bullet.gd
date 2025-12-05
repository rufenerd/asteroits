class_name Bullet extends Area2D

@export var speed := 1000.0
@export var lifetime := 1.0
var direction := Vector2.RIGHT
var time_alive := 0.0

var previous_position: Vector2

var damage = 1

func _ready():
	previous_position = global_position

func _physics_process(delta):
	var velocity = direction * speed
	var new_position = global_position + velocity * delta

	var space = get_world_2d().direct_space_state
	
	var query = PhysicsRayQueryParameters2D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = true
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
