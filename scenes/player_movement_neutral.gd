extends "res://scenes/player_movement_base.gd"

signal tag_requested(thrower: Node2D)

@export var charge_duration: float = 2.5 # Complete out-and-back meter cycle.
const THROW_METER = preload("res://scenes/throw_meter.gd")
@export var accept_local_input: bool = true
var throwoff_locked := false
@export var is_taya: bool = false
@export_range(0.1, 1.0, 0.05) var carry_speed_ratio := 0.85
const TAG_DELAY := 3.0
var tag_ready_at := 0.0
@export var can_path: NodePath
@export var lunge_distance: float = 300.0
@export var lunge_cooldown_seconds: float = 10.0
@export var safe_strip_rect: Rect2
@export var allowed_throw_rect: Rect2
var require_standing_can := false
@export var throw_speed_multiplier := 1.0
@export var throw_grunt: AudioStream
@export var collision_width_ratio := 0.58
@export var show_player_ring := true
@export var show_gameplay_overlays := true
var taya_min_x := -INF
@export var arena_bounds: Rect2
@export var player_color := Color("329dff")

const SLIPPER_VISUAL = preload("res://scenes/slipper_visual.gd")
const SPRINT_DUST = preload("res://scenes/sprint_dust.gd")
const THROW_BURST = preload("res://scenes/throw_burst.gd")
const TAYA_STUN_SLIPPER = preload("res://scenes/taya_stun_slipper.gd")
const SKILL_FONT = preload("res://assets/fonts/TitanOne-Regular.ttf")
const THROW_ORIGIN: Vector2 = Vector2(0.0, -103.0)
const TAG_DISTANCE: float = 49.0
const PLAYER_CLEARANCE: float = 90.0
const CAN_GUARD_CLEARANCE: float = 100.0
const LUNGE_WINDUP: float = 0.13
const LUNGE_TRAVEL_TIME: float = 0.30
# Order matches DIRECTIONS in player_movement_base.gd.
const AIM_SCALES: Array[float] = [0.89, 0.83, 0.90, 0.83, 0.88, 0.87, 0.93, 0.89]
const THROW_SCALES: Array[float] = [0.95, 0.86, 0.96, 0.86, 0.95, 0.87, 0.94, 0.87]

enum AttackState { FREE, CHARGING, THROWING }

@onready var attack_sprite: AnimatedSprite2D = $AttackSprite
@onready var charge_bar: ProgressBar = $ChargeBar
@onready var taya_visual: Variant = $TayaVisual
@onready var interact_prompt: Label = $InteractPrompt

var attack_state: int = AttackState.FREE
var attack_direction: Vector2 = Vector2.DOWN
var aim_distance: float = 48.0
var charge_elapsed: float = 0.0
var charge_ratio: float = 0.0
var charge_id := 0
var charge_started := 0.0
var sweet_spot := 0.5
var throw_feedback := ""
var feedback_until := 0.0
var release_spread := 0.0
var slipper_spawned: bool = false
var active_slipper: Node2D
var possession_icon: Node2D
var throw_grunt_player: AudioStreamPlayer2D
var last_grunt_charge_id := -1
var dust_cooldown: float = 0.0
var next_foot_left: bool = false
var can_node
var carrying_can: bool = false
var taya_action: StringName = &""
var lunge_direction: Vector2 = Vector2.DOWN
var lunge_target: Node2D
var lunge_collision_exception: PhysicsBody2D
var lunge_elapsed: float = 0.0
var lunge_travelled: float = 0.0
var lunge_launched: bool = false
var lunge_landed: bool = false
var next_lunge_time: float = 0.0
var last_tagged_target: Node2D
var name_label: Label
var role_label: Label
var skill_charge := 0
var special_armed := false
var ability_glow_until := 0.0
var stunned_until := 0.0
var stun_started_at := 0.0
var stun_immune_until := 0.0
var taya_stun_ready_at := 0.0
var taya_stun_aiming := false
var taya_stun_cast_until := 0.0
var taya_stun_projectile: Node2D
var rapid_slippers: Array[Node2D] = []
var rapid_remaining := 0
var rapid_next_at := 0.0
const THROWER_NAME_COLOR := Color("65e37b")
const TAYA_NAME_COLOR := Color("ff3030")
var throw_status: Label
var predicted_path := PackedVector2Array()
var hit_flash_remaining := 0.0
var lan_processed_input_sequence := 0


func _ready() -> void:
	_prepare_movement_banks()
	possession_icon = preload("res://scenes/possession_icon.gd").new()
	possession_icon.name = "PossessionIcon"
	possession_icon.hide()
	possession_icon.position = Vector2(0, -340)
	possession_icon.scale = Vector2.ONE * 1.5
	add_child(possession_icon)
	super._ready()
	_configure_body_collision.call_deferred()
	_build_reaction_frames()
	_build_cast_frames()
	if throw_grunt != null:
		throw_grunt_player = AudioStreamPlayer2D.new()
		throw_grunt_player.stream = throw_grunt
		throw_grunt_player.position = Vector2(0, -90)
		throw_grunt_player.volume_db = 0.0
		add_child(throw_grunt_player)
	attack_sprite.animation_finished.connect(_on_attack_finished)
	attack_sprite.frame_changed.connect(_on_attack_frame_changed)
	attack_sprite.hide()
	charge_bar.set_script(THROW_METER)
	charge_bar.offset_left = -122
	charge_bar.offset_right = 122
	charge_bar.offset_top = -275
	charge_bar.offset_bottom = -253
	charge_bar._ready()
	charge_bar.hide()
	taya_visual.hide()
	interact_prompt.hide()
	taya_visual.action_finished.connect(_on_taya_action_finished)
	if not String(can_path).is_empty():
		can_node = get_node_or_null(can_path)
	if not is_taya:
		add_to_group("throwers")
	_update_taya_prompt()
	throw_status = Label.new()
	throw_status.position = Vector2(-110, -312)
	throw_status.size = Vector2(220, 26)
	throw_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	throw_status.add_theme_font_override("font", preload("res://assets/fonts/TitanOne-Regular.ttf"))
	throw_status.add_theme_font_size_override("font_size", 17)
	throw_status.add_theme_color_override("font_outline_color", Color("20130f"))
	throw_status.add_theme_constant_override("outline_size", 5)
	throw_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(throw_status)


func _configure_body_collision() -> void:
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(&"idle_down", 0)
	if texture == null:
		return
	var image: Image = texture.get_image()
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.5)
	var outlines: Array[PackedVector2Array] = bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 5.0)
	if outlines.is_empty():
		return
	var visible := Rect2(outlines[0][0], Vector2.ZERO)
	for point in outlines[0]:
		visible = visible.expand(point)
	var half_width: float = visible.size.x * sprite.scale.x * collision_width_ratio * 0.5
	var half_height: float = minf(visible.size.y * sprite.scale.y * 0.2, 40.0)
	var canvas_offset := (texture as AtlasTexture).margin.position if texture is AtlasTexture else Vector2.ZERO
	var foot: Vector2 = sprite.transform * (Vector2(visible.get_center().x, visible.end.y) + canvas_offset - texture.get_size() * 0.5)
	var center := foot - Vector2(0.0, half_height)
	var body := ConvexPolygonShape2D.new()
	var points := PackedVector2Array([
		Vector2(-half_width, -half_height * 0.55),
		Vector2(-half_width * 0.55, -half_height),
		Vector2(half_width * 0.55, -half_height),
		Vector2(half_width, -half_height * 0.55),
		Vector2(half_width, half_height * 0.55),
		Vector2(half_width * 0.55, half_height),
		Vector2(-half_width * 0.55, half_height),
		Vector2(-half_width, half_height * 0.55),
	])
	for index in range(points.size()):
		points[index] = (points[index] + center).round()
	body.points = points
	$CollisionShape2D.position = Vector2.ZERO
	$CollisionShape2D.shape = body


func _physics_process(delta: float) -> void:
	if LanSession.mode == "lan" and LanSession.is_host():
		lan_processed_input_sequence = int(network_input.get("sequence", lan_processed_input_sequence))
	_advance_rapid_burst()
	hit_flash_remaining = maxf(0.0, hit_flash_remaining - delta)
	modulate = Color(1.8, 1.35, 0.9) if hit_flash_remaining > 0.0 else Color(1.35, 1.15 + 0.12 * sin(LanSession.clock_time() * 9.0), 1.8) if is_stunned() else Color.WHITE
	_update_throw_status()
	if is_taya or special_armed or is_stunned(): queue_redraw()
	if not accept_local_input:
		velocity = Vector2.ZERO
		return
	if is_stunned():
		velocity = Vector2.ZERO
		var elapsed := LanSession.clock_time() - stun_started_at
		_play("hit" if elapsed < 0.17 else "recover" if stunned_until - LanSession.clock_time() < 0.2 else "stunned", facing)
		var remaining := stunned_until - LanSession.clock_time()
		var lean_degrees := 8.0 * smoothstep(0.0, 0.12, elapsed) if elapsed < 0.17 else 5.0 * smoothstep(0.0, 0.2, remaining) if remaining < 0.2 else 2.5 * sin(elapsed * 3.5)
		var lean := deg_to_rad(lean_degrees) * (-1.0 if facing.x < 0.0 else 1.0)
		sprite.rotation = lean
		sprite.position.x = sin(lean) * sprite.scale.y * 150.0
		_refresh_possession_visual()
		queue_redraw()
		return
	if is_taya:
		_taya_physics_process(delta)
		return
	if attack_state == AttackState.FREE:
		if _throw_pressed() and not is_instance_valid(active_slipper) and can_throw_here():
			_start_charge()
		else:
			super._physics_process(delta)
			_update_sprint_dust(delta)
			_update_slipper_pickup()
	elif attack_state == AttackState.CHARGING:
		if not throw_target_ready():
			set_taya_role(is_taya)
			return
		_update_cursor_aim()
		_refresh_meter()
		_update_trajectory()
		if not _throw_pressed():
			_start_throw()


func _move_character() -> void:
	super._move_character()
	_keep_out_of_can_circle()


func _move_character_delta(delta: float) -> void:
	super._move_character_delta(delta)
	_keep_out_of_can_circle()


func _keep_out_of_can_circle() -> void:
	if not is_taya or carrying_can or not require_standing_can or can_node == null or not can_node.is_standing() or can_node.base == null:
		return
	var center: Vector2 = can_node.base.global_position + Vector2(0, -27)
	var outward: Vector2 = global_position - center
	if outward.length_squared() >= CAN_GUARD_CLEARANCE * CAN_GUARD_CLEARANCE:
		return
	outward = outward.normalized() if not outward.is_zero_approx() else Vector2.LEFT
	global_position = center + outward * CAN_GUARD_CLEARANCE
	if velocity.dot(outward) < 0.0:
		velocity -= outward * velocity.dot(outward)


func _process(_delta: float) -> void:
	_refresh_possession_visual()
	_update_run_polish()
	# Replicas do not simulate physics, but their timing marker must animate smoothly.
	if attack_state == AttackState.CHARGING and not LanSession.is_host():
		_refresh_meter()
		_update_throw_status()
		if int(get_meta("peer_id", -1)) == LanSession.local_id():
			_update_trajectory()

func _prepare_movement_banks() -> void:
	# Never mutate shared authored SpriteFrames when adding role aliases.
	sprite.sprite_frames = sprite.sprite_frames.duplicate()
	var frames := sprite.sprite_frames
	for direction in DIRECTIONS:
		for action in ["idle", "walk", "sprint"]:
			var original := StringName(action + "_" + direction)
			if not frames.has_animation(original): continue
			for prefix in ["empty_", "taya_"]:
				var name := StringName(prefix + original)
				if frames.has_animation(name): continue
				frames.add_animation(name)
				frames.set_animation_loop(name, frames.get_animation_loop(original))
				frames.set_animation_speed(name, frames.get_animation_speed(original))
				for frame in range(frames.get_frame_count(original)):
					frames.add_frame(name, frames.get_frame_texture(original, frame), frames.get_frame_duration(original, frame))
	# Double every walk/sprint cycle with generated in-betweens where available.
	if not has_meta("skip_inbetweens"):
		preload("res://scenes/locomotion_inbetweens.gd").install(frames)


func _movement_animation(action: String, direction_name: String) -> StringName:
	var prefix := "taya_" if is_taya else "empty_" if is_instance_valid(active_slipper) else ""
	var name := StringName(prefix + action + "_" + direction_name)
	return name if sprite.sprite_frames.has_animation(name) else super._movement_animation(action, direction_name)


func is_local_view() -> bool:
	return show_gameplay_overlays and int(get_meta("peer_id", LanSession.local_id())) == LanSession.local_id() and not bool(get_meta("bot", false))


func _refresh_possession_visual() -> void:
	if possession_icon == null: return
	if not show_gameplay_overlays:
		possession_icon.item = &""
		charge_bar.hide()
		return
	charge_bar.visible = attack_state == AttackState.CHARGING and is_local_view()
	var stun_cast := LanSession.clock_time() < taya_stun_cast_until
	var windup := attack_state == AttackState.CHARGING or (attack_state == AttackState.THROWING and not slipper_spawned) or taya_stun_aiming or (stun_cast and attack_sprite.frame < 2)
	var can_action := is_taya and taya_action in [&"pickup", &"place"]
	# Item-bearing artwork is hidden; ownership is shown solely by the overhead icon.
	if is_stunned():
		sprite.show()
		attack_sprite.hide()
		taya_visual.hide()
	elif windup or can_action:
		sprite.show()
		attack_sprite.hide()
		taya_visual.hide()
		_play("idle", facing)
	elif attack_state == AttackState.THROWING or (stun_cast and not carrying_can):
		sprite.hide()
		attack_sprite.show() # Release/recovery drawings have empty hands.
	elif carrying_can and taya_action == &"":
		sprite.show()
		taya_visual.hide()
	if attack_state == AttackState.FREE and taya_action == &"" and not is_stunned() and not taya_stun_aiming and not stun_cast:
		var action := "sprint" if "sprint_" in String(sprite.animation) else "walk" if "walk_" in String(sprite.animation) else "idle"
		var expected := _movement_animation(action, DIRECTIONS[_facing_sector()])
		if sprite.animation != expected: _play(action, facing)
	possession_icon.item = &"can" if carrying_can else &"slipper" if not is_taya and not is_instance_valid(active_slipper) and not (attack_state == AttackState.THROWING and slipper_spawned) else &""


func _refresh_meter() -> void:
	charge_elapsed = maxf(0.0, LanSession.clock_time() - charge_started)
	charge_bar.target_center = sweet_spot
	charge_bar.value = THROW_METER.marker_at(charge_elapsed, charge_duration * 0.5)
	charge_bar.modulate = Color.WHITE

func throw_quality() -> Dictionary:
	return THROW_METER.quality_at(charge_bar.value, sweet_spot)

func release_network_throw(id: int, at_time: float, aim: Vector2) -> bool:
	if attack_state != AttackState.CHARGING or charge_id != id or not can_throw_here():
		return false
	var now := LanSession.clock_time()
	if not is_finite(at_time) or at_time < now - 0.25 or at_time > now + 0.03 or at_time < charge_started:
		return false
	network_input["aim"] = aim
	_update_cursor_aim()
	_start_throw(maxf(0.0, minf(at_time, now) - charge_started))
	return true

func _taya_physics_process(delta: float) -> void:
	if taya_stun_aiming:
		var aim: Vector2 = _aim_position() - get_throw_origin()
		if aim.length_squared() > 1.0:
			facing = aim.normalized()
			attack_direction = facing
			if carrying_can: taya_visual.show_carry(_facing_sector(), false)
			else:
				_set_attack_visual(_attack_sector(), false)
				var animation := StringName("taya_stun_aim_" + _attack_direction_name())
				if attack_sprite.animation != animation: attack_sprite.play(animation)
		velocity = Vector2.ZERO
		return
	if LanSession.clock_time() < taya_stun_cast_until:
		velocity = Vector2.ZERO
		return
	if taya_stun_cast_until > 0.0:
		taya_stun_cast_until = 0.0
		attack_sprite.hide()
		if carrying_can: taya_visual.show_carry(_facing_sector(), false)
		else: sprite.show()
	if taya_action == &"lunge":
		_advance_lunge(delta)
		return
	if taya_action != &"":
		velocity = Vector2.ZERO
		return
	if _action_just_pressed("lunge") and can_lunge():
		_start_lunge()
		return
	var original_walk: float = walk_speed
	var original_sprint: float = sprint_speed
	if carrying_can:
		walk_speed = original_walk * carry_speed_ratio
		sprint_speed = walk_speed
	super._physics_process(delta)
	walk_speed = original_walk
	sprint_speed = original_sprint
	if can_node != null and LanSession.is_host():
		if carrying_can:
			if can_node.reset_at_base(self):
				carrying_can = false
				_refresh_possession_visual()
				_keep_out_of_can_circle()
		elif can_node.pick_up(self):
			carrying_can = true
			_refresh_possession_visual()
	if carrying_can:
		dust_cooldown = 0.0
		sprite.show()
		taya_visual.hide()
	else:
		taya_visual.hide()
		_update_sprint_dust(delta)
	_try_tag()
	_update_taya_prompt()


func _start_taya_action(next_action: StringName) -> void:
	taya_action = next_action
	velocity = Vector2.ZERO
	if next_action != &"lunge":
		facing = Vector2.DOWN
	sprite.hide()
	attack_sprite.hide()
	charge_bar.hide()
	interact_prompt.hide()
	taya_visual.play_action(next_action, _facing_sector())
	_refresh_possession_visual()


func _start_lunge() -> void:
	_restore_lunge_collision(false)
	if facing.is_zero_approx(): facing = Vector2.DOWN
	lunge_direction = Vector2.RIGHT.rotated(float(_facing_sector()) * PI / 4.0)
	lunge_elapsed = 0.0
	lunge_travelled = 0.0
	lunge_launched = false
	lunge_landed = false
	# A straight dash can pass through a thrower directly ahead if it can land clear.
	var ray_start: Vector2 = global_position + Vector2(0.0, -20.0 * scale.y)
	var ray := PhysicsRayQueryParameters2D.create(ray_start, ray_start + lunge_direction * lunge_distance, collision_mask, [get_rid()])
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	lunge_target = hit.get("collider") as Node2D
	if lunge_target is PhysicsBody2D and lunge_target.is_in_group("throwers") and _is_eligible_thrower(lunge_target) and global_position.distance_to(lunge_target.global_position) + PLAYER_CLEARANCE * maxf(scale.x, lunge_target.scale.x) + 16.0 <= lunge_distance:
		lunge_collision_exception = lunge_target
		add_collision_exception_with(lunge_collision_exception)
	else:
		lunge_target = null
	next_lunge_time = Time.get_ticks_msec() / 1000.0 + lunge_cooldown_seconds
	_start_taya_action(&"lunge")


func _advance_lunge(delta: float) -> void:
	lunge_elapsed += delta
	if lunge_landed:
		velocity = Vector2.ZERO
		return
	if lunge_elapsed < LUNGE_WINDUP:
		velocity = Vector2.ZERO
		return
	if not lunge_launched:
		lunge_launched = true
		_spawn_lunge_dust(false)
	if lunge_elapsed >= LUNGE_WINDUP + LUNGE_TRAVEL_TIME:
		_land_lunge()
		return

	var step: float = minf(lunge_distance / LUNGE_TRAVEL_TIME * delta, lunge_distance - lunge_travelled)
	var before: Vector2 = global_position
	velocity = lunge_direction * step / maxf(delta, 0.001)
	_move_character()
	var moved: float = global_position.distance_to(before)
	lunge_travelled += moved
	_try_tag()
	if not is_taya or taya_action != &"lunge":
		return
	if moved < step * 0.2 or lunge_travelled >= lunge_distance - 0.5:
		_land_lunge()


func _land_lunge() -> void:
	if lunge_landed:
		return
	lunge_landed = true
	velocity = Vector2.ZERO
	_restore_lunge_collision(true)
	taya_visual.begin_lunge_recovery()
	_spawn_lunge_dust(true)


func _restore_lunge_collision(separate: bool) -> void:
	if separate and is_instance_valid(lunge_target) and lunge_target is PhysicsBody2D:
		var away: Vector2 = global_position - lunge_target.global_position
		var direction: Vector2 = away.normalized() if not away.is_zero_approx() else -lunge_direction
		var clearance: float = PLAYER_CLEARANCE * maxf(scale.x, lunge_target.scale.x) + 2.0
		if away.length() < clearance:
			global_position = lunge_target.global_position + direction * clearance
	_keep_out_of_can_circle()
	if is_instance_valid(lunge_collision_exception):
		remove_collision_exception_with(lunge_collision_exception)
	lunge_collision_exception = null


func _spawn_lunge_dust(landing: bool) -> void:
	var side := Vector2(-lunge_direction.y, lunge_direction.x)
	var count: int = 4 if landing else 3
	for index in range(count):
		var spread: float = float(index) - float(count - 1) * 0.5
		var dust = SPRINT_DUST.new()
		get_parent().add_child(dust)
		dust.global_position = global_position + side * spread * 20.0 - lunge_direction * (0.0 if landing else 12.0) + Vector2(0, -3)
		dust.drift_direction = (side * spread * 0.55 + lunge_direction * (0.7 if landing else -0.7)).normalized()
		dust.drift_speed = 82.0 if landing else 64.0
		dust.lifetime = 0.66 if landing else 0.57
		dust.scale = Vector2.ONE * (1.35 if landing else 1.12)


func _is_eligible_thrower(candidate: Node2D) -> bool:
	return candidate != self and not (safe_strip_rect.has_area() and safe_strip_rect.has_point(candidate.global_position))


func _try_tag() -> void:
	if not can_tag():
		return
	var current_target: Node2D
	for candidate in get_tree().get_nodes_in_group("throwers"):
		if candidate is Node2D and _is_eligible_thrower(candidate) and candidate.global_position.distance_squared_to(global_position) <= TAG_DISTANCE * TAG_DISTANCE:
			current_target = candidate
			break
	if current_target == null:
		for index in get_slide_collision_count():
			var collider: Object = get_slide_collision(index).get_collider()
			if collider is Node2D and collider.is_in_group("throwers") and _is_eligible_thrower(collider):
				current_target = collider
				break
	if current_target != last_tagged_target:
		last_tagged_target = current_target
		if current_target != null:
			tag_requested.emit(current_target)


func _on_taya_action_finished(_completed: StringName) -> void:
	taya_action = &""
	taya_visual.hide()
	sprite.show()
	_play("idle", facing)
	_refresh_possession_visual()
	_update_taya_prompt()


func _update_taya_prompt() -> void:
	interact_prompt.hide()
	if not is_taya or can_node == null or taya_action != &"":
		return
	if carrying_can:
		interact_prompt.text = "Carry can to base"
	else:
		return
	interact_prompt.show()


func tag_delay_remaining() -> float:
	return clampf(tag_ready_at - LanSession.clock_time(), 0.0, TAG_DELAY)


func can_tag() -> bool:
	return is_taya and not is_stunned() and not carrying_can and can_node != null and can_node.is_standing() and LanSession.clock_time() >= tag_ready_at


func can_lunge() -> bool:
	return is_taya and not is_stunned() and not carrying_can and can_node != null and can_node.is_standing() and Time.get_ticks_msec() / 1000.0 >= next_lunge_time


func _facing_sector() -> int:
	return (roundi(facing.angle() / (PI / 4.0)) + 8) % 8


func set_taya_role(enabled: bool) -> void:
	_restore_lunge_collision(taya_action == &"lunge")
	special_armed = false
	rapid_remaining = 0
	taya_stun_aiming = false
	taya_stun_cast_until = 0.0
	if is_taya and not enabled and carrying_can and can_node != null:
		can_node.drop(self)
		carrying_can = false
	if enabled and not is_taya: tag_ready_at = LanSession.clock_time() + TAG_DELAY
	if not enabled: tag_ready_at = 0.0
	is_taya = enabled
	update_name_color()
	movement_min_x = taya_min_x if enabled else -INF
	global_position.x = maxf(global_position.x, movement_min_x)
	_keep_out_of_can_circle()
	velocity = Vector2.ZERO
	attack_sprite.stop()
	charge_elapsed = 0.0
	charge_started = 0.0
	predicted_path.clear()
	slipper_spawned = true
	lunge_target = null
	lunge_elapsed = 0.0
	lunge_landed = false
	taya_visual.action = &""
	network_edges.clear()
	queue_redraw()
	attack_state = AttackState.FREE
	attack_sprite.hide()
	charge_bar.hide()
	last_tagged_target = null
	if enabled:
		remove_from_group("throwers")
		add_to_group("taya_players")
	else:
		add_to_group("throwers")
		remove_from_group("taya_players")
	taya_action = &""
	taya_visual.hide()
	sprite.show()
	_play("idle", facing)
	_refresh_possession_visual()
	_update_taya_prompt()


func update_name_color() -> void:
	if is_instance_valid(name_label):
		name_label.add_theme_color_override("font_color", TAYA_NAME_COLOR if is_taya else THROWER_NAME_COLOR)
	if is_instance_valid(role_label):
		role_label.visible = is_taya

func set_skill_charge(value: int) -> void:
	var next_charge := clampi(value, 0, 3) if has_thrower_special() else 0
	if skill_charge != next_charge:
		skill_charge = next_charge
		queue_redraw()


func has_thrower_special() -> bool:
	return true


func is_stunned() -> bool:
	return LanSession.clock_time() < stunned_until


func apply_stun() -> bool:
	var now := LanSession.clock_time()
	if now < stun_immune_until:
		return false
	stunned_until = now + 3.0
	stun_started_at = now
	stun_immune_until = stunned_until + 5.0
	if attack_state != AttackState.FREE:
		set_taya_role(is_taya)
	_restore_lunge_collision(true)
	taya_action = &""
	taya_visual.hide()
	taya_stun_aiming = false
	taya_stun_cast_until = 0.0
	attack_sprite.hide()
	sprite.show()
	_refresh_possession_visual()
	velocity = Vector2.ZERO
	queue_redraw()
	return true


func begin_taya_stun_aim() -> bool:
	if not is_taya or is_stunned() or taya_action != &"" or LanSession.clock_time() < taya_stun_ready_at:
		return false
	taya_stun_aiming = true
	attack_direction = facing
	_set_attack_visual(_attack_sector(), false)
	attack_sprite.play(StringName("taya_stun_aim_" + _attack_direction_name()))
	if carrying_can: taya_visual.show_carry(_facing_sector(), false)
	else: attack_sprite.show()
	sprite.hide()
	if not carrying_can: taya_visual.hide()
	_refresh_possession_visual()
	return true


func release_taya_stun(aim: Vector2) -> bool:
	if not taya_stun_aiming or not is_taya or is_stunned() or not aim.is_finite():
		taya_stun_aiming = false
		return false
	var direction := (aim - get_throw_origin()).normalized()
	if direction.is_zero_approx():
		taya_stun_aiming = false
		return false
	taya_stun_aiming = false
	taya_stun_ready_at = LanSession.clock_time() + 120.0
	taya_stun_cast_until = LanSession.clock_time() + 0.42
	ability_glow_until = LanSession.clock_time() + 0.8
	facing = direction
	attack_direction = direction
	_set_attack_visual(_attack_sector(), true)
	if not carrying_can: attack_sprite.play(StringName("taya_stun_throw_" + _attack_direction_name()))
	var projectile = TAYA_STUN_SLIPPER.new()
	get_parent().add_child(projectile)
	projectile.launch_taya(self, get_throw_origin() + direction * 42.0, direction)
	taya_stun_projectile = projectile
	_refresh_possession_visual()
	queue_redraw()
	return true

func _build_reaction_frames() -> void:
	# All five characters reuse their own directional drawings and original feet alignment.
	# Effects and timing distinguish these states without changing their silhouette size.
	var frames: SpriteFrames = sprite.sprite_frames.duplicate(true)
	for direction in DIRECTIONS:
		var idle := StringName("idle_" + direction)
		if not frames.has_animation(idle): continue
		for action in ["hit", "stunned", "recover"]:
			var name := StringName(action + "_" + direction)
			frames.add_animation(name)
			frames.set_animation_loop(name, action == "stunned")
			frames.set_animation_speed(name, 5.0 if action == "stunned" else 8.0)
			var count := frames.get_frame_count(idle)
			for index in range(count):
				frames.add_frame(name, frames.get_frame_texture(idle, index))
	sprite.sprite_frames = frames

func _build_cast_frames() -> void:
	var frames: SpriteFrames = attack_sprite.sprite_frames.duplicate(true)
	for direction in DIRECTIONS:
		for action in ["aim", "throw"]:
			var original := StringName(action + "_" + direction)
			if not frames.has_animation(original): continue
			for variant in ["special_", "taya_stun_"]:
				var name := StringName(variant + action + "_" + direction)
				frames.add_animation(name)
				frames.set_animation_loop(name, frames.get_animation_loop(original))
				frames.set_animation_speed(name, frames.get_animation_speed(original))
				for index in range(frames.get_frame_count(original)):
					frames.add_frame(name, frames.get_frame_texture(original, index), frames.get_frame_duration(original, index))
	attack_sprite.sprite_frames = frames


func _advance_rapid_burst() -> void:
	if rapid_remaining == 0 and is_instance_valid(active_slipper) and active_slipper.special_kind == &"rapid":
		var finished := true
		for shot in rapid_slippers:
			if is_instance_valid(shot) and not shot.return_complete:
				finished = false
		if finished and is_instance_valid(active_slipper) and active_slipper.return_complete:
			set_meta("rapid_complete", true)
			for shot in rapid_slippers:
				if is_instance_valid(shot): shot.queue_free()
			rapid_slippers.clear()
			active_slipper.queue_free()
			active_slipper = null
	if rapid_remaining <= 0 or LanSession.clock_time() < rapid_next_at:
		return
	if is_taya or is_stunned() or not throw_target_ready():
		rapid_remaining = 0
		return
	var slipper = SLIPPER_VISUAL.new()
	get_parent().add_child(slipper)
	var origin := get_throw_origin()
	var direction := attack_direction
	slipper.launch(self, origin + direction * 42.0, direction, charge_ratio, origin, throw_speed_multiplier)
	slipper.special_kind = &"rapid"
	slipper.arena_bounds = arena_bounds
	slipper.outline_color = player_color
	rapid_slippers.append(slipper)
	rapid_remaining -= 1
	rapid_next_at = LanSession.clock_time() + 0.25
	ability_glow_until = LanSession.clock_time() + 0.35


func throw_target_ready() -> bool:
	return not require_standing_can or (is_instance_valid(can_node) and can_node.is_standing())


func can_throw_here() -> bool:
	return not is_taya and not is_stunned() and not throwoff_locked and accept_local_input and throw_target_ready() and (not allowed_throw_rect.has_area() or allowed_throw_rect.has_point(global_position))


func _start_charge() -> void:
	if not can_throw_here() or is_instance_valid(active_slipper):
		return
	attack_state = AttackState.CHARGING
	velocity = Vector2.ZERO
	dust_cooldown = 0.0
	charge_elapsed = 0.0
	charge_id += 1
	charge_started = LanSession.clock_time()
	sweet_spot = randf_range(0.25, 0.75)
	charge_bar.target_center = sweet_spot
	# Bots release near the sweet spot; VS AI difficulty widens the spread and adds aim error.
	var profile: Dictionary = LanSession.bot_profile()
	set_meta("bot_release_at", clampf(sweet_spot + randf_range(-profile.release, profile.release), 0.05, 0.98))
	set_meta("bot_aim_offset", Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * float(profile.aim))
	charge_bar.value = 0.0
	charge_bar.visible = is_local_view()
	interact_prompt.hide()
	_update_cursor_aim()
	sprite.hide()
	attack_sprite.show()
	attack_sprite.play(StringName(("special_aim_" if special_armed else "aim_") + _attack_direction_name()))
	_refresh_possession_visual()


func _start_throw(release_elapsed: float = -1.0) -> void:
	if not can_throw_here():
		set_taya_role(is_taya)
		return
	predicted_path.clear()
	queue_redraw()
	if release_elapsed >= 0.0:
		charge_bar.value = THROW_METER.marker_at(release_elapsed, charge_duration * 0.5)
	var quality := throw_quality()
	charge_ratio = quality.power
	release_spread = quality.spread
	throw_feedback = "%s %d%%" % [quality.band, roundi(charge_ratio * 100.0)]
	feedback_until = LanSession.clock_time() + 0.8
	attack_direction = attack_direction.rotated(deg_to_rad(randf_range(-release_spread, release_spread)))
	charge_bar.hide()
	attack_state = AttackState.THROWING
	slipper_spawned = false
	_set_attack_visual(_attack_sector(), true)
	attack_sprite.play(StringName(("special_throw_" if special_armed else "throw_") + _attack_direction_name()))
	_refresh_possession_visual()


func _attack_direction_name() -> String:
	return DIRECTIONS[_attack_sector()]


func _attack_sector() -> int:
	return (roundi(attack_direction.angle() / (PI / 4.0)) + 8) % 8


func _update_cursor_aim() -> void:
	var aim: Vector2 = _aim_position() - get_throw_origin()
	if aim.length_squared() <= 0.01:
		return
	var previous_sector: int = _attack_sector()
	var sector: int = (roundi(aim.angle() / (PI / 4.0)) + 8) % 8
	aim_distance = aim.length()
	attack_direction = aim.normalized()
	facing = attack_direction
	_set_attack_visual(sector, false)
	var desired := StringName(("special_aim_" if special_armed else "aim_") + DIRECTIONS[sector])
	if attack_sprite.visible and (sector != previous_sector or attack_sprite.animation != desired):
		var frame: int = attack_sprite.frame
		var progress: float = attack_sprite.frame_progress
		attack_sprite.play(desired)
		attack_sprite.set_frame_and_progress(frame, progress)


func _set_attack_visual(sector: int, releasing: bool) -> void:
	var attack_scale: float = THROW_SCALES[sector] if releasing else AIM_SCALES[sector]
	attack_sprite.scale = Vector2.ONE * attack_scale
	attack_sprite.position = Vector2(0, -120.5 * attack_scale)
	# These atlas rows do not share one mirror rule: the down-left aim and
	# release drawings face opposite sides, while up-left needs mirroring.
	attack_sprite.flip_h = sector == 5 or (sector == 3 and not releasing)


func _on_attack_frame_changed() -> void:
	if attack_state != AttackState.THROWING or attack_sprite.frame < 2 or slipper_spawned:
		return
	if not can_throw_here():
		set_taya_role(is_taya)
		return
	slipper_spawned = true
	play_throw_grunt()
	var release_point: Vector2 = get_throw_origin() + attack_direction * minf(48.0, aim_distance * 0.5)
	var burst = THROW_BURST.new()
	get_parent().add_child(burst)
	burst.global_position = release_point
	burst.direction = attack_direction
	burst.charge_ratio = charge_ratio
	var slipper = SLIPPER_VISUAL.new()
	get_parent().add_child(slipper)
	slipper.launch(self, release_point, attack_direction, charge_ratio, get_throw_origin(), throw_speed_multiplier)
	slipper.arena_bounds = arena_bounds
	slipper.outline_color = player_color
	if has_thrower_special() and special_armed and skill_charge == 3 and not is_taya and throw_target_ready():
		var kinds := [&"rapid", &"ricochet", &"self_return", &"stun", &"mind_control"]
		var index := clampi(int(get_meta("character_index", 0)), 0, kinds.size() - 1)
		slipper.special_kind = kinds[index]
		if index == 0:
			rapid_remaining = 2
			rapid_next_at = LanSession.clock_time() + 0.25
			rapid_slippers.clear()
			set_meta("rapid_complete", false)
			set_meta("rapid_hit", false)
		elif index == 4:
			slipper.steer_until = LanSession.clock_time() + 2.0
		set_skill_charge(0)
		special_armed = false
		ability_glow_until = LanSession.clock_time() + 0.8
	else:
		special_armed = false
	active_slipper = slipper
	_refresh_possession_visual()


func play_throw_grunt() -> void:
	if is_taya or throw_grunt_player == null or last_grunt_charge_id == charge_id:
		return
	last_grunt_charge_id = charge_id
	throw_grunt_player.play()


func get_throw_origin() -> Vector2:
	return to_global(THROW_ORIGIN)


func _update_slipper_pickup() -> void:
	interact_prompt.hide()
	if not is_instance_valid(active_slipper) or not active_slipper.can_pick_up(self):
		return
	if active_slipper.pick_up(self):
		active_slipper = null
		_refresh_possession_visual()
		interact_prompt.hide()


func _update_sprint_dust(delta: float) -> void:
	if not _action_pressed("sprint") or velocity.length() < walk_speed * 0.85:
		dust_cooldown = 0.0
		return
	dust_cooldown -= delta
	if dust_cooldown > 0.0:
		return
	dust_cooldown = 0.16
	var travel: Vector2 = velocity.normalized()
	var side: Vector2 = Vector2(-travel.y, travel.x) * (-11.0 if next_foot_left else 11.0)
	next_foot_left = not next_foot_left
	var dust = SPRINT_DUST.new()
	get_parent().add_child(dust)
	dust.global_position = global_position + side - travel * 16.0 + Vector2(0, -4)
	dust.drift_direction = -travel


func _on_attack_finished() -> void:
	if attack_state != AttackState.THROWING:
		return
	attack_state = AttackState.FREE
	attack_sprite.hide()
	sprite.show()
	sprite.speed_scale = 1.0
	_play("idle", facing)


func flash_hit() -> void:
	hit_flash_remaining = 0.18


func _update_throw_status() -> void:
	if throw_status == null:
		return
	throw_status.position.y = -525 if is_taya else -440
	throw_status.add_theme_color_override("font_color", player_color.lightened(0.4))
	if is_stunned():
		throw_status.text = "STUNNED %.1fs" % (stunned_until - LanSession.clock_time())
	elif is_taya and tag_delay_remaining() > 0.0:
		throw_status.text = "TAGGING IN %d" % ceili(tag_delay_remaining())
	elif is_taya:
		throw_status.text = "STUN %.0fs" % ceilf(taya_stun_ready_at - LanSession.clock_time()) if LanSession.clock_time() < taya_stun_ready_at else "%s  STUN READY" % UserSettings.short_binding_text("special")
	elif special_armed:
		throw_status.text = "SPECIAL ARMED"
	elif attack_state == AttackState.CHARGING:
		var quality := throw_quality()
		throw_status.text = "%s %d%%" % [quality.band, roundi(quality.power * 100.0)]
		throw_status.add_theme_color_override("font_color", quality.color)
	elif LanSession.clock_time() < feedback_until:
		throw_status.text = throw_feedback
	elif is_instance_valid(active_slipper):
		throw_status.text = "RETURNS IN %.1fs" % active_slipper.lost_remaining if active_slipper.lost_remaining > 0.0 else "RUN OVER YOUR SLIPPER" if active_slipper.can_pick_up(self) else "SLIPPER IN PLAY"
	elif not throw_target_ready():
		throw_status.text = "WAIT FOR CAN RESET"
	else:
		throw_status.text = "READY TO THROW"


func _update_trajectory() -> void:
	if not is_local_view():
		predicted_path.clear()
		queue_redraw()
		return
	var origin := get_throw_origin()
	var release := origin + attack_direction * minf(48.0, aim_distance * 0.5)
	predicted_path = SLIPPER_VISUAL.predict_path(get_world_2d(), origin, release, attack_direction, float(throw_quality().power), get_tree().get_nodes_in_group("can_targets"), throw_speed_multiplier)
	if predicted_path.size() > 8:
		predicted_path.resize(8)
	queue_redraw()


func _draw() -> void:
	if not show_gameplay_overlays: return
	if show_player_ring:
		draw_arc(Vector2(0, 5), 43.0, 0, TAU, 32, Color(player_color, 0.8), 4.0, true)
	if is_taya:
		var cooldown_progress := clampf(1.0 - (taya_stun_ready_at - LanSession.clock_time()) / 120.0, 0.0, 1.0)
		draw_arc(Vector2(0, 5), 53.0, -PI * 0.5, -PI * 0.5 + TAU * cooldown_progress, 48, Color("bd70ff") if cooldown_progress >= 1.0 else Color("744a8c"), 5.0, true)
	if (attack_sprite.visible or is_taya and carrying_can) and (special_armed or taya_stun_aiming or LanSession.clock_time() < taya_stun_cast_until or LanSession.clock_time() < ability_glow_until):
		var colors := [Color("ffb83e"), Color("61d8ff"), Color("70edb7"), Color("db8aff"), Color("ff83ca")]
		var character_index := clampi(int(get_meta("character_index", 0)), 0, 4)
		var aura: Color = Color("bd70ff") if is_taya else colors[character_index]
		var direction := attack_direction.normalized()
		var center := Vector2(direction.x * 48.0, -86.0 + direction.y * 10.0) if character_index == 4 else Vector2(direction.x * 86.0, -118.0 + direction.y * 22.0)
		var pulse := 21.0 + 3.0 * sin(LanSession.clock_time() * 12.0)
		draw_arc(center, pulse, 0.0, TAU, 24, Color(aura, 0.76), 4.0, true)
		for ray_index in range(4):
			var ray := Vector2.RIGHT.rotated(ray_index * PI * 0.5 + LanSession.clock_time() * 1.2)
			draw_line(center + ray * 28.0, center + ray * 36.0, Color(aura, 0.65), 3.0, true)
	if has_thrower_special():
		for orb in range(3):
			var center := Vector2((orb - 1) * 58.0, 91.0)
			draw_circle(center, 23.0, Color("241a17"))
			draw_circle(center, 17.0, Color("49372c"))
			if orb < skill_charge:
				draw_circle(center, 15.0, Color("ffba32"))
				draw_circle(center + Vector2(-5, -5), 5.0, Color("fff1b1"))
				draw_arc(center, 21.0, 0.0, TAU, 32, Color("fff1b1"), 3.0, true)
			else:
				draw_arc(center, 20.0, 0.0, TAU, 32, Color("b2a08a"), 2.0, true)
	if has_thrower_special() and skill_charge == 3:
		draw_rect(Rect2(-95, 122, 190, 34), Color("241a17"))
		draw_string(SKILL_FONT, Vector2(-90, 149), "ARMED" if special_armed else "%s  SPECIAL" % UserSettings.short_binding_text("special"), HORIZONTAL_ALIGNMENT_CENTER, 180, 22, Color("fff1b1"))
	if LanSession.clock_time() < ability_glow_until:
		draw_arc(Vector2(0, -115), 106.0, 0, TAU, 48, Color(player_color.lightened(0.5), 0.75), 7.0, true)
	if is_stunned():
		for index in 3:
			var at := Vector2(-44 + index * 44, -235) + Vector2(0, sin(LanSession.clock_time() * 7.0 + index * 2.0) * 8.0)
			draw_circle(at, 9.0, Color("ffdf56"))
	if not is_local_view() or attack_state != AttackState.CHARGING or predicted_path.is_empty():
		return
	var spread: float = throw_quality().spread
	if spread > 0.0:
		var origin := to_local(get_throw_origin())
		var reach := origin.distance_to(to_local(predicted_path[-1]))
		var left := origin + attack_direction.rotated(deg_to_rad(-spread)) * reach
		var right := origin + attack_direction.rotated(deg_to_rad(spread)) * reach
		draw_colored_polygon(PackedVector2Array([origin, left, right]), Color(player_color, 0.13))
		draw_line(origin, left, Color(player_color, 0.5), 2.0, true)
		draw_line(origin, right, Color(player_color, 0.5), 2.0, true)
	for point in predicted_path:
		draw_circle(to_local(point), 3.5, Color(player_color.lightened(0.3), 0.8))
