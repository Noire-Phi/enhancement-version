extends SceneTree

# Fails when an idle/walk/sprint frame is cut off: the drawing carries on past the edge of
# the texture region the game shows (opaque on both sides of the edge), so part of the
# body is clipped away. A whole-image frame is cut if it is opaque on its own border.
const MOTION := "^(taya_|empty_)?(idle|walk|sprint)_(right|down_right|down|down_left|left|up_left|up|up_right)$"
const INBETWEENS = preload("res://scenes/locomotion_inbetweens.gd")
const ALPHA := 40     # an edge pixel at least this opaque counts as drawing
const MIN_PIXELS := 4 # a few stray pixels on an edge are haze, not a cut limb

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var pattern := RegEx.create_from_string(MOTION)
	var stage := Node2D.new()
	root.add_child(stage)
	var seen := {}
	var atlases := {}
	var problems: Array[String] = []
	var checked := 0
	for character in root.get_node("LanSession").CHARACTERS:
		for role in ["Thrower", "Taya"]:
			var actor = load("res://scenes/%s %s.tscn" % [role, character]).instantiate()
			stage.add_child(actor)
			await process_frame
			var frames: SpriteFrames = actor.sprite.sprite_frames
			for animation in frames.get_animation_names():
				if pattern.search(String(animation)) == null:
					continue
				for index in range(frames.get_frame_count(animation)):
					var texture := frames.get_frame_texture(animation, index)
					var id := INBETWEENS.texture_key(texture)
					if seen.has(id):
						continue
					seen[id] = true
					checked += 1
					var cut := _cut_edges(texture, atlases)
					if not cut.is_empty():
						var where: String = "%s %s" % [(texture as AtlasTexture).atlas.resource_path, (texture as AtlasTexture).region] if texture is AtlasTexture else texture.resource_path
						problems.append("%s %s frame %d cut at %s | %s" % [character, animation, index, ", ".join(cut), where])
			actor.free()
	for problem in problems:
		printerr("CUT: ", problem)
	if problems.is_empty():
		print("PASS: %d unique idle/walk/sprint frames, none cut off at a region edge" % checked)
	else:
		printerr("FAIL: %d of %d frames cut off" % [problems.size(), checked])
	quit(0 if problems.is_empty() else 1)

static func _cut_edges(texture: Texture2D, atlases: Dictionary) -> Array[String]:
	var image: Image
	var rect: Rect2i
	if texture is AtlasTexture:
		var path := (texture as AtlasTexture).atlas.resource_path
		if not atlases.has(path):
			var full := (texture as AtlasTexture).atlas.get_image()
			full.convert(Image.FORMAT_RGBA8)
			atlases[path] = full
		image = atlases[path]
		rect = Rect2i((texture as AtlasTexture).region)
	else:
		image = texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		rect = Rect2i(Vector2i.ZERO, image.get_size())
	var w := image.get_width()
	var h := image.get_height()
	var data := image.get_data()
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x - 1
	var y1 := rect.end.y - 1
	# [edge pixel, the pixel just outside it]; outside the image counts as opaque only for
	# whole-image frames, where the image border itself is the cut.
	var whole := not texture is AtlasTexture
	var counts := {"top": 0, "bottom": 0, "left": 0, "right": 0}
	for x in range(x0, x1 + 1):
		if _cuts(data, w, h, x, y0, x, y0 - 1, whole): counts.top += 1
		if _cuts(data, w, h, x, y1, x, y1 + 1, whole): counts.bottom += 1
	for y in range(y0, y1 + 1):
		if _cuts(data, w, h, x0, y, x0 - 1, y, whole): counts.left += 1
		if _cuts(data, w, h, x1, y, x1 + 1, y, whole): counts.right += 1
	var cut: Array[String] = []
	for edge in counts:
		if counts[edge] >= MIN_PIXELS:
			cut.append("%s (%d px)" % [edge, counts[edge]])
	return cut

static func _cuts(data: PackedByteArray, w: int, h: int, x: int, y: int, ox: int, oy: int, whole: bool) -> bool:
	if data[(y * w + x) * 4 + 3] < ALPHA:
		return false
	if ox < 0 or oy < 0 or ox >= w or oy >= h:
		return whole
	return data[(oy * w + ox) * 4 + 3] >= ALPHA
