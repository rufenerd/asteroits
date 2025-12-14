extends Explodable

@export var bullet_scene: PackedScene

func _ready():
	add_to_group("turrets")

@export
var fire_cooldown = 0.5
var fire_timer = 1.0

var cell: Vector2i
var team

func _physics_process(delta):
	fire_timer -= delta
	if fire_timer <= 0.0:
		shoot_bullet()
		fire_timer = fire_cooldown

func shoot_bullet():
	var bullet = bullet_scene.instantiate()
	bullet.direction = Vector2.RIGHT.rotated(rotation)
	bullet.origin = self
	bullet.team = team

	var team_col = World.colors.get(team, Color.WHITE)
	var c: Color
	if typeof(team_col) == TYPE_STRING:
		c = Color.from_string(team_col, Color.WHITE)
	else:
		c = team_col
	bullet.modulate = c.lerp(Color.WHITE, 0.3) * 2.5

	var nose_offset := Vector2(16, 0).rotated(rotation)
	bullet.global_position = global_position + nose_offset

	get_parent().add_child(bullet)
