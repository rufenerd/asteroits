class_name Asteroid extends RigidBody2D

@export var sides := 16                 # Number of random points
@export var radius := 160.0             # Outer size
@export var concavity := 0.6            # 0 = convex, 1 = jagged
@export var color := Color.DARK_GRAY

@export var min_speed := 5.0
@export var max_speed := 100.0

@export var min_spin := -1.0           # radians/sec
@export var max_spin := 1.0

@export var player_mass := 1.0       # conceptual mass
@export var push_power := 1.5         # tune feel, not physics
@export var self_pushback := 0.15     # how much player is affected

func on_hit(_damage, origin):
	if (radius == 10):
		print("POOF")
	else:
		for i in range(4):
			spawn_child(origin)
	queue_free()

func spawn_child(hit_origin: Vector2):
	var child := preload("res://asteroid.tscn").instantiate()

	child.radius = radius * 0.25
	child.mass = mass * 0.25

	# --- direction away from hit ---
	var dir := global_position - hit_origin
	if dir.length_squared() < 1.0:
		dir = Vector2.from_angle(randf() * TAU)
	else:
		dir = dir.normalized()

	var spread := deg_to_rad(35)
	dir = dir.rotated(randf_range(-spread, spread))

	# --- add first, THEN position ---
	get_parent().add_child(child)

	var dist := randf_range(0.25 * radius, radius)
	child.global_position = global_position + dir * dist

	# --- velocity ---
	child.linear_velocity = linear_velocity

	var explode_speed := randf_range(20.0, 40.0)
	child.linear_velocity += dir * explode_speed * (mass / child.mass)

	# --- spin ---
	child.angular_velocity = randf_range(-8.0, 8.0) * (mass / child.mass)

func _ready():
	randomize()
	global_position = Vector2(600, 600)

	var poly := random_concave_polygon(sides, radius, concavity)

	# --- RENDER ---
	var poly2d := Polygon2D.new()
	poly2d.polygon = poly
	poly2d.color = color
	add_child(poly2d)

	# --- COLLISION ---
	var chunks := Geometry2D.decompose_polygon_in_convex(poly)
	for c in chunks:
		var coll := CollisionPolygon2D.new()
		coll.polygon = c
		add_child(coll)

	# --- RANDOM LINEAR VELOCITY ---
	var angle := randf() * TAU
	var speed := randf_range(min_speed, max_speed)
	linear_velocity = Vector2(cos(angle), sin(angle)) * speed

	# --- RANDOM ANGULAR VELOCITY ---
	angular_velocity = randf_range(min_spin, max_spin)

# ============================================================
# ===============   POLYGON GENERATION   ======================
# ============================================================

func random_concave_polygon(n: int, radius: float, concavity: float) -> PackedVector2Array:
	# 1. Generate n random angles from 0 to TAU
	var angles := []
	for i in range(n):
		angles.append(randf() * TAU)
	angles.sort()

	# 2. For each angle, generate a radius with noise
	var pts := PackedVector2Array()
	for ang in angles:
		# Very irregular radius
		var r = radius * (1.0 - concavity * randf_range(0.0, 1.0))

		# Add local jagginess (small spikes)
		r *= randf_range(0.9, 1.1)

		pts.append(Vector2(cos(ang), sin(ang)) * r)

	return pts


# ============================================================
# ===================  GEOMETRY HELPERS  ======================
# ============================================================

func _convex_hull(pts: Array[Vector2]) -> Array[Vector2]:
	var lower: Array[Vector2] = []
	for p in pts:
		while lower.size() >= 2 and _cross(lower[-2], lower[-1], p) <= 0:
			lower.pop_back()
		lower.append(p)

	var upper: Array[Vector2] = []
	for i in range(pts.size()-1, -1, -1):
		var p := pts[i]
		while upper.size() >= 2 and _cross(upper[-2], upper[-1], p) <= 0:
			upper.pop_back()
		upper.append(p)

	return lower + upper.slice(1, upper.size() - 2)


func _cross(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a - o).cross(b - o)


# ============================================================
# =======  SAFE POINT INSERTION (NO SELF INTERSECTION)  ======
# ============================================================

func _safe_insert_point(poly: Array[Vector2], p: Vector2, concavity: float):
	var best_index := -1
	var best_score := INF

	for i in range(poly.size()):
		var j = (i + 1) % poly.size()

		var mid := (poly[i] + poly[j]) * 0.5
		var score := p.distance_to(mid) * (1.0 - concavity)

		if score < best_score and _insertion_no_cross(poly, i, p):
			best_score = score
			best_index = i + 1

	if best_index != -1:
		poly.insert(best_index, p)


func _insertion_no_cross(poly: Array[Vector2], i: int, p: Vector2) -> bool:
	var n := poly.size()
	var prev := poly[i]
	var next := poly[(i + 1) % n]

	var new_edges = [
		[prev, p],
		[p, next]
	]

	for e in range(n):
		var a := poly[e]
		var b := poly[(e + 1) % n]

		# skip replaced edge
		if (a == prev and b == next) or (a == next and b == prev):
			continue

		for edge in new_edges:
			if Geometry2D.segment_intersects_segment(edge[0], edge[1], a, b):
				return false

	return true

# Wrap-around
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var pos := global_position
	var b := World.BOUNDS

	# Wrap horizontally
	if pos.x < b.position.x:
		pos.x = b.position.x + b.size.x
	elif pos.x > b.position.x + b.size.x:
		pos.x = b.position.x

	# Wrap vertically
	if pos.y < b.position.y:
		pos.y = b.position.y + b.size.y
	elif pos.y > b.position.y + b.size.y:
		pos.y = b.position.y

	# Apply new position directly to body
	state.transform.origin = pos
