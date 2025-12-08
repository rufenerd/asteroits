class_name Harvester extends Explodable

var cell : Vector2i
var team = null

func _ready():
	var t := Timer.new()
	t.wait_time = 0.25
	t.autostart = true
	t.one_shot = false
	add_child(t)

	t.timeout.connect(func():
		World.harvest(self)
	)
	add_to_group("harvesters")
