class_name Base extends Area2D

var team: String = "neutral"

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Node2D = $Sprite2D

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	add_to_group("bases")

func _on_body_entered(body: Node):
	if body is Player:
		team = body.team
		if World.colors.has(team):
			visual.modulate = World.team_color(team)
