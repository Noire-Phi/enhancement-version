extends Node2D

# Atmosphere for the match arenas: drifting cloud shadows over the court, a warm
# screen vignette, gently swaying trees and per-map floating particles.
# Purely visual and local to each player; nothing here is networked.

const CLOUD_SHADER := """
shader_type canvas_item;
uniform vec4 shade_color : source_color = vec4(0.09, 0.11, 0.24, 1.0);
uniform float strength = 0.16;
uniform vec2 drift = vec2(16.0, 5.0);
uniform float noise_scale = 0.0017;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += amplitude * noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}
varying vec2 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float cloud = smoothstep(0.5, 0.74, fbm((local_position + drift * TIME) * noise_scale));
	COLOR = vec4(shade_color.rgb, cloud * strength);
}
"""

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.17, 0.07, 0.02, 1.0);
uniform float strength = 0.42;
void fragment() {
	vec2 offset = UV - 0.5;
	offset.x *= 1.25;
	COLOR = vec4(tint.rgb, smoothstep(0.38, 0.92, length(offset)) * strength);
}
"""

# Bends the top of a sprite while its base stays planted, like wind in foliage.
const SWAY_SHADER := """
shader_type canvas_item;
uniform float phase = 0.0;
uniform float amount = 5.0;
void fragment() {
	float canopy = pow(1.0 - UV.y, 2.0);
	float sway = sin(TIME * 0.9 + phase) * amount * canopy + sin(TIME * 2.3 + phase * 1.7) * amount * 0.25 * canopy;
	COLOR = texture(TEXTURE, UV - vec2(sway * TEXTURE_PIXEL_SIZE.x, 0.0));
}
"""

# Per-map particles: leaves on the court, warm dust motes in the lane, sand on the yard.
const PARTICLES := [
	{"name": "Leaves", "amount": 16, "lifetime": 10.0, "size": Vector2i(18, 9), "color": Color("9bc65a"), "velocity": Vector2(28, 38), "spread": 25.0, "spin": 90.0, "scale": Vector2(0.9, 1.5)},
	{"name": "Motes", "amount": 34, "lifetime": 8.0, "size": Vector2i(10, 10), "color": Color("ffe7a8"), "velocity": Vector2(8, -12), "spread": 60.0, "spin": 0.0, "scale": Vector2(0.5, 1.1)},
	{"name": "Sand", "amount": 26, "lifetime": 6.0, "size": Vector2i(14, 5), "color": Color("f2d39b"), "velocity": Vector2(70, 6), "spread": 12.0, "spin": 10.0, "scale": Vector2(0.7, 1.4)},
]

var cloud_layer: ColorRect
var vignette: ColorRect
var particles: CPUParticles2D

func setup(level: Node2D, map_index: int, bounds: Rect2) -> void:
	name = "Ambience"
	cloud_layer = ColorRect.new()
	cloud_layer.name = "CloudShadows"
	cloud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloud_layer.position = bounds.position - Vector2(200, 200)
	cloud_layer.size = bounds.size + Vector2(400, 400)
	cloud_layer.z_index = 20
	cloud_layer.material = _material(CLOUD_SHADER)
	if map_index == 1:
		# The narrow lane sits in more shade; the sandy yard gets thinner clouds.
		cloud_layer.material.set_shader_parameter("strength", 0.2)
	elif map_index == 2:
		cloud_layer.material.set_shader_parameter("strength", 0.12)
	add_child(cloud_layer)
	particles = _build_particles(PARTICLES[clampi(map_index, 0, PARTICLES.size() - 1)], bounds)
	add_child(particles)
	var screen := CanvasLayer.new()
	screen.name = "VignetteLayer"
	screen.layer = 3 # Below the match HUD (layer 4).
	add_child(screen)
	vignette = ColorRect.new()
	vignette.name = "Vignette"
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.material = _material(VIGNETTE_SHADER)
	screen.add_child(vignette)
	_sway_foliage(level)

static func _material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _sway_foliage(level: Node2D) -> void:
	var targets: Array[Node] = []
	var trees := level.get_node_or_null("Backdrop/Trees")
	if trees != null and trees.visible:
		targets.append_array(trees.get_children())
	for child in level.get_node("Backdrop").get_children():
		if child is Sprite2D and ("Palm" in child.name or "Plant" in child.name):
			targets.append(child)
	var index := 0
	for node in targets:
		if node is Sprite2D and node.material == null:
			var material := _material(SWAY_SHADER)
			material.set_shader_parameter("phase", index * 1.37)
			material.set_shader_parameter("amount", 3.0 if "Plant" in node.name else 5.0)
			node.material = material
			index += 1

static func _blob_texture(size: Vector2i) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in range(size.y):
		for x in range(size.x):
			var offset := Vector2((x + 0.5) / size.x * 2.0 - 1.0, (y + 0.5) / size.y * 2.0 - 1.0)
			var alpha := clampf((1.0 - offset.length_squared()) * 2.2, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)

static func _build_particles(config: Dictionary, bounds: Rect2) -> CPUParticles2D:
	var emitter := CPUParticles2D.new()
	emitter.name = config.name
	emitter.z_index = 22
	emitter.texture = _blob_texture(config.size)
	emitter.amount = config.amount
	emitter.lifetime = config.lifetime
	emitter.preprocess = config.lifetime # Start with the air already full.
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.position = bounds.get_center()
	emitter.emission_rect_extents = bounds.size * 0.5
	var velocity: Vector2 = config.velocity
	emitter.direction = velocity.normalized()
	emitter.spread = config.spread
	emitter.initial_velocity_min = velocity.length() * 0.6
	emitter.initial_velocity_max = velocity.length() * 1.2
	emitter.gravity = Vector2.ZERO
	emitter.angular_velocity_min = -float(config.spin)
	emitter.angular_velocity_max = float(config.spin)
	emitter.angle_min = 0.0
	emitter.angle_max = 360.0
	emitter.scale_amount_min = config.scale.x
	emitter.scale_amount_max = config.scale.y
	emitter.color = config.color
	# Fade in and out so particles never pop.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 0.85))
	ramp.add_point(0.8, Color(1, 1, 1, 0.85))
	emitter.color_ramp = ramp
	return emitter
