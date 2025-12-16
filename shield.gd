class_name Shield
extends Explodable

var cell: Vector2i
var team

@export var sprite: Sprite2D

func _ready():
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_area_entered(area):
	_handle_hit(area)

func _on_body_entered(body):
	_handle_hit(body)

func enable_label():
	$ShieldHealthLabelContainer.visible = true

func disable_label():
	$ShieldHealthLabelContainer.visible = false

func _process(_delta):
	$ShieldHealthLabelContainer.global_rotation = 0
	$ShieldHealthLabelContainer/ShieldHealthLabel.text = str(health)

func _handle_hit(target):
	if "team" in target and str(target.team) == str(team):
		return
	
	if target is Base or target is Harvester:
		return

	if target.has_method("on_hit"):
		target.on_hit(1, global_position)

	if target is not Bullet and target is not Coin:
		on_hit(5, global_position)
