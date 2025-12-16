class_name AIPlayer extends Node2D

@export var combat_bias := 1.0
@export var base_bias := 1.0
@export var asteroid_bias := 1.0

func _ready() -> void:
	# Player registration/position handled by Player._ready using team set before instancing
	if is_instance_valid($Player/Camera2D):
		$Player/Camera2D.enabled = false

	# Propagate personality biases to the brain if present
	if has_node("AIBrain"):
		var brain = $AIBrain
		if brain:
			brain.combat_multiplier = combat_bias
			brain.base_multiplier = base_bias
			brain.asteroid_multiplier = asteroid_bias
