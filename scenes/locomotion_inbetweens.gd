extends RefCounted

# Generated in-between frames for walk/sprint cycles (see tools/sprites/).
# Each entry sits between two source images, keyed by those images, so every
# animation that uses the pair (thrower, Taya, empty-hand, mirrored) shares it.
# An animation is rebuilt only if every neighbouring pair has an in-between; it
# then has twice the frames at twice the rate, so the stride timing is unchanged.

const INDEX_PATH := "res://assets/characters/sprites/inbetween/index.json"
const LOCOMOTION := "^(taya_|empty_)?(walk|sprint)_(right|down_right|down|down_left|left|up_left|up|up_right)$"

static var _index: Dictionary = {}
static var _loaded := false
static var _textures: Dictionary = {}

static func texture_key(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		return "%s|%s|%s" % [atlas.atlas.resource_path, atlas.region, atlas.margin]
	return texture.resource_path

static func pair_key(a: Texture2D, b: Texture2D) -> String:
	return texture_key(a) + " >> " + texture_key(b)

static func _pairs() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(INDEX_PATH):
			_index = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH)).get("pairs", {})
	return _index

static func _generated(entry: Dictionary) -> AtlasTexture:
	var key := "%s|%s" % [entry.atlas, entry.rect]
	if not _textures.has(key):
		var texture := AtlasTexture.new()
		texture.atlas = load(entry.atlas)
		var rect: Array = entry.rect
		var full: Array = entry.size
		texture.region = Rect2(rect[0], rect[1], rect[2], rect[3])
		# Margin restores the source frame's full size, so fitting and feet match.
		texture.margin = Rect2(rect[4], rect[5], float(full[0]) - rect[2], float(full[1]) - rect[3])
		texture.filter_clip = true
		_textures[key] = texture
	return _textures[key]

static func install(frames: SpriteFrames) -> int:
	var pairs := _pairs()
	if pairs.is_empty():
		return 0
	var pattern := RegEx.create_from_string(LOCOMOTION)
	var upgraded := 0
	for animation in frames.get_animation_names():
		if pattern.search(String(animation)) == null:
			continue
		var count := frames.get_frame_count(animation)
		var sources: Array[Texture2D] = []
		var middles: Array[Texture2D] = []
		for index in range(count):
			var a := frames.get_frame_texture(animation, index)
			var b := frames.get_frame_texture(animation, (index + 1) % count)
			var entry = pairs.get(pair_key(a, b))
			if entry == null:
				break
			sources.append(a)
			middles.append(_generated(entry))
		if middles.size() != count or count < 2:
			continue
		var speed := frames.get_animation_speed(animation)
		frames.clear(animation)
		for index in range(count):
			frames.add_frame(animation, sources[index])
			frames.add_frame(animation, middles[index])
		frames.set_animation_speed(animation, speed * 2.0)
		upgraded += 1
	return upgraded
