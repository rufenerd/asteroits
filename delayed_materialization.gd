extends Node2D

@export var delay_seconds: float = 0.2

func _ready() -> void:
	_suppress_collisions()

func _suppress_collisions() -> void:
	var parent = get_parent()
	if parent == null:
		return

	# Collect CollisionShape2D children
	var collisions: Array = []
	for child in parent.get_children():
		if child is CollisionShape2D:
			collisions.append(child)

	# Disable them
	for c in collisions:
		c.disabled = true

	# Wait for delay
	var timer = get_tree().create_timer(delay_seconds)
	await timer.timeout

	# Re-enable collisions
	for c in collisions:
		c.disabled = false
