class_name Player
extends CharacterBody2D

var health = 1
var team = "player"
var shield = null

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

var input: PlayerInput

func _ready():
	World.register_player(self)
	global_position = World.spawn_points[team]
	$Sprite2D.modulate = World.team_color(team)
	add_to_group("players")

func _physics_process(delta):
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
	
	var input_vector := input.move

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
	var bullet = bullet_scene.instantiate()
	bullet.team = team
	bullet.origin = self

	var direction = aim_vector.normalized()
	bullet.direction = direction
	
	bullet.speed += acceleration
	var team_col = World.colors.get(team, Color.WHITE)
	var c: Color
	if typeof(team_col) == TYPE_STRING:
		c = Color.from_string(team_col, Color.WHITE)
	else:
		c = team_col
	bullet.modulate = c.lerp(Color.WHITE, 0.3) * 2.5

	var nose_offset := Vector2(16, 0).rotated(direction.angle())
	bullet.global_position = global_position + nose_offset

	get_parent().add_child(bullet)

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
				# Reparent to explosion so it tracks the effect while the player is hidden
				camera.reparent(explosion, true)
				camera.global_position = explosion.global_position
				camera.zoom.x = 16.0
				camera.zoom.y = 16.0

			call_deferred("_die", explosion)

			# Enter spectator mode: allow toggling cameras after game over
			if World:
				World.enter_spectator_mode()

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
