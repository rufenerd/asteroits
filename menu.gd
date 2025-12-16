extends Control
class_name MenuUI

@onready var title_label = Label.new()
@onready var host_button = Button.new()
@onready var connect_button = Button.new()
@onready var ip_input = LineEdit.new()
@onready var join_button = Button.new()
@onready var status_label = Label.new()
@onready var spacer2 = Control.new()
@onready var start_game_button = Button.new()
var connection_mode = "none" # "none", "host", "connect"

func _ready():
	setup_ui()
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.game_started.connect(_on_game_started)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	set_process(true)

func _process(_delta):
	# Update host display with current player count
	if NetworkManager.is_host and connection_mode == "host":
		status_label.text = "Players: %d/%d" % [NetworkManager.get_human_player_count(), NetworkManager.MAX_PLAYERS]

func setup_ui():
	var panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200
	panel.offset_top = -250
	panel.offset_right = 200
	panel.offset_bottom = 250
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)
	
	title_label.text = "ASTEROIDS - MULTIPLAYER"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)
	
	host_button.text = "Host Game"
	host_button.pressed.connect(_on_host_pressed)
	vbox.add_child(host_button)
	
	connect_button.text = "Connect to Game"
	connect_button.pressed.connect(_on_connect_pressed)
	vbox.add_child(connect_button)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	spacer2.visible = false
	spacer2.name = "spacer2"
	self.spacer2 = spacer2
	vbox.add_child(spacer2)
	
	ip_input.placeholder_text = "Enter server IP"
	ip_input.visible = false
	ip_input.name = "ip_input"
	self.ip_input = ip_input
	vbox.add_child(ip_input)
	
	join_button.text = "Join"
	join_button.visible = false
	join_button.pressed.connect(_on_join_pressed)
	join_button.name = "join_button"
	self.join_button = join_button
	vbox.add_child(join_button)
	
	start_game_button.text = "Start Game"
	start_game_button.visible = false
	start_game_button.pressed.connect(_on_start_game_pressed)
	self.start_game_button = start_game_button
	vbox.add_child(start_game_button)
	
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer3)
	
	status_label.text = "Ready"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(status_label)

func _on_host_pressed():
	connection_mode = "host"
	host_button.disabled = true
	connect_button.disabled = true
	status_label.text = "Starting server..."
	print("===== HOST MENU: Starting server =====")
	
	if NetworkManager.host_game():
		status_label.text = "Players: 0/%d" % NetworkManager.MAX_PLAYERS
		start_game_button.visible = true
	else:
		status_label.text = "Failed to start server"
		host_button.disabled = false
		connect_button.disabled = false

func _on_connect_pressed():
	connection_mode = "connect"
	host_button.disabled = true
	connect_button.disabled = true
	ip_input.visible = true
	join_button.visible = true
	spacer2.visible = true

func _on_join_pressed():
	var ip = ip_input.text
	if ip.is_empty():
		status_label.text = "Please enter an IP address"
		return
	
	print("===== CLIENT MENU: Attempting to join =====")
	status_label.text = "Connecting to " + ip + "..."
	NetworkManager.connect_to_server(ip)
	# Status will update via _on_connected_to_server signal

func _on_peer_connected(peer_id: int):
	if NetworkManager.is_host:
		status_label.text = "Players: %d/%d" % [NetworkManager.get_human_player_count(), NetworkManager.MAX_PLAYERS]

func _on_peer_disconnected(peer_id: int):
	if NetworkManager.is_host:
		status_label.text = "Players: %d/%d" % [NetworkManager.get_human_player_count(), NetworkManager.MAX_PLAYERS]

func _on_start_game_pressed():
	if NetworkManager.is_host:
		status_label.text = "Starting game with %d human + %d AI..." % [NetworkManager.get_human_player_count(), NetworkManager.get_ai_player_count()]
		start_game_button.disabled = true
		NetworkManager.start_game()

func _on_connected_to_server():
	print("Client: Successfully connected to server!")
	status_label.text = "Connected! Waiting for host to start game..."

func _on_connection_failed():
	print("Client: Connection failed!")
	print("Multiplayer peer state: ", multiplayer.multiplayer_peer.get_connection_status() if multiplayer.multiplayer_peer else "null")
	status_label.text = "Failed to connect"
	host_button.disabled = false
	connect_button.disabled = false
	ip_input.visible = false
	join_button.visible = false

func _on_game_started():
	print("Game started!")
