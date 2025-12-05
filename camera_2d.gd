extends Camera2D

const ZOOM_IN_FACTOR := 0.5
const ZOOM_OUT_FACTOR := 2.0

const MIN_ZOOM := 0.5
const MAX_ZOOM := 8.0

func _input(event):
	if event.is_action_pressed("zoom_in"):
		zoom *= ZOOM_IN_FACTOR
		zoom.x = clamp(zoom.x, MIN_ZOOM, MAX_ZOOM)
		zoom.y = clamp(zoom.y, MIN_ZOOM, MAX_ZOOM)

	if event.is_action_pressed("zoom_out"):
		zoom *= ZOOM_OUT_FACTOR
		zoom.x = clamp(zoom.x, MIN_ZOOM, MAX_ZOOM)
		zoom.y = clamp(zoom.y, MIN_ZOOM, MAX_ZOOM)
