extends SceneTree

# Exports every walk/sprint frame exactly as the game builds it (full texture
# size, margins included), plus the list of neighbouring frame pairs that need
# an in-between. tools/sprites/locomotion_inbetweens.py turns that into
# assets/characters/sprites/inbetween/. Pairs are keyed by source image, so
# Taya/empty-hand copies and mirrored directions share one generated frame.
#
# godot --headless --path . --script res://tools/sprites/export_locomotion_frames.gd -- <out dir>

const LOCOMOTION := "^(taya_|empty_)?(walk|sprint)_(right|down_right|down|down_left|left|up_left|up|up_right)$"
const INBETWEENS = preload("res://scenes/locomotion_inbetweens.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://locomotion"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var pattern := RegEx.create_from_string(LOCOMOTION)
	var frames_out := {}
	var pairs_out := {}
	var stage := Node2D.new()
	root.add_child(stage)
	for character in root.get_node("LanSession").CHARACTERS:
		for role in ["Thrower", "Taya"]:
			var actor = load("res://scenes/%s %s.tscn" % [role, character]).instantiate()
			actor.set_meta("skip_inbetweens", true) # export the authored frames only
			stage.add_child(actor)
			await process_frame
			var frames: SpriteFrames = actor.sprite.sprite_frames
			for animation in frames.get_animation_names():
				if pattern.search(String(animation)) == null:
					continue
				var count := frames.get_frame_count(animation)
				for index in range(count):
					var a := frames.get_frame_texture(animation, index)
					var b := frames.get_frame_texture(animation, (index + 1) % count)
					for texture in [a, b]:
						var id := INBETWEENS.texture_key(texture)
						if not frames_out.has(id):
							var file := "f%04d.png" % frames_out.size()
							_full_image(texture).save_png(out_dir.path_join(file))
							frames_out[id] = {"file": file, "character": character}
					var pair := INBETWEENS.pair_key(a, b)
					if not pairs_out.has(pair):
						pairs_out[pair] = {"a": frames_out[INBETWEENS.texture_key(a)].file, "b": frames_out[INBETWEENS.texture_key(b)].file, "character": character, "animation": String(animation).trim_prefix("taya_").trim_prefix("empty_")}
			actor.free()
	var manifest := FileAccess.open(out_dir.path_join("manifest.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"pairs": pairs_out}, "  "))
	manifest.close()
	print("exported %d frames, %d pairs to %s" % [frames_out.size(), pairs_out.size(), out_dir])
	quit(0)

# The texture as the sprite draws it: its full size with any atlas margin applied.
static func _full_image(texture: Texture2D) -> Image:
	var size := Vector2i(texture.get_size())
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var source := texture.get_image()
	source.convert(Image.FORMAT_RGBA8)
	var at := Vector2i.ZERO
	if texture is AtlasTexture:
		at = Vector2i((texture as AtlasTexture).margin.position)
	image.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), at)
	return image
