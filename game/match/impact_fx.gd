extends Node2D

# Can knockdown burst: a white flash, an expanding ring, sparks and tin shards
# that arc out under gravity. Drawn in code to match the game's other effects.

const LIFETIME := 0.7
const GRAVITY := 900.0

var strength := 0.5
var age := 0.0
var sparks: Array = []
var shards: Array = []

func _ready() -> void:
	var power := lerpf(0.6, 1.25, clampf(strength, 0.0, 1.0))
	for index in range(10):
		var angle := randf_range(-PI, 0.0)
		sparks.append({"dir": Vector2.RIGHT.rotated(angle), "speed": randf_range(220.0, 420.0) * power, "length": randf_range(12.0, 24.0)})
	for index in range(6):
		var angle := randf_range(-PI * 0.95, -PI * 0.05)
		shards.append({"pos": Vector2.ZERO, "vel": Vector2.RIGHT.rotated(angle) * randf_range(150.0, 300.0) * power, "spin": randf_range(-14.0, 14.0), "size": randf_range(4.0, 8.0), "tint": [Color("d8dde0"), Color("c43c2c"), Color("f2c14e")][index % 3]})

func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	for shard in shards:
		shard.vel.y += GRAVITY * delta
		shard.pos += shard.vel * delta
	queue_redraw()

func _draw() -> void:
	var progress := age / LIFETIME
	var fade := 1.0 - progress
	# Bright flash that ends quickly; things should leave faster than they arrive.
	var flash := 1.0 - smoothstep(0.0, 0.18, progress)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, 26.0 + 30.0 * strength, Color(1.0, 0.98, 0.85, 0.75 * flash))
	var ring := lerpf(18.0, 70.0 + 40.0 * strength, ease(progress, 0.4))
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 40, Color(1.0, 0.86, 0.4, 0.8 * fade), 6.0 * fade + 1.0, true)
	var travel := ease(progress, 0.35)
	for spark in sparks:
		var tip: Vector2 = spark.dir * spark.speed * travel * 0.45
		draw_line(tip - spark.dir * spark.length * fade, tip, Color(1.0, 0.8, 0.3, fade), 3.0, true)
	for shard in shards:
		var angle: float = shard.spin * age
		var half: float = shard.size
		var points := PackedVector2Array([Vector2(-half, -half * 0.5), Vector2(half, -half * 0.3), Vector2(half * 0.6, half * 0.5), Vector2(-half * 0.7, half * 0.4)])
		for index in range(points.size()):
			points[index] = shard.pos + points[index].rotated(angle)
		draw_colored_polygon(points, Color(shard.tint, fade))
