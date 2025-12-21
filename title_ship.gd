extends Sprite2D

const ROTATION_SPEED = 0.5 # radians per second

func _process(delta: float) -> void:
	rotation += ROTATION_SPEED * delta
