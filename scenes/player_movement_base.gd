extends CharacterBody2D

## Reusable eight-direction movement. The scene origin is at the character's feet.
@export var walk_speed: float = 100.0
@export var sprint_speed: float = 150.0
@export var acceleration: float = 850.0
@export var stopping_friction: float = 1050.0
@export var idle_sprite_y: float = -87.0
@export var walk_sprite_y: float = -87.0
@export var walk_scale_multiplier: float = 1.0
@export var mirror_down_left_walk: bool = false
@export var mirror_up_left_walk: bool = false
@export var diagonal_walk_scale: float = 1.0
@export var down_diagonal_walk_scale: float = 1.0
@export var up_diagonal_walk_scale: float = 1.0
@export var up_diagonal_lean_degrees: float = 0.0
@export var diagonal_walk_y_offset: float = 0.0
@export var sprint_cardinal_scale: float = 1.0
@export var sprint_cardinal_y_offset: float = 0.0
@export var motion_visible_height: float = 0.0

const DIRECTIONS: Array[String] = [
	"right", "down_right", "down", "down_left",
	"left", "up_left", "up", "up_right",
]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var idle_sprite_scale: Vector2 = sprite.scale

var facing: Vector2 = Vector2.DOWN
var network_controlled := false
var network_input: Dictionary = {}
var network_edges: Dictionary = {}
var movement_min_x := -INF
var movement_locked := false
var motion_bounds: Dictionary = {}


func apply_network_input(packet: Dictionary) -> void:
	for action in ["interact", "lunge"]:
		if packet.get(action, false) and not network_input.get(action, false):
			network_edges[action] = true
	network_input = packet


func _action_pressed(action: String) -> bool:
	return bool(network_input.get(action, false)) if network_controlled else Input.is_action_pressed(action)


func _action_just_pressed(action: String) -> bool:
	if network_controlled:
		return network_edges.erase(action)
	return Input.is_action_just_pressed(action)


func _movement_input() -> Vector2:
	if movement_locked:
		return Vector2.ZERO
	return network_input.get("move", Vector2.ZERO) if network_controlled else Input.get_vector("left", "right", "up", "down")


func _throw_pressed() -> bool:
	return bool(network_input.get("throw", false)) if network_controlled else UserSettings.throw_pressed(get_viewport())


func _aim_position() -> Vector2:
	return network_input.get("aim", global_position + facing * 300.0) if network_controlled else UserSettings.aim_position(self)


func _ready() -> void:
	# Center the character when running this scene directly; keep its origin for level instances.
	if get_parent() == get_tree().root:
		global_position = get_viewport_rect().size * 0.5
	if motion_visible_height > 0.0:
		sprite.frame_changed.connect(_fit_motion_frame)
	_play("idle", facing)


func _physics_process(delta: float) -> void:
	move_from_input(delta, _movement_input(), _action_pressed("sprint"))


func move_from_input(delta: float, input_direction: Vector2, sprinting: bool, animate: bool = true, explicit_delta: bool = false) -> void:
	var speed: float = sprint_speed if sprinting else walk_speed
	var target_velocity: Vector2 = input_direction * speed
	var change_rate: float = acceleration if input_direction != Vector2.ZERO else stopping_friction

	velocity = velocity.move_toward(target_velocity, change_rate * delta)
	if explicit_delta: _move_character_delta(delta)
	else: _move_character()

	if input_direction != Vector2.ZERO:
		facing = input_direction

	if not animate: return
	if velocity.length_squared() > 12.0 * 12.0:
		var sprint_animation: bool = sprinting and sprite.sprite_frames.has_animation("sprint_down")
		_play("sprint" if sprint_animation else "walk", facing)
		sprite.speed_scale = clampf(velocity.length() / 150.0, 0.45, 1.35)
	else:
		_play("idle", facing)
		sprite.speed_scale = 1.0


func _play(action: String, direction: Vector2) -> void:
	var sector: int = (roundi(direction.angle() / (PI / 4.0)) + 8) % 8
	var moving: bool = action == "walk" or action == "sprint"
	var mirror_down_left: bool = mirror_down_left_walk and moving and DIRECTIONS[sector] == "down_left"
	var mirror_up_left: bool = mirror_up_left_walk and moving and DIRECTIONS[sector] == "up_left"
	var mirror_sprint_left: bool = action == "sprint" and DIRECTIONS[sector] == "left"
	var direction_name: String = DIRECTIONS[sector]
	if mirror_down_left:
		direction_name = "down_right"
	elif mirror_up_left:
		direction_name = "up_right"
	elif mirror_sprint_left:
		direction_name = "right"
	var animation_name: StringName = _movement_animation(action, direction_name)
	var visual_y: float = idle_sprite_y if action == "idle" else walk_sprite_y
	if moving and sector % 2 == 1:
		visual_y += diagonal_walk_y_offset
	elif action == "sprint":
		visual_y += sprint_cardinal_y_offset
	sprite.flip_h = mirror_down_left or mirror_up_left or mirror_sprint_left
	var visual_scale: float = walk_scale_multiplier if moving else 1.0
	if moving and sector % 2 == 1:
		visual_scale *= diagonal_walk_scale
		var direction_scale: float = down_diagonal_walk_scale if sector == 1 or sector == 3 else up_diagonal_walk_scale
		visual_scale *= direction_scale
	elif action == "sprint":
		visual_scale *= sprint_cardinal_scale
	sprite.scale = idle_sprite_scale * visual_scale
	var lean: float = 0.0
	if moving and (sector == 5 or sector == 7):
		var lean_degrees: float = up_diagonal_lean_degrees + (3.0 if action == "sprint" else 0.0)
		lean = deg_to_rad(lean_degrees) * (-1.0 if sector == 5 else 1.0)
	sprite.rotation = lean
	# Compensate for center-based rotation so the feet stay at the same world position.
	sprite.position = Vector2(sin(lean) * sprite.scale.y * 150.0, visual_y)
	if sprite.animation != animation_name or not sprite.is_playing():
		var previous_motion: bool = "walk_" in String(sprite.animation) or "sprint_" in String(sprite.animation)
		var keep_step: bool = moving and previous_motion
		var step_frame: int = sprite.frame
		var step_progress: float = sprite.frame_progress
		sprite.play(animation_name)
		if keep_step:
			sprite.set_frame_and_progress(step_frame, step_progress)
	_fit_motion_frame()


func _fit_motion_frame() -> void:
	_fit_frame(sprite, sprite.frame)


func _fit_frame(target: AnimatedSprite2D, frame_index: int) -> void:
	if motion_visible_height <= 0.0 or not target.sprite_frames:
		return
	var animation_name := String(target.animation)
	if not ("idle_" in animation_name or "walk_" in animation_name or "sprint_" in animation_name):
		return
	var texture: Texture2D = target.sprite_frames.get_frame_texture(target.animation, frame_index)
	if texture == null:
		return
	var bounds: Rect2i = _visible_bounds(texture, motion_bounds)
	var height := cycle_height(target.sprite_frames, target.animation, func(frame: Texture2D) -> float: return float(_visible_bounds(frame, motion_bounds).size.y))
	if bounds.size.y <= 0 or height <= 0.0:
		return
	var fitted_scale := motion_visible_height / height
	target.scale = Vector2.ONE * fitted_scale
	target.position = Vector2(0.0, -(float(bounds.end.y) - texture.get_size().y * 0.5) * fitted_scale)


## Visible pixels in the texture's own drawn space. An AtlasTexture's image is
## its region only, drawn offset by its margin, so the margin is added back
## (otherwise padded or tightly packed frames anchor their feet in the wrong place).
static func _visible_bounds(texture: Texture2D, cache: Dictionary) -> Rect2i:
	var id := texture.get_instance_id()
	if not cache.has(id):
		var used := texture.get_image().get_used_rect()
		if texture is AtlasTexture:
			used.position += Vector2i((texture as AtlasTexture).margin.position)
		cache[id] = used
	return cache[id]


# One scale per animation, from its average visible height. Scaling each frame
# to the same height made the body grow and shrink as legs spread and closed
# (up to 14% within one stride); a steady size lets the drawn bob show through,
# like a hand-animated run cycle. Feet stay planted per frame.
var cycle_heights: Dictionary = {}

func cycle_height(frames: SpriteFrames, animation: StringName, measure: Callable) -> float:
	var key := "%d:%s" % [frames.get_instance_id(), animation]
	if not cycle_heights.has(key):
		var total := 0.0
		var counted := 0
		for index in range(frames.get_frame_count(animation)):
			var texture := frames.get_frame_texture(animation, index)
			var value: float = float(measure.call(texture)) if texture != null else 0.0
			if value > 0.0:
				total += value
				counted += 1
		cycle_heights[key] = total / counted if counted > 0 else 0.0
	return float(cycle_heights[key])


# Seamless running: most run cycles have only four drawn frames, so blend each
# frame into the next and add a light stride bounce and forward lean. Local
# presentation only; every peer computes it from the sprite it already shows.
const STEP_BLEND := 0.55
# Lowest on foot contact, highest mid-stride; kept light because the drawn
# poses now carry their own bob at a steady scale (see cycle_height).
const STRIDE_BOUNCE := {"walk": 2.0, "sprint": 4.0}
const RUN_LEAN := 0.09
var step_blend: AnimatedSprite2D


func _update_run_polish() -> void:
	var name_text := String(sprite.animation)
	var gait := "sprint" if name_text.begins_with("sprint_") else "walk" if name_text.begins_with("walk_") else ""
	var running := gait != "" and sprite.visible and sprite.is_playing() and sprite.sprite_frames != null
	if not running:
		sprite.offset = Vector2.ZERO
		sprite.skew = 0.0
		if step_blend != null: step_blend.hide()
		return
	var count := sprite.sprite_frames.get_frame_count(sprite.animation)
	var cycle := (float(sprite.frame) + sprite.frame_progress) / float(maxi(count, 1))
	# Two footfalls per cycle; the body rises between them.
	var lift: float = absf(sin(cycle * TAU)) * STRIDE_BOUNCE[gait]
	sprite.offset = Vector2(0.0, -lift / maxf(absf(sprite.scale.y), 0.001))
	var sideways := signf(facing.x) * (1.0 if absf(facing.x) > 0.3 else 0.0)
	sprite.skew = -sideways * RUN_LEAN * (1.0 if gait == "sprint" else 0.5)
	if count < 2:
		return
	if step_blend == null:
		step_blend = AnimatedSprite2D.new()
		step_blend.name = "StepBlend"
		step_blend.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(step_blend)
		move_child(step_blend, sprite.get_index() + 1)
	step_blend.show()
	if step_blend.sprite_frames != sprite.sprite_frames: step_blend.sprite_frames = sprite.sprite_frames
	if step_blend.animation != sprite.animation: step_blend.animation = sprite.animation
	step_blend.frame = (sprite.frame + 1) % count
	step_blend.flip_h = sprite.flip_h
	step_blend.rotation = sprite.rotation
	step_blend.position = sprite.position
	step_blend.scale = sprite.scale
	_fit_frame(step_blend, step_blend.frame)
	step_blend.offset = Vector2(0.0, -lift / maxf(absf(step_blend.scale.y), 0.001))
	step_blend.skew = sprite.skew
	step_blend.material = sprite.material
	# Cycles with drawn or generated in-betweens need only a light touch.
	var strength := STEP_BLEND if count <= 4 else STEP_BLEND * 0.4
	step_blend.modulate = Color(1, 1, 1, smoothstep(0.0, 1.0, sprite.frame_progress) * strength)


func _movement_animation(action: String, direction_name: String) -> StringName:
	return StringName(action + "_" + direction_name)


func _move_character() -> void:
	if is_finite(movement_min_x):
		var step := maxf(get_physics_process_delta_time(), 0.001)
		velocity.x = maxf(velocity.x, (movement_min_x - global_position.x) / step)
	move_and_slide()
	global_position.x = maxf(global_position.x, movement_min_x)


func _move_character_delta(delta: float) -> void:
	# Replaying input outside a physics callback must use its recorded timestep.
	var step := maxf(delta, 0.001)
	if is_finite(movement_min_x):
		velocity.x = maxf(velocity.x, (movement_min_x - global_position.x) / step)
	var motion := velocity * step
	for slide in range(4):
		var collision := move_and_collide(motion)
		if collision == null: break
		motion = collision.get_remainder().slide(collision.get_normal())
		velocity = velocity.slide(collision.get_normal())
	global_position.x = maxf(global_position.x, movement_min_x)
