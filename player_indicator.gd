extends Control

@export var indicator_radius: float = 100.0
@export var label_font: Font

var camera: Camera2D

func _ready():
	camera = get_viewport().get_camera_2d()

func _process(_delta):
	# Refresh camera in case current changes or was null
	if camera == null or not is_instance_valid(camera):
		camera = get_viewport().get_camera_2d()

	if is_visible_in_tree():
		queue_redraw()

func _draw():
	if camera == null:
		return

	if World.players() == null:
		return

	for p in World.players():
		if p == null or !is_instance_valid(p):
			continue
		
		var canvas_xform := camera.get_canvas_transform()
		var screen_pos: Vector2 = canvas_xform * p.global_position
	
		var color = World.team_color(p.team)
		highlight(screen_pos, color, p)
		
		if not is_instance_valid(p):
			continue
		
		if p.shield == null or not is_instance_valid(p.shield):
			continue
		
		var shield_sprite = p.shield.sprite
		if shield_sprite == null or not is_instance_valid(shield_sprite):
			continue
		
		var health = p.shield.health
		var text = str(health)
		var texture_size = shield_sprite.texture.get_size()
		var world_radius = (texture_size.x * 0.5) * shield_sprite.global_scale.x

		var screen_radius = canvas_xform.x.length() * world_radius
		
		if label_font == null:
			return
		var text_size = label_font.get_string_size(text)

		var padding := 4.0
		var x_offset = text_size.x * 0.5 + 4.0
		if health >= 10.0:
			x_offset += 4.0

		var text_pos = screen_pos - Vector2(
			x_offset,
			screen_radius + padding
		)

		draw_string(
			label_font,
			text_pos,
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			32,
			color
		)

func highlight(screen_pos: Vector2, base_color: Color, p):
	if camera == null:
		return

	var modulate_color := Color(1, 1, 1, 0.4)
	var circle_color := base_color * modulate_color
	var line_width := 3.0

	# --- main indicator circle ---
	draw_circle(screen_pos, indicator_radius, circle_color, false, line_width)

	# only draw directional ticks for the local HUD player
	if World.hud == null or p != World.hud.player:
		return

	var canvas_xform := camera.get_canvas_transform()

	# ============================
	# Player ticks
	# ============================
	var player_tick_length := 12.0
	var tick_width := 3.0

	for other in World.players():
		if other == null or other == p or !is_instance_valid(other):
			continue

		var world_dir = other.global_position - p.global_position
		if world_dir.length_squared() < 0.001:
			continue

		var screen_dir := world_dir_to_screen_dir(world_dir.normalized(), canvas_xform)

		var other_color = World.team_color(other.team)
		var tick_color = other_color * modulate_color

		draw_radial_tick(
			screen_pos,
			screen_dir,
			indicator_radius,
			player_tick_length,
			tick_color,
			tick_width
		)

	# ============================
	# Asteroid ticks (shorter)
	# ============================
	var asteroid_tick_length := 6.0 # shorter than player ticks
	var asteroid_color := Color(1, 1, 1, 0.4)

	if World.asteroids() != null:
		for a in World.asteroids():
			if a == null or !is_instance_valid(a):
				continue

			var world_dir = a.global_position - p.global_position
			if world_dir.length_squared() < 0.001:
				continue

			var screen_dir := world_dir_to_screen_dir(world_dir.normalized(), canvas_xform)

			draw_radial_tick(
				screen_pos,
				screen_dir,
				indicator_radius,
				asteroid_tick_length,
				asteroid_color,
				2.0
			)

func draw_radial_tick(
	screen_pos: Vector2,
	screen_dir: Vector2,
	radius: float,
	length: float,
	color: Color,
	width: float
):
	var center := screen_pos + screen_dir * radius
	var a := center - screen_dir * length
	var b := center + screen_dir * length
	draw_line(a, b, color, width)

func world_dir_to_screen_dir(world_dir: Vector2, canvas_xform: Transform2D) -> Vector2:
	return (
		canvas_xform.x * world_dir.x +
		canvas_xform.y * world_dir.y
	).normalized()
