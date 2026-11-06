extends Node2D

# A short "+1" that rises from a player whenever their match score goes up.
# Every peer spawns these from score changes it sees, so nothing extra is sent.

const FONT = preload("res://assets/fonts/TitanOne-Regular.ttf")
const LIFETIME := 1.1
const RISE := 70.0
const INK := Color("26150f")

var text := "+1"
var color := Color("ffe29a")
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress := age / LIFETIME
	# Pop in quickly, hold, then fade over the last third.
	var pop := 1.0 + 0.35 * (1.0 - smoothstep(0.0, 0.18, progress))
	var alpha := 1.0 - smoothstep(0.66, 1.0, progress)
	var font_size := int(round(38.0 * pop))
	var offset := Vector2(-80, -RISE * smoothstep(0.0, 1.0, progress))
	draw_string_outline(FONT, offset, text, HORIZONTAL_ALIGNMENT_CENTER, 160, font_size, 8, Color(INK, alpha))
	draw_string(FONT, offset, text, HORIZONTAL_ALIGNMENT_CENTER, 160, font_size, Color(color.lightened(0.25), alpha))
