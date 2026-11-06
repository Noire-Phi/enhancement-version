extends "res://scenes/player_movement_neutral.gd"

## Leonardo and Kay use the same host-owned rules as the original roster.
## Their directional art is kept in separate atlases so every action retains
## the character's own head, outfit, and foot placement.
@export_enum("leonardo", "kay") var art_name := "leonardo"

const THROW_ROWS := {
	"leonardo": {
		"cardinal": [36, 369, 695, 1005],
		"diagonal": [61, 382, 700, 1013],
	},
	"kay": {
		"cardinal": [62, 374, 688, 1005],
		"diagonal": [25, 356, 683, 1003],
	},
}
const CARDINAL := ["down", "left", "up", "right"]
const DIAGONAL := ["down_right", "up_left", "up_right", "down_left"]
const ATLAS_REGIONS_PATH := "res://assets/characters/sprites/new_roster/atlas_regions.json"
var previous_carry_visual := false
var can_transition_until := 0.0
var atlas_regions: Dictionary = {}
var motion_geometry: Dictionary = {}


func _process(delta: float) -> void:
	super._process(delta)
	if not is_taya:
		previous_carry_visual = false
		can_transition_until = 0.0
		return
	if is_taya and carrying_can != previous_carry_visual:
		previous_carry_visual = carrying_can
		taya_visual.play_action(&"pickup" if carrying_can else &"place", 2)
		can_transition_until = LanSession.clock_time() + 0.34
	if can_transition_until > LanSession.clock_time() and is_taya and not is_stunned() and not taya_stun_aiming and taya_action == &"":
		sprite.hide()
		attack_sprite.hide()
		taya_visual.show()
	elif can_transition_until > 0.0:
		can_transition_until = 0.0
		if taya_visual.action == &"pickup" or taya_visual.action == &"place":
			taya_visual.action = &""
			taya_visual.hide()
			sprite.show()
func _ready() -> void:
	atlas_regions = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_REGIONS_PATH)) as Dictionary
	var frames := _character_frames()
	sprite.sprite_frames = frames
	attack_sprite.sprite_frames = frames
	idle_sprite_scale = Vector2.ONE * (0.72 if art_name == "leonardo" else 0.68)
	collision_width_ratio = 0.55
	walk_scale_multiplier = 0.75 / idle_sprite_scale.x
	mirror_down_left_walk = false
	mirror_up_left_walk = false
	diagonal_walk_scale = 1.0
	down_diagonal_walk_scale = 1.0
	up_diagonal_walk_scale = 1.0
	up_diagonal_lean_degrees = 0.0
	sprint_cardinal_scale = 1.0
	taya_visual.configure(frames, idle_sprite_scale)
	super._ready()
	sprite.frame_changed.connect(_align_current_motion_frame)
	_align_current_motion_frame()


func has_thrower_special() -> bool:
	return false


func _build_reaction_frames() -> void:
	# Dedicated reaction drawings are installed with the directional bank.
	pass


func _character_frames() -> SpriteFrames:
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	var path := "res://assets/characters/sprites/new_roster/%s/" % art_name
	for direction in DIRECTIONS:
		var diagonal := direction.contains("_")
		var suffix := "diagonal" if diagonal else "cardinal"
		var idle_row: int = (DIAGONAL if diagonal else CARDINAL).find(direction)
		var idle_key := "idle_" + suffix
		var idle_sheet := load(path + idle_key + ".png") as Texture2D
		var idle_cells: Array[Texture2D] = []
		var idle_heights: Array[float] = []
		for column in range(4):
			idle_cells.append(_grid_cell(idle_sheet, idle_key, column, idle_row))
			idle_heights.append(_cell_height(idle_key, column, idle_row))
		_add(result, "idle_" + direction, idle_cells, true, 3.0)
		_record_geometry("idle_" + direction, idle_key, idle_heights)
		var reaction_key := "reaction_" + suffix
		var reaction_sheet := load(path + reaction_key + ".png") as Texture2D
		var reaction_cells: Array[Texture2D] = []
		var reaction_heights: Array[float] = []
		for column in range(4):
			reaction_cells.append(_grid_cell(reaction_sheet, reaction_key, column, idle_row))
			reaction_heights.append(_cell_height(reaction_key, column, idle_row))
		_add(result, "hit_" + direction, [reaction_cells[0]], false, 8.0)
		_add(result, "stunned_" + direction, [reaction_cells[1], reaction_cells[2]], true, 4.0)
		_add(result, "recover_" + direction, [reaction_cells[3]], false, 8.0)
		_record_geometry("hit_" + direction, reaction_key, [reaction_heights[0]])
		_record_geometry("stunned_" + direction, reaction_key, [reaction_heights[1], reaction_heights[2]])
		_record_geometry("recover_" + direction, reaction_key, [reaction_heights[3]])
		var carry_sheet := load(path + "carry_" + suffix + ".png") as Texture2D
		var carry_cells: Array[Texture2D] = []
		var carry_heights: Array[float] = []
		for column in range(4):
			carry_cells.append(_grid_cell(carry_sheet, "carry_" + suffix, column, idle_row))
			carry_heights.append(_cell_height("carry_" + suffix, column, idle_row))
		_add(result, "carry_idle_" + direction, [carry_cells[0]], true, 1.0)
		_add(result, "carry_walk_" + direction, carry_cells, true, 8.0)
		_record_geometry("carry_idle_" + direction, "carry_" + suffix, [carry_heights[0]])
		_record_geometry("carry_walk_" + direction, "carry_" + suffix, carry_heights)
		for action in ["walk", "sprint"]:
			var key: String = action + "_" + ("diagonal_v2" if diagonal else "cardinal")
			var sheet := load(path + key + ".png") as Texture2D
			var cells: Array[Texture2D] = []
			var heights: Array[float] = []
			var geometry_key := key
			var source_key := key
			var row: int = (0 if direction in ["down_right", "down_left"] else 1) if diagonal else CARDINAL.find(direction)
			if direction in ["left", "right"]:
				# The side-view cycle includes both shoe contacts and passing steps.
				source_key = "side_" + action + "_cycle"
				sheet = load(path + source_key + ".png") as Texture2D
				row = 0
				geometry_key = source_key
			# Cardinal in-betweens are hand-drawn; diagonal and side walk ones were
			# generated for the enhancement version. Any listed sheet doubles the frames.
			var inbetween_key := source_key + "_inbetween"
			var has_inbetween: bool = atlas_regions[art_name].has(inbetween_key)
			var inbetween_sheet := load(path + inbetween_key + ".png") as Texture2D if has_inbetween else null
			for column in range(4):
				cells.append(_grid_cell(sheet, source_key, column, row))
				heights.append(_cell_height(source_key, column, row))
				if has_inbetween:
					cells.append(_grid_cell(inbetween_sheet, inbetween_key, column, row))
					heights.append(_cell_height(inbetween_key, column, row))
			var speed := 6.0 if action == "walk" and (diagonal or direction in ["left", "right"]) else 7.0 if action == "sprint" and (diagonal or direction in ["left", "right"]) else 8.0 if action == "walk" else 11.0
			# Keep the stride rate where generated in-betweens doubled a 4-frame cycle.
			if has_inbetween and (diagonal or direction in ["left", "right"]):
				speed *= 2.0
			_add(result, action + "_" + direction, cells, true, speed)
			_record_geometry(action + "_" + direction, geometry_key, heights)
		# Thrower release uses its separately authored directional atlas.
		var throw_source := "down_right" if direction == "down_left" else direction
		var throw_row: int = (DIAGONAL if diagonal else CARDINAL).find(throw_source)
		var throw_sheet := load(path + "throw_" + suffix + ".png") as Texture2D
		var throw_cells: Array[Texture2D] = []
		for column in range(4):
			throw_cells.append(_action_cell(throw_sheet, column, int(THROW_ROWS[art_name][suffix][throw_row])))
		_add(result, "throw_" + direction, throw_cells, false, 12.0)
		var throw_name := StringName("throw_" + direction)
		if result.has_animation(throw_name):
			var aim_cells: Array[Texture2D] = [result.get_frame_texture(throw_name, 0)]
			_add(result, "aim_" + direction, aim_cells, true, 1.0)
		for action in ["idle", "walk", "sprint"]:
			var source := StringName(action + "_" + direction)
			var copies: Array[Texture2D] = []
			for frame in range(result.get_frame_count(source)):
				copies.append(result.get_frame_texture(source, frame))
			_add(result, "taya_" + action + "_" + direction, copies, true, result.get_animation_speed(source))
	return result


func _add(frames: SpriteFrames, name: String, cells: Array[Texture2D], looped: bool, speed: float) -> void:
	var animation := StringName(name)
	frames.add_animation(animation)
	frames.set_animation_loop(animation, looped)
	frames.set_animation_speed(animation, speed)
	for cell in cells:
		frames.add_frame(animation, cell)


func _action_cell(sheet: Texture2D, column: int, top: int) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(column * sheet.get_width() / 4.0, top, sheet.get_width() / 4.0, 320)
	atlas.filter_clip = true
	return atlas


func _grid_cell(sheet: Texture2D, key: String, column: int, row: int) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	var source: Dictionary = atlas_regions[art_name][key]
	var values: Array = source["cells"][row][column]
	var canvas: Array = source["canvas"]
	var region_size := Vector2(float(values[2]), float(values[3]))
	var canvas_size := Vector2(float(canvas[0]), float(canvas[1]))
	atlas.region = Rect2(Vector2(float(values[0]), float(values[1])), region_size)
	var padding := canvas_size - region_size
	atlas.margin = Rect2(Vector2(floorf(padding.x / 2.0), padding.y), padding)
	atlas.filter_clip = true
	return atlas


func _cell_height(key: String, column: int, row: int) -> float:
	return float(atlas_regions[art_name][key]["cells"][row][column][3])


func _record_geometry(name: String, key: String, heights: Array[float]) -> void:
	motion_geometry[name] = {
		"canvas_height": float(atlas_regions[art_name][key]["canvas"][1]),
		"heights": heights,
	}


func _align_current_motion_frame() -> void:
	var name := String(sprite.animation)
	if name.begins_with("empty_"):
		name = name.trim_prefix("empty_")
	elif name.begins_with("taya_"):
		name = name.trim_prefix("taya_")
	if not motion_geometry.has(name):
		return
	var geometry: Dictionary = motion_geometry[name]
	var heights: Array = geometry["heights"]
	var content_height: float = float(heights[mini(sprite.frame, heights.size() - 1)])
	var scale_factor := 210.0 / content_height
	sprite.scale = Vector2.ONE * scale_factor
	sprite.rotation = 0.0
	sprite.position = Vector2(0, -float(geometry["canvas_height"]) * scale_factor * 0.5)


func _movement_animation(action: String, direction_name: String) -> StringName:
	if is_taya and carrying_can and action in ["idle", "walk", "sprint"]:
		var carry_action := "idle" if action == "idle" else "walk"
		return StringName("carry_" + carry_action + "_" + direction_name)
	return super._movement_animation(action, direction_name)


func _build_cast_frames() -> void:
	var frames: SpriteFrames = attack_sprite.sprite_frames.duplicate(true)
	var path := "res://assets/characters/sprites/new_roster/%s/" % art_name
	for direction in DIRECTIONS:
		var diagonal := direction.contains("_")
		var suffix := "diagonal" if diagonal else "cardinal"
		var row: int = (DIAGONAL if diagonal else CARDINAL).find(direction)
		var sheet := load(path + "taya_stun_" + suffix + ".png") as Texture2D
		var cast_cells: Array[Texture2D] = []
		for column in range(4):
			cast_cells.append(_grid_cell(sheet, "taya_stun_" + suffix, column, row))
		_add(frames, "taya_stun_aim_" + direction, [cast_cells[0]], true, 1.0)
		# The second drawing switches the slipper between hands in some rows.
		# Hold the grounded windup briefly, then use the clean empty-hand release.
		_add(frames, "taya_stun_throw_" + direction, [cast_cells[0], cast_cells[0], cast_cells[2], cast_cells[3]], false, 12.0)
		for action in ["aim", "throw"]:
			var original := StringName(action + "_" + direction)
			var copies: Array[Texture2D] = []
			for index in range(frames.get_frame_count(original)):
				copies.append(frames.get_frame_texture(original, index))
			_add(frames, "special_" + action + "_" + direction, copies, frames.get_animation_loop(original), frames.get_animation_speed(original))
	attack_sprite.sprite_frames = frames


func _play(action: String, direction: Vector2) -> void:
	if is_taya and carrying_can and action == "sprint":
		action = "walk"
	super._play(action, direction)
	var sector := (roundi(direction.angle() / (PI / 4.0)) + 8) % 8
	# Down-left mirrors one clean right-facing pose; the other directions use
	# their own authored head and body orientation.
	sprite.flip_h = (sector in [3, 4, 5] and action in ["walk", "sprint"] and not (is_taya and carrying_can))
	if action == "sprint" and DIRECTIONS[sector] == "left":
		var name := _movement_animation(action, "left")
		if sprite.animation != name:
			var previous_frame := sprite.frame
			sprite.play(name)
			sprite.frame = mini(previous_frame, sprite.sprite_frames.get_frame_count(name) - 1)
	_align_current_motion_frame()


func _set_attack_visual(_sector: int, _releasing: bool) -> void:
	if is_taya:
		attack_sprite.scale = Vector2.ONE * (0.72 if art_name == "leonardo" else 0.76)
		attack_sprite.position = Vector2(0, -104)
		attack_sprite.flip_h = false
		return
	attack_sprite.scale = Vector2.ONE
	attack_sprite.position = Vector2(0, -92)
	attack_sprite.flip_h = _sector == 3
