extends Node2D

# Renders every frame of Leonardo's and Kay's side and diagonal sprints as the game draws
# them, one row per direction on a shared ground line, to review body size and foot contact.
const CHARACTERS := ["Leonardo", "Kay"]
const DIRECTIONS := ["right", "down_right", "up_right"]
const GROUND := [330.0, 660.0, 990.0]


func _ready() -> void:
	_capture.call_deferred()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("4b4b4b"))
	for y in GROUND:
		draw_line(Vector2(20, y), Vector2(1900, y), Color("a9a9a9"), 2.0)


func _capture() -> void:
	for character in CHARACTERS:
		var nodes: Array[Node] = []
		for row in range(DIRECTIONS.size()):
			for column in range(8):
				var actor = load("res://scenes/Thrower %s.tscn" % character).instantiate()
				actor.position = Vector2(130 + column * 235, GROUND[row])
				actor.scale = Vector2.ONE * 1.1
				actor.show_gameplay_overlays = false
				add_child(actor)
				actor.set_process(false)
				actor.set_physics_process(false)
				var direction: String = DIRECTIONS[row]
				actor._play("sprint", Vector2.RIGHT.rotated(actor.DIRECTIONS.find(direction) * PI / 4.0))
				var frame_count: int = actor.sprite.sprite_frames.get_frame_count(actor.sprite.animation)
				actor.sprite.frame = column % frame_count
				actor._align_current_motion_frame()
				actor.sprite.pause()
				nodes.append(actor)
				var label := Label.new()
				label.text = "%s %d/%d" % [direction, actor.sprite.frame + 1, frame_count]
				label.position = actor.position + Vector2(-80, 8)
				label.add_theme_font_size_override("font_size", 20)
				add_child(label)
				nodes.append(label)
		await get_tree().process_frame
		await get_tree().process_frame
		var path := "res://tests/sprint_strip_review_%s.png" % character.to_lower()
		get_viewport().get_texture().get_image().save_png(path)
		print("REVIEW: ", path)
		for node in nodes:
			node.queue_free()
		await get_tree().process_frame
	get_tree().quit()
