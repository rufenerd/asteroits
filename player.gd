class_name Player
extends CharacterBody2D

var health = 1
var team = "player"
var peer_id = 0 # 0 for AI, >0 for human players (matches multiplayer peer ID)
var shield = null

var input: PlayerInput
var _net_position: Vector2
var _net_velocity: Vector2
var _net_rotation: float

const NORMAL_MAX_SPEED = 600.0
const TURBO_MAX_SPEED = 4 * NORMAL_MAX_SPEED

const NORMAL_ACCELERATION = 400.0
const TURBO_ACCELERATION = 4000.0
const TURBO_COST = 500

@export var deadzone := 0.2
@export var max_speed := NORMAL_MAX_SPEED
@export var acceleration := NORMAL_ACCELERATION
@export var friction := 1800.0
@export var max_turn_speed := 15.0
@export var turn_accel := 50.0

@export var bullet_scene: PackedScene
@export var wall_scene: PackedScene
@export var harvester_scene: PackedScene
@export var turret_scene: PackedScene

@export var fire_cooldown := 0.2 # seconds between shots
var fire_timer := 0.0

@export var build_cooldown := 0.1
var build_timer := 0.0

var angular_velocity := 0.0

@export var shield_boost_delay := 1.0
var shield_boost_timer := 0.0

var weapon_level = 1

var turbo = false

var respawn_timer = 0.0
var invincible_timer = 0.0
var blink_timer = 0.0
var dying = false

func _ready():
	# Initialize with default input (may be overridden by HumanInput for human players)
	if not input:
		input = PlayerInput.new()
	
	# Register player if not already registered (main.gd registers before adding child)
	if not team in World.spawn_points:
		World.register_player(self)
	
	global_position = World.spawn_points[team]
	$Sprite2D.modulate = World.team_color(team)
	add_to_group("players")
	_net_position = global_position
	_net_velocity = velocity
	_net_rotation = rotation
	
	# Only enable camera for this client's own player
	var camera = get_node_or_null("Camera2D")
	if camera:
		camera.enabled = (peer_id == multiplayer.get_unique_id())
		if camera.enabled:
			camera.make_current()

func _physics_process(delta):
	var is_server = multiplayer.is_server()
	var is_local_player = peer_id == multiplayer.get_unique_id()

	if not is_server:
		# Client
		if is_local_player and input:
			# For our own player: update input, send to host, and run full simulation for prediction
			input.update(self, delta)
			_send_input_to_host()
			# Continue to full simulation below for client-side prediction
		else:
			# For other players: just interpolate received state from server
			_interpolate_state(delta)
			return
	else:
		# Server: update input only for local players (AI and host's own player)
		# Remote human players get their input from RPC, so we don't call update()
		var is_remote_human = (peer_id != 0 and peer_id != multiplayer.get_unique_id())
		if input and not is_remote_human:
			input.update(self, delta)

	# decrement global build cooldown every physics frame
	build_timer = max(build_timer - delta, 0.0)

	respawn_timer = max(respawn_timer - delta, 0.0)
	invincible_timer = max(invincible_timer - delta, 0.0)

	if invincible_timer > 0.0:
		blink_timer += delta
		if blink_timer >= 0.1:
			blink_timer = 0.0
			$Sprite2D.visible = not $Sprite2D.visible
	else:
		$Sprite2D.visible = true

	if respawn_timer > 0.0:
		return

	var input_vector: Vector2 = input.move

	var stick_active := input_vector.length() >= deadzone
	if stick_active:
		input_vector = input_vector.normalized()

	var forward := Vector2.RIGHT.rotated(rotation)

	if stick_active:
		velocity = velocity.move_toward(forward * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	_update_rotation_from_input(input_vector, delta)

	move_and_slide()
	var pos_after_move = global_position

	# Client-side reconciliation for locally-owned player
	if not is_server and is_local_player:
		_reconcile_with_server(delta)

	global_position.x = clamp(global_position.x, World.BOUNDS.position.x, World.BOUNDS.position.x + World.BOUNDS.size.x)
	global_position.y = clamp(global_position.y, World.BOUNDS.position.y, World.BOUNDS.position.y + World.BOUNDS.size.y)

	if global_position != pos_after_move:
		velocity = Vector2.ZERO

	var aim_vector := input.aim

	if aim_vector.length() > deadzone:
		fire_timer -= delta
		if fire_timer <= 0.0:
			fire_weapon(aim_vector)
			fire_timer = fire_cooldown
			
	if input.build_wall:
		build_wall()

	if input.build_harvester:
		build_harvester()
		
	if input.build_turret:
		build_turret()

	if input.boost_shield:
		shield_boost_timer += delta
		if shield_boost_timer >= shield_boost_delay:
			if World.bank[team] >= 1000:
				World.bank[team] -= 1000
				boost_shield()
				shield_boost_timer = 0.0
	else:
		shield_boost_timer = 0.0
		
	if World.bank[team] > (TURBO_COST * delta) and input.turbo:
		World.bank[team] -= min(TURBO_COST * delta, World.bank[team])
		max_speed = TURBO_MAX_SPEED
		acceleration = TURBO_ACCELERATION
		turbo = true
	else:
		if turbo:
			if velocity.length() > NORMAL_MAX_SPEED:
				velocity = velocity.normalized() * NORMAL_MAX_SPEED
		max_speed = NORMAL_MAX_SPEED
		acceleration = NORMAL_ACCELERATION
		turbo = false

	# Broadcast state to clients every frame
	_broadcast_state()

func _update_rotation_from_input(input_vector: Vector2, delta: float) -> void:
	if input_vector.length() < deadzone:
		angular_velocity = 0.0
		return

	input_vector = input_vector.normalized()
	var target_angle = input_vector.angle()
	var angle_diff = wrapf(target_angle - rotation, -PI, PI)

	var desired_speed = clamp(angle_diff * 8.0, -max_turn_speed, max_turn_speed)

	angular_velocity = move_toward(
		angular_velocity,
		desired_speed,
		turn_accel * delta
	)

	rotation += angular_velocity * delta

func fire_weapon(aim_vector):
	shoot_bullet(aim_vector)
	var spread := deg_to_rad(2 * (weapon_level - 1))
	for i in range(3 * (weapon_level - 1)):
		var jitter_vector = aim_vector.rotated(randf_range(-spread, spread))
		shoot_bullet(jitter_vector)

func shoot_bullet(aim_vector: Vector2):
	# Only server spawns bullets
	if not multiplayer.is_server():
		return
		
	var bullet = bullet_scene.instantiate()
	bullet.team = team
	bullet.origin = self

	var direction = aim_vector.normalized()
	bullet.direction = direction
	
	bullet.speed += acceleration
	var team_col: Variant = World.colors.get(team, Color.WHITE)
	var c: Color
	if typeof(team_col) == TYPE_STRING:
		c = Color.from_string(team_col, Color.WHITE)
	else:
		c = team_col
	bullet.modulate = c.lerp(Color.WHITE, 0.3) * 2.5

	var nose_offset := Vector2(16, 0).rotated(direction.angle())
	bullet.global_position = global_position + nose_offset

	get_parent().add_child(bullet)
	
	# Assign deterministic name and sync spawn to clients
	var bullet_name = World.next_net_name("Bullet")
	bullet.name = bullet_name
	# Sync bullet spawn to clients with name
	World._rpc_spawn_bullet.rpc(bullet.global_position, direction, bullet.speed, team, bullet_name)

func build_wall():
	var wall = wall_scene.instantiate()
	build(wall)

func build_harvester():
	var harvester = harvester_scene.instantiate()
	build(harvester)

func build_turret():
	var turret = turret_scene.instantiate()
	turret.rotation = snapped_cardinal(rotation)
	build(turret)

func build(node):
	node.team = team
	if build_timer > 0.0:
		node.queue_free()
		return
	World.build(node, global_position, team)
	if node.is_inside_tree():
		build_timer = build_cooldown

func boost_shield():
	if not shield:
		shield = preload("res://shield.tscn").instantiate()
		shield.team = team
		shield.health = 1
		shield.modulate = World.team_color(team)
		add_child(shield)
		shield = shield
	else:
		shield.health += 1

# === Networking helpers ===
func _send_input_to_host():
	if multiplayer.is_server():
		return
	if input == null:
		return
	# Create a copy of move/aim to avoid reference mutation issues with RPCs
	var payload := {
		"move": Vector2(input.move.x, input.move.y),
		"aim": Vector2(input.aim.x, input.aim.y),
		"turbo": input.turbo,
		"build_wall": input.build_wall,
		"build_harvester": input.build_harvester,
		"build_turret": input.build_turret,
		"boost_shield": input.boost_shield,
	}

	
	# Clients send input to host
	if not multiplayer.is_server():
		# Call method on host's main node 
		var main = get_tree().root.get_node("Main")
		# Pass individual floats instead of Vector2 to avoid reference issues
		main.receive_player_input.rpc_id(1, peer_id, payload["move"].x, payload["move"].y, payload["aim"].x, payload["aim"].y, payload["turbo"], payload["build_wall"], payload["build_harvester"], payload["build_turret"], payload["boost_shield"])
	else:
		# Host applies its own input directly
		var main = get_tree().root.get_node("Main")
		main._apply_player_input_direct(peer_id, payload)

@rpc("any_peer")
func _apply_network_input(payload: Dictionary):
	if input == null:
		return
	input.move = payload.get("move", Vector2.ZERO)
	input.aim = payload.get("aim", Vector2.ZERO)
	input.turbo = payload.get("turbo", false)
	input.build_wall = payload.get("build_wall", false)
	input.build_harvester = payload.get("build_harvester", false)
	input.build_turret = payload.get("build_turret", false)
	input.boost_shield = payload.get("boost_shield", false)

func _broadcast_state():
	if not multiplayer.is_server():
		return
	# Send state via World RPC so it reaches all clients (use team for unique routing)
	World._broadcast_player_state.rpc(team, global_position, velocity, rotation, health, dying)

func _interpolate_state(delta: float):
	if not is_instance_valid(self):
		return
	# Extrapolate server position to compensate for latency
	var predicted_pos = _net_position + _net_velocity * (4.0 / 60.0)
	# Faster interpolation for snappier multiplayer feel
	global_position = global_position.lerp(predicted_pos, clamp(15.0 * delta, 0.0, 1.0))
	velocity = velocity.lerp(_net_velocity, clamp(15.0 * delta, 0.0, 1.0))
	rotation = _net_rotation

func _reconcile_with_server(delta: float) -> void:
	# Don't reconcile during respawn to prevent teleporting back to death location
	if respawn_timer > 0.0:
		return
	# Extrapolate server position forward to compensate for network latency
	# Assume ~6 frames of latency (at 60fps = ~100ms round-trip)
	var predicted_server_pos = _net_position + _net_velocity * (6.0 / 60.0)
	
	var pos_err: Vector2 = predicted_server_pos - global_position
	var dist := pos_err.length()
	
	# Snap if way off (e.g., after asteroid impact)
	if dist > 300.0:
		global_position = _net_position
		velocity = _net_velocity
		return
	
	# Use gentler blend during active movement, stronger when idle
	var is_moving = input and input.move.length() >= deadzone
	var blend_factor = 10.0 if is_moving else 30.0
	
	# Blend if any error exists (position only; leave rotation under local control)
	if dist > 0.5:
		var w = clamp(blend_factor * delta, 0.0, 1.0)
		global_position = global_position.lerp(predicted_server_pos, w)
		velocity = velocity.lerp(_net_velocity, w)

func ang_dist(a, b):
	return abs(wrapf(a - b, -PI, PI))

func snapped_cardinal(angle: float) -> float:
	var cardinals = [
		0.0, # right
		PI * 0.5, # down
		PI, # left
		- PI * 0.5 # up
	]

	var closest = cardinals[0]
	var closest_dist = ang_dist(angle, closest)

	for c in cardinals:
		var dist = ang_dist(angle, c)
		if dist < closest_dist:
			closest = c
			closest_dist = dist

	return closest

func on_hit(damage, _origin):
	if dying:
		return
	if invincible_timer > 0.0:
		return
	if shield and shield.health > 0:
		return
	health -= damage

	if health <= 0:
		dying = true
		if World.extra_lives[team] == 0:
			var explosion = preload("res://Explosion.tscn").instantiate()
			var anim := explosion.get_node("AnimatedSprite2D") as AnimatedSprite2D
			anim.sprite_frames.set_animation_loop("explode", true)
			explosion.global_position = global_position
			explosion.target_node = self
			explosion.target_frames = 18
			visible = false

			var camera = $Camera2D
			if is_instance_valid(camera) and camera:
				# For now, keep current camera on explosion
				camera.enabled = true
				camera.make_current()
				camera.reparent(get_tree().current_scene)
				camera.global_position = explosion.global_position
				camera.zoom.x = 16.0
				camera.zoom.y = 16.0

			call_deferred("_die", explosion)

			if not World.hud.player == self:
				return

			# Find the alive player with the most bank
			var max_bank = - INF
			var best_player = null
			for p in World.players():
				if not is_instance_valid(p) or p == self:
					continue
				var p_bank = World.bank.get(p.team, 0)
				if p_bank > max_bank:
					max_bank = p_bank
					best_player = p

			if best_player:
				# Schedule camera switch after explosion plays
				World.call_deferred("_switch_camera_deferred", best_player)
		else:
			World.extra_lives[team] -= 1
			weapon_level = 1
			health = 1
			dying = false
			global_position = World.spawn_points[team]
			# Update network position to prevent reconciliation from pulling back
			_net_position = global_position
			velocity = Vector2.ZERO
			_net_velocity = Vector2.ZERO
			respawn_timer = 0.5
			invincible_timer = 3.0
			var damaged = preload("res://damaged.tscn").instantiate()
			damaged.global_position = global_position
			get_tree().current_scene.add_child(damaged)

func _die(explosion):
	remove_from_group("players")
	get_tree().current_scene.add_child(explosion)

func switch_camera(best_player):
	print("Switching camera to best player: ", best_player)
	if best_player:
		var best_camera = best_player.get_node_or_null("Camera2D")
		if best_camera and is_instance_valid(best_camera) and best_camera.is_inside_tree():
			var current_cam = get_viewport().get_camera_2d()
			if current_cam:
				current_cam.enabled = false
			best_camera.enabled = true
			best_camera.zoom = Vector2(1, 1)
			best_camera.make_current()

func upgrade_weapon():
	weapon_level += 1
