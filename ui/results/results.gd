extends Control

const UI = preload("res://ui/game_ui.gd")
var podium_players: Array[Node2D] = []

func _ready() -> void:
	Music.play_music("menu")
	LanSession.room_closed.connect(func(reason: String) -> void:
		LanSession.set_meta("notice", reason)
		get_tree().change_scene_to_file.call_deferred("res://ui/main_menu/main_menuu.tscn")
	)
	theme = UI.theme()
	var rankings: Array = LanSession.results
	var best := int(rankings[0].score) if not rankings.is_empty() else 0
	var leaders := rankings.filter(func(member: Dictionary) -> bool: return int(member.score) == best).size()
	for member in rankings:
		if member.id == LanSession.local_id() and LanSession.mode in ["lan", "online"]:
			UserSettings.record_result(LanSession.match_id, int(member.score) == best)
	var background := TextureRect.new()
	background.texture = preload("res://assets/ui/Sunset Campground Battle Stage.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.12, 0.06, 0.02, 0.32)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var title := "SHARED VICTORY" if leaders > 1 else "%s WINS!" % rankings[0].name if not rankings.is_empty() else "MATCH RESULTS"
	_text(title, Vector2(160, 65), Vector2(1600, 80), 56)
	_text("FINAL STANDINGS", Vector2(460, 155), Vector2(1000, 50), 26)
	var stage := Control.new()
	stage.name = "Podium"
	stage.position = Vector2(360, 280)
	stage.size = Vector2(1200, 550)
	add_child(stage)
	var positions := [600.0, 240.0, 960.0]
	var heights := [260.0, 200.0, 165.0]
	var colors := [Color("eeb63c"), Color("aebfc8"), Color("b87742")]
	for rank in range(3):
		var top: float = 500.0 - heights[rank]
		var block := Panel.new()
		block.name = "Place%d" % (rank + 1)
		block.position = Vector2(positions[rank] - 160, top)
		block.size = Vector2(320, heights[rank])
		block.add_theme_stylebox_override("panel", UI.panel(colors[rank], 6))
		stage.add_child(block)
		var place := UI.label(str(rank + 1), 64)
		place.position = Vector2(0, 20)
		place.size = Vector2(320, 85)
		block.add_child(place)
		if rank >= rankings.size(): continue
		var member: Dictionary = rankings[rank]
		var character := clampi(int(member.get("character", 0)), 0, LanSession.CHARACTERS.size() - 1)
		var scene := load("res://scenes/Taya %s.tscn" % LanSession.CHARACTERS[character]) as PackedScene
		if scene == null:
			push_error("Missing results character scene: %s" % LanSession.CHARACTERS[character])
			scene = load("res://scenes/Taya Head Band.tscn") as PackedScene
		if scene == null:
			continue
		var actor := scene.instantiate() as CharacterBody2D
		if actor == null:
			push_error("Invalid results character scene: %s" % LanSession.CHARACTERS[character])
			continue
		actor.position = Vector2(positions[rank], top - 10)
		actor.scale = Vector2.ONE * 0.85
		actor.accept_local_input = false
		actor.show_player_ring = false
		actor.show_gameplay_overlays = false
		actor.collision_layer = 0
		actor.collision_mask = 0
		stage.add_child(actor)
		actor.set_physics_process(false)
		actor.set_process(false)
		actor.throw_status.hide()
		podium_players.append(actor)
		var name_label := UI.label(str(member.name), 28)
		name_label.position = Vector2(positions[rank] - 175, top - 240)
		name_label.size = Vector2(350, 45)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stage.add_child(name_label)
		var score := UI.label("%d POINT%s" % [int(member.score), "" if int(member.score) == 1 else "S"], 26)
		score.position = Vector2(0, 110)
		score.size = Vector2(320, 45)
		block.add_child(score)
	for rank in range(3, rankings.size()):
		var member: Dictionary = rankings[rank]
		_text("%d. %s   %d point%s" % [rank + 1, member.name, member.score, "" if int(member.score) == 1 else "s"],Vector2(200 + (rank - 3) * 760, 825), Vector2(760, 55), 26)
	_build_awards(rankings)
	if LanSession.mode == "developer":
		_text("Games against AI do not affect saved statistics." if LanSession.is_vs_ai() else "Developer games do not affect saved statistics.", Vector2(300, 895), Vector2(1320, 40), 22)
	var leave := UI.button("Main Menu", func() -> void:
		LanSession.close_room()
		get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")
	)
	leave.position = Vector2(760, 965)
	leave.size = Vector2(400, 75)
	add_child(leave)
	_celebrate(stage, rankings)


# Podium blocks rise third → second → first, then players and names drop on,
# award cards slide in and confetti in the winner's colour falls for a moment.
func _celebrate(stage: Control, rankings: Array) -> void:
	var order := {"Place3": 0, "Place2": 1, "Place1": 2}
	for child in stage.get_children():
		var item := child as CanvasItem
		var resting: Vector2 = child.position
		item.modulate.a = 0.0
		var tween := create_tween().set_parallel()
		if order.has(child.name):
			var delay: float = 0.15 + order[child.name] * 0.18
			child.position.y += 340.0
			tween.tween_property(child, "position", resting, 0.55).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
		else:
			child.position.y -= 90.0
			tween.tween_property(child, "position", resting, 0.4).set_delay(0.85).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tween.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(0.85)
	var awards := get_node_or_null("Awards") as Control
	if awards != null:
		var resting_x := awards.position.x
		awards.position.x += 460.0
		var slide := create_tween()
		slide.tween_property(awards, "position:x", resting_x, 0.5).set_delay(1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var winner_color: Color = rankings[0].color if not rankings.is_empty() else Color("ffe29a")
	var confetti := CPUParticles2D.new()
	confetti.name = "Confetti"
	var image := Image.create(6, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	confetti.texture = ImageTexture.create_from_image(image)
	confetti.position = Vector2(960, -30)
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(960, 10)
	confetti.amount = 140
	confetti.lifetime = 4.5
	confetti.direction = Vector2.DOWN
	confetti.spread = 25.0
	confetti.initial_velocity_min = 120.0
	confetti.initial_velocity_max = 260.0
	confetti.gravity = Vector2(0, 160)
	confetti.angular_velocity_min = -360.0
	confetti.angular_velocity_max = 360.0
	confetti.angle_max = 360.0
	confetti.scale_amount_min = 0.8
	confetti.scale_amount_max = 1.6
	var palette := Gradient.new()
	palette.set_color(0, winner_color)
	palette.set_color(1, Color("ffd34d"))
	palette.add_point(0.33, Color("ff5f5f"))
	palette.add_point(0.66, Color("6fd3ff"))
	confetti.color_initial_ramp = palette
	add_child(confetti)
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		if is_instance_valid(confetti): confetti.emitting = false
	)
# Match awards: the player(s) with the most can hits, tags and safe returns.
const AWARDS := [
	{"key": "hits", "title": "SHARPSHOOTER", "unit": "can hit", "color": Color("2f7fcf")},
	{"key": "tags", "title": "TAG MASTER", "unit": "tag", "color": Color("c5271d")},
	{"key": "returns", "title": "SAFE HANDS", "unit": "safe return", "color": Color("1f8a4c")},
]

static func award_winners(rankings: Array, key: String) -> Dictionary:
	var best := 0
	var names: Array[String] = []
	for member in rankings:
		var value := int(member.get(key, 0))
		if value <= 0:
			continue
		if value > best:
			best = value
			names.clear()
		if value == best:
			names.append(str(member.name))
	return {"value": best, "names": names}

func _build_awards(rankings: Array) -> void:
	var column := VBoxContainer.new()
	column.name = "Awards"
	column.position = Vector2(1520, 300)
	column.custom_minimum_size = Vector2(370, 0)
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	for award in AWARDS:
		var winners := award_winners(rankings, award.key)
		if winners.names.is_empty():
			continue
		var card := PanelContainer.new()
		card.name = str(award.title).capitalize().replace(" ", "")
		var style := UI.panel(award.color, 5)
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", style)
		column.add_child(card)
		var copy := VBoxContainer.new()
		copy.add_theme_constant_override("separation", 2)
		card.add_child(copy)
		var heading := UI.label(award.title, 20)
		heading.add_theme_color_override("font_color", Color("ffe29a"))
		copy.add_child(heading)
		var who := UI.label(" & ".join(winners.names), 26)
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		who.custom_minimum_size.x = 320
		copy.add_child(who)
		var count: int = winners.value
		copy.add_child(UI.label("%d %s%s" % [count, award.unit, "" if count == 1 else "s"], 18))

func _text(copy: String, at: Vector2, dimensions: Vector2, font_size: int) -> void:
	var label := UI.label(copy, font_size)
	label.position = at
	label.size = dimensions
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(label)
