extends "res://scenes/player_movement_neutral.gd"

## Adapts each character's existing drawings to the shared thrower/Taya rules.
@export var art_kind: StringName = &"thrower"
@export var relaxed_cardinal: Texture2D
@export var relaxed_diagonal: Texture2D
@export var release_sheet: Texture2D
@export var neutral_idle_sheet: Texture2D
@export var side_walk_sheet: Texture2D
@export var side_sprint_sheet: Texture2D

const POLISHED_HEIGHT := 210.0
var polished_bounds: Dictionary = {}


func _ready() -> void:
	var scale_at_rest: Vector2 = sprite.scale
	var frames: SpriteFrames = _normalized_frames(sprite.sprite_frames)
	sprite.sprite_frames = frames
	attack_sprite.sprite_frames = frames
	idle_sprite_scale = scale_at_rest
	walk_scale_multiplier = 1.0
	mirror_down_left_walk = false
	mirror_up_left_walk = false
	diagonal_walk_scale = 1.0
	down_diagonal_walk_scale = 1.0
	up_diagonal_walk_scale = 1.0
	up_diagonal_lean_degrees = 0.0
	diagonal_walk_y_offset = 0.0
	sprint_cardinal_scale = 1.0
	sprint_cardinal_y_offset = 0.0
	taya_visual.configure(frames, scale_at_rest)
	super._ready()
	sprite.frame_changed.connect(_fit_polished_frame)
	_fit_polished_frame()


func _normalized_frames(source: SpriteFrames) -> SpriteFrames:
	var result := SpriteFrames.new()
	if result.has_animation(&"default"):
		result.remove_animation(&"default")
	for direction in DIRECTIONS:
		var lookup: String = "right" if direction == "left" else direction
		var diagonal: bool = lookup.contains("_")
		var prefix: String = "diagonal_" if diagonal else ""
		var suffix: String = "" if art_kind == &"bullcap" else "_throw"
		var idle_source: StringName = StringName(prefix + "idle" + suffix + "_" + lookup)
		var walk_source: StringName = StringName(prefix + "walk" + suffix + "_" + lookup)
		var release_source: StringName = StringName(prefix + "throw_" + lookup)
		if art_kind == &"bullcap":
			release_source = walk_source
		if art_kind == &"bullcap":
			_copy_frames(result, source, StringName("idle_" + direction), idle_source, true, 5.0)
		else:
			# The supplied idle sheets are aiming poses. Rest on the empty-hand
			# recovery drawing and reserve those sheets for the charge animation.
			_copy_empty_hand(result, source, StringName("idle_" + direction), release_source, false)
		_copy_frames(result, source, StringName("walk_" + direction), walk_source, true, 8.0)
		_copy_frames(result, source, StringName("sprint_" + direction), walk_source, true, 11.0)
		_copy_frames(result, source, StringName("aim_" + direction), idle_source, true, 5.0)
		_copy_frames(result, source, StringName("throw_" + direction), release_source, false, 12.0, art_kind == &"bullcap")
		if art_kind == &"bullcap":
			_copy_frames(result, source, StringName("taya_idle_" + direction), idle_source, true, 5.0)
			_copy_frames(result, source, StringName("taya_walk_" + direction), walk_source, true, 8.0)
			_copy_frames(result, source, StringName("taya_sprint_" + direction), walk_source, true, 11.0)
		else:
			_copy_empty_hand(result, source, StringName("taya_idle_" + direction), release_source, false)
			_copy_empty_hand(result, source, StringName("taya_walk_" + direction), release_source, true)
			_copy_empty_hand(result, source, StringName("taya_sprint_" + direction), release_source, true)
		if relaxed_cardinal != null and relaxed_diagonal != null:
			var sheet := relaxed_diagonal if diagonal else relaxed_cardinal
			# These sheets use the same row order as the authored release frames.
			var row := ["down_left", "up_left", "up_right", "down_right"].find(lookup) if diagonal else ["down", "left", "up", "right"].find(lookup)
			# Five rows of near-square cells; enhanced sheets hold 8 frames per row
			# (drawn poses plus in-betweens), so speed scales to keep the stride.
			var columns := maxi(1, roundi(sheet.get_width() / (sheet.get_height() / 5.0 * 1.025)))
			for name_prefix in ["", "taya_"]:
				for action in (["idle", "walk", "sprint"] if name_prefix == "" else ["walk", "sprint"]):
					var name := StringName(name_prefix + action + "_" + direction)
					result.clear(name)
					result.set_animation_speed(name, 1.0 if action == "idle" else (11.0 if action == "sprint" else 8.0) * columns / 4.0)
					for frame in ([0] if action == "idle" else range(columns)):
						var texture := AtlasTexture.new()
						texture.atlas = sheet
						var cell := Vector2(sheet.get_width() / float(columns), sheet.get_height() / 5.0)
						texture.region = Rect2(Vector2(frame, row) * cell + Vector2(0, 12), cell - Vector2(0, 12))
						texture.margin = Rect2(0, 12, 0, 12)
						texture.filter_clip = true
						result.add_frame(name, texture)
		if release_sheet != null:
			var row := ["down", "down_left", "left", "up_left", "up", "up_right", "right", "down_right"].find(direction)
			var cell := Vector2(release_sheet.get_width() / 4.0, release_sheet.get_height() / 8.0)
			for action in ["aim", "throw"]:
				var name := StringName(action + "_" + direction)
				result.clear(name)
				for frame in ([1] if action == "aim" else [1, 1, 2, 3]):
					var texture := AtlasTexture.new()
					texture.atlas = release_sheet
					texture.region = Rect2(Vector2(frame, row) * cell, cell)
					texture.filter_clip = true
					result.add_frame(name, texture)
		_install_polished_frames(result, direction)
	return result


func _install_polished_frames(frames: SpriteFrames, direction: String) -> void:
	if neutral_idle_sheet != null:
		var order := ["down", "left", "up", "right", "down_left", "up_left", "up_right", "down_right"]
		var index := order.find(direction)
		var texture := _polished_cell(neutral_idle_sheet, index % 4, index / 4, 4, 2)
		for prefix in ["", "taya_"]:
			var name := StringName(prefix + "idle_" + direction)
			frames.clear(name)
			frames.set_animation_speed(name, 1.0)
			frames.add_frame(name, texture)
	if direction not in ["left", "right"]:
		return
	for action in ["walk", "sprint"]:
		var sheet := side_walk_sheet if action == "walk" else side_sprint_sheet
		if sheet == null:
			continue
		# Side sheets are one row of 3:4 cells; enhanced sheets carry 8 frames
		# (originals plus in-betweens), so the rate scales to keep the same stride.
		var columns := maxi(1, roundi(sheet.get_width() / (sheet.get_height() * 0.75)))
		for prefix in ["", "taya_"]:
			var name := StringName(prefix + action + "_" + direction)
			frames.clear(name)
			frames.set_animation_speed(name, (6.0 if action == "walk" else 8.0) * columns / 4.0)
			for column in range(columns):
				frames.add_frame(name, _polished_cell(sheet, column, 0, columns, 1))


func _polished_cell(sheet: Texture2D, column: int, row: int, columns: int, rows: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	var from := Vector2(floorf(float(column) * sheet.get_width() / columns), floorf(float(row) * sheet.get_height() / rows))
	var to := Vector2(floorf(float(column + 1) * sheet.get_width() / columns), floorf(float(row + 1) * sheet.get_height() / rows))
	texture.region = Rect2(from, to - from)
	texture.filter_clip = true
	return texture


func _fit_polished_frame() -> void:
	var animation_name := String(sprite.animation)
	if not ("idle_" in animation_name or "walk_" in animation_name or "sprint_" in animation_name):
		return
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if not texture is AtlasTexture:
		return
	var id := texture.get_instance_id()
	if not polished_bounds.has(id):
		polished_bounds[id] = texture.get_image().get_used_rect()
	var bounds: Rect2i = polished_bounds[id]
	if bounds.size.y <= 0:
		return
	var fitted_scale := POLISHED_HEIGHT / float(bounds.size.y)
	sprite.scale = Vector2.ONE * fitted_scale
	sprite.position = Vector2(0.0, -(float(bounds.end.y) - texture.get_size().y * 0.5) * fitted_scale)


func _copy_frames(target: SpriteFrames, source: SpriteFrames, name: StringName, original: StringName, looped: bool, speed: float, select_three: bool = false) -> void:
	target.add_animation(name)
	target.set_animation_loop(name, looped)
	target.set_animation_speed(name, speed)
	if not source.has_animation(original):
		push_error("Missing character animation: " + String(original))
		return
	var count: int = source.get_frame_count(original)
	if select_three and count >= 3:
		for index in [0, floori(float(count) / 3.0), floori(float(count * 2) / 3.0)]:
			target.add_frame(name, source.get_frame_texture(original, index))
	else:
		for index in range(count):
			target.add_frame(name, source.get_frame_texture(original, index), source.get_frame_duration(original, index))


func _copy_empty_hand(target: SpriteFrames, source: SpriteFrames, name: StringName, original: StringName, moving: bool) -> void:
	target.add_animation(name)
	target.set_animation_loop(name, true)
	target.set_animation_speed(name, 8.0 if moving else 1.0)
	var count: int = source.get_frame_count(original)
	if count < 3:
		push_error("No empty-hand frames in " + String(original))
		return
	if moving:
		for index in [count - 2, count - 1, count - 2, count - 1]:
			target.add_frame(name, _trim_recovery_frame(source.get_frame_texture(original, index)))
	else:
		target.add_frame(name, _trim_recovery_frame(source.get_frame_texture(original, count - 1)))


func _trim_recovery_frame(texture: Texture2D) -> Texture2D:
	# Some old atlas cells contain the previous row's shoe at their upper edge.
	if not texture is AtlasTexture: return texture
	var trimmed: AtlasTexture = texture.duplicate()
	trimmed.region.position.y += 12
	trimmed.region.size.y -= 12
	trimmed.margin.position.y += 12
	trimmed.margin.size.y += 12
	trimmed.filter_clip = true
	return trimmed


func _play(action: String, direction: Vector2) -> void:
	super._play(action, direction)
	# The new idle sheet contains a separately drawn left pose; only the
	# right-facing side gait is mirrored for left movement.
	var direction_name: String = DIRECTIONS[(roundi(direction.angle() / (PI / 4.0)) + 8) % 8]
	sprite.flip_h = direction_name == "left" and (action != "idle" or neutral_idle_sheet == null)
	_fit_polished_frame()
	if action == "idle" and neutral_idle_sheet != null:
		# A slow, tiny weight shift gives the one-pose idle a pulse without
		# moving its feet or changing the character's size.
		var lean := sin(Time.get_ticks_msec() * 0.0016) * deg_to_rad(0.6)
		sprite.rotation = lean
		sprite.position.x = sin(lean) * POLISHED_HEIGHT * 0.5


func _set_attack_visual(sector: int, _releasing: bool) -> void:
	attack_sprite.scale = idle_sprite_scale
	attack_sprite.position = Vector2(0.0, idle_sprite_y)
	attack_sprite.flip_h = sector == 4
	if release_sheet != null:
		attack_sprite.scale *= Vector2(280.0 * 0.9 / (release_sheet.get_width() / 4.0), 273.0 * 0.9 / (release_sheet.get_height() / 8.0))
		attack_sprite.flip_h = false
