class_name TutorialHUD extends Control

@onready var title_label := $TopContainer/TitleLabel
@onready var message_label := $TopContainer/MessageLabel

func _ready():
	# Ensure full-rect anchors
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_level(title: String, message: String):
	if title_label and is_instance_valid(title_label):
		title_label.text = title
		title_label.visible = true
	if message_label and is_instance_valid(message_label):
		message_label.text = message
		message_label.visible = true

func hide_level():
	if title_label and is_instance_valid(title_label):
		title_label.visible = false
	if message_label and is_instance_valid(message_label):
		message_label.visible = false
