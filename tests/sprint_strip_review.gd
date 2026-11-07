extends Node2D

# Renders every frame of each character's walk and sprint as the game draws them, one row
# per animation on a shared ground line, to review body size, foot contact and clipping.
const CHARACTERS := ["Hat Thrower", "Head Band", "Glasses Thrower", "Curly Haired", "Bullcap Head", "Leonardo", "Kay"]
const ROWS := [["sprint", "right"], ["sprint", "down_right"], ["sprint", "up_right"], ["walk", "right"], ["walk", "down"]]
const COLUMNS := 16


func _ready() -> void:
	_capture.call_deferred()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("4b4b4b"))
	for row in range(ROWS.size()):
		var y := _ground(row)
		draw_line(Vector2(10, y), Vector2(1910, y), Color("a9a9a9"), 2.0)


func _ground(row: int) -> float:
	return 175.0 + row * 210.0


func _capture() -> void:
	for character in CHARACTERS:
		var nodes: Array[Node] = []
		for row in range(ROWS.size()):
			var action: String = ROWS[row][0]
			var direction: String = ROWS[row][1]
			for column in range(COLUMNS):
				var actor = load("res://scenes/Thrower %s.tscn" % character).instantiate()
				actor.position = Vector2(62 + column * 119, _ground(row))
				actor.scale = Vector2.ONE * 0.62
				actor.show_gameplay_overlays = false
				add_child(actor)
				actor.set_process(false)
				actor.set_physics_process(false)
				actor._play(action, Vector2.RIGHT.rotated(actor.DIRECTIONS.find(direction) * PI / 4.0))
				var frame_count: int = actor.sprite.sprite_frames.get_frame_count(actor.sprite.animation)
				actor.sprite.frame = column % frame_count
				if actor.has_method("_fit_polished_frame"):
					actor._fit_polished_frame()
				if actor.has_method("_align_current_motion_frame"):
					actor._align_current_motion_frame()
				actor.sprite.pause()
				nodes.append(actor)
				if column == 0:
					var label := Label.new()
					label.text = "%s %s (%d frames)" % [action, direction, frame_count]
					label.position = Vector2(12, _ground(row) + 4)
					label.add_theme_font_size_override("font_size", 18)
					add_child(label)
					nodes.append(label)
		await get_tree().process_frame
		await get_tree().process_frame
		var path := "res://tests/sprint_strip_review_%s.png" % character.to_lower().replace(" ", "_")
		get_viewport().get_texture().get_image().save_png(path)
		print("REVIEW: ", path)
		for node in nodes:
			node.queue_free()
		await get_tree().process_frame
	get_tree().quit()
