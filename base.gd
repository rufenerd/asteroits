class_name Base extends Area2D

# Team can be string "neutral" or int team ids
var team = "neutral"

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Node2D = $Sprite2D

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	add_to_group("bases")

func _on_body_entered(body: Node):
	if body is Player:
		# Only host processes base capture
		if not multiplayer.is_server():
			return
		print("Base capture: player team %s capturing base at %s (current team: %s)" % [body.team, global_position, team])
		team = body.team
		if World.colors.has(team):
			visual.modulate = World.team_color(team)
		# Sync base capture to clients
		World._rpc_capture_base.rpc(get_path(), team)
