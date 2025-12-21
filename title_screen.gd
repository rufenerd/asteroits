extends Control

var selected_difficulty := 2 # 0=TRAINING, 1=EASY, 2=NORMAL, 3=HARD
var difficulties := [World.Difficulty.TRAINING, World.Difficulty.EASY, World.Difficulty.NORMAL, World.Difficulty.HARD]
var difficulty_names := ["TRAINING", "EASY", "NORMAL", "HARD"]

const NAV_DEBOUNCE_MS := 150
var _nav_locked := false
var _last_nav_ms := 0

@onready var training_arrow := $MainVBox/CenterContainer/VBoxContainer/TrainingRow/TrainingArrow
@onready var easy_arrow := $MainVBox/CenterContainer/VBoxContainer/EasyRow/EasyArrow
@onready var normal_arrow := $MainVBox/CenterContainer/VBoxContainer/NormalRow/NormalArrow
@onready var hard_arrow := $MainVBox/CenterContainer/VBoxContainer/HardRow/HardArrow
@onready var _bg := $Background
@onready var _center := $MainVBox/CenterContainer

func _ready():
	# Enforce full-rect anchors at runtime to avoid instance overrides
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	if _bg:
		_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bg.offset_left = 0
		_bg.offset_top = 0
		_bg.offset_right = 0
		_bg.offset_bottom = 0

	if _center:
		_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		_center.offset_left = 0
		_center.offset_top = 0
		_center.offset_right = 0
		_center.offset_bottom = 0

	update_difficulty_display()
	_last_nav_ms = Time.get_ticks_msec()

func _process(delta: float) -> void:
	# Unlock navigation once all nav inputs return to neutral (prevents jitter when holding stick)
	var any_nav_pressed := (
		Input.is_action_pressed("left_stick_up") or
		Input.is_action_pressed("left_stick_down") or
		Input.is_action_pressed("aim_up") or
		Input.is_action_pressed("aim_down") or
		Input.is_action_pressed("rotate_colors")
	)
	if not any_nav_pressed:
		_nav_locked = false

func _input(event):
	if event.is_action_pressed("left_stick_up") or event.is_action_pressed("aim_up"):
		if _can_navigate():
			selected_difficulty = max(selected_difficulty - 1, 0)
			update_difficulty_display()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("left_stick_down") or event.is_action_pressed("aim_down") or event.is_action_pressed("rotate_colors"):
		if _can_navigate():
			selected_difficulty = min(selected_difficulty + 1, 3)
			update_difficulty_display()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("pause") or event.is_action_pressed("boost_shield"):
		start_game()
		get_viewport().set_input_as_handled()
		return

func update_difficulty_display():
	# Hide all arrows (make transparent)
	training_arrow.modulate.a = 0.0
	easy_arrow.modulate.a = 0.0
	normal_arrow.modulate.a = 0.0
	hard_arrow.modulate.a = 0.0
	
	# Show arrow for selected option (make opaque)
	match selected_difficulty:
		0:
			training_arrow.modulate.a = 1.0
		1:
			easy_arrow.modulate.a = 1.0
		2:
			normal_arrow.modulate.a = 1.0
		3:
			hard_arrow.modulate.a = 1.0

func _can_navigate() -> bool:
	if _nav_locked:
		return false
	var now := Time.get_ticks_msec()
	if now - _last_nav_ms < NAV_DEBOUNCE_MS:
		return false
	_last_nav_ms = now
	_nav_locked = true
	return true

func start_game():
	var difficulty = difficulties[selected_difficulty]
	var difficulty_name = difficulty_names[selected_difficulty]
	print("Starting game with difficulty: ", difficulty_name)
	
	# Reset world state before spawning players so colors/bank/spawns are fresh
	World.reset_state()

	# Set difficulty on the global World singleton
	World.difficulty = difficulty
	
	# Choose scene based on difficulty
	var scene_path := "res://tutorial.tscn" if difficulty == World.Difficulty.TRAINING else "res://world.tscn"
	var world_scene = load(scene_path)
	var world_instance = world_scene.instantiate()
	get_tree().root.get_node("Main").add_child(world_instance)
	
	# Initialize the game
	World.initialize_game()
	
	# Remove title screen
	queue_free()
