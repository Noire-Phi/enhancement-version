extends Control

const UI = preload("res://ui/game_ui.gd")
var name_input: LineEdit
var online_view: Dictionary = {}
var online_status: Label
var online_buttons: Array[Button] = []

@onready var play_local: Button = $PlayLocal
@onready var popup: Control = $LocalPlayPopup
@onready var backdrop: ColorRect = $LocalPlayPopup/Backdrop
@onready var card: Panel = $LocalPlayPopup/Card
@onready var host: Button = $LocalPlayPopup/Card/Host
@onready var join: Button = $LocalPlayPopup/Card/Join
@onready var close_button: Button = $LocalPlayPopup/Card/Close
var popup_tween: Tween


func _ready() -> void:
	Music.play_music("menu")
	_build_profile_controls()
	_color_menu_buttons()
	play_local.pressed.connect(_show_local_popup)
	$PlayOnline.pressed.connect(_show_online_popup)
	LanSession.room_joined.connect(_online_ready)
	LanSession.connection_status_changed.connect(_online_status_changed)
	host.pressed.connect(_open_host)
	join.pressed.connect(_open_join)
	close_button.pressed.connect(_hide_local_popup)
	backdrop.gui_input.connect(_on_backdrop_input)
	$Avatar.pressed.connect(_show_customization)
	$Settings.pressed.connect(_show_settings)
	play_local.grab_focus()
	_play_entrance()
	if LanSession.has_meta("notice"):
		var notice = UI.modal(self, "ROOM CLOSED", str(LanSession.get_meta("notice")))
		notice.content.add_child(UI.button("Back to menu", notice.layer.queue_free))
		LanSession.remove_meta("notice")


# Logo pops in, then menu buttons (with their shadow plates) slide in from the
# screen edges in a short stagger. Arrive with a slight overshoot, never block input.
func _play_entrance() -> void:
	var logo: Control = $TextureRect
	logo.pivot_offset = logo.size * 0.5
	logo.scale = Vector2.ONE * 0.6
	logo.modulate.a = 0.0
	var pop := create_tween().set_parallel()
	pop.tween_property(logo, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(logo, "modulate:a", 1.0, 0.25)
	var columns := [[["PlayOnline", "PlayLocal", "Practice", "VsAI"], -1.0], [["Avatar", "Friends", "Statistics"], 1.0]]
	for column in columns:
		var index := 0
		for button_name in column[0]:
			for node_name in [button_name, "ButtonShadow_" + button_name]:
				var item := get_node_or_null(NodePath(node_name)) as Control
				if item == null: continue
				var resting := item.position
				item.position.x += 520.0 * column[1]
				item.modulate.a = 0.0
				var slide := create_tween().set_parallel()
				slide.tween_property(item, "position", resting, 0.45).set_delay(0.12 + index * 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				slide.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(0.12 + index * 0.07)
			index += 1


func _show_local_popup() -> void:
	if popup_tween and popup_tween.is_running():
		popup_tween.kill()
	popup.show()
	backdrop.modulate.a = 0.0
	card.modulate.a = 0.0
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.92, 0.92)
	popup_tween = create_tween().set_parallel()
	popup_tween.tween_property(backdrop, "modulate:a", 1.0, 0.18)
	popup_tween.tween_property(card, "modulate:a", 1.0, 0.18)
	popup_tween.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	host.grab_focus()


func _hide_local_popup() -> void:
	if popup_tween and popup_tween.is_running():
		popup_tween.kill()
	popup.hide()
	play_local.grab_focus()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_hide_local_popup()


func _unhandled_key_input(event: InputEvent) -> void:
	if popup.visible and event.is_action_pressed("ui_cancel"):
		_hide_local_popup()
		get_viewport().set_input_as_handled()


func _open_host() -> void:
	_save_name()
	var host_error := LanSession.host_room()
	if host_error == OK:
		get_tree().change_scene_to_file("res://ui/waiting_room/waiting_room.tscn")
	else:
		var notice = UI.modal(self, "COULDN'T HOST", "Could not open LAN port %d (error %d). Check whether another app is using it." % [LanSession.PORT, host_error])
		notice.content.add_child(UI.button("Okay", notice.layer.queue_free))


func _open_join() -> void:
	_save_name()
	get_tree().change_scene_to_file("res://ui/lobby/join_local.tscn")


func _show_customization() -> void:
	_save_name()
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var screen := preload("res://ui/character_customization/character_customization.tscn").instantiate()
	screen.connect("closed", func() -> void:
		name_input.text = UserSettings.display_name
		layer.queue_free()
	)
	layer.add_child(screen)

func _show_settings() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var screen := preload("res://ui/settings/settings.tscn").instantiate()
	screen.closed.connect(func() -> void:
		layer.queue_free()
		$Settings.grab_focus()
	)
	layer.add_child(screen)


func _build_profile_controls() -> void:
	var profile_title := UI.label("YOUR NAME", 24)
	profile_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	profile_title.offset_left = -195
	profile_title.offset_right = 195
	profile_title.offset_top = -140
	profile_title.offset_bottom = -106
	profile_title.theme = UI.theme()
	add_child(profile_title)
	name_input = LineEdit.new()
	name_input.name = "PlayerName"
	name_input.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	name_input.offset_left = -195
	name_input.offset_right = 195
	name_input.offset_top = -98
	name_input.offset_bottom = -36
	name_input.theme = UI.theme()
	name_input.max_length = 20
	name_input.placeholder_text = "Enter your name"
	name_input.text = UserSettings.display_name
	name_input.text_submitted.connect(func(_value: String) -> void: _save_name(); name_input.release_focus())
	name_input.focus_exited.connect(_save_name)
	add_child(name_input)
	var practice_shadow := $ButtonShadow_PlayLocal.duplicate()
	practice_shadow.name = "ButtonShadow_Practice"
	practice_shadow.position.y += 128
	add_child(practice_shadow)
	var practice: Button = $PlayLocal.duplicate()
	practice.name = "Practice"
	practice.position.y += 128
	practice.text = "Practice"
	practice.pressed.connect(_open_practice)
	add_child(practice)
	var vs_ai_shadow := $ButtonShadow_PlayLocal.duplicate()
	vs_ai_shadow.name = "ButtonShadow_VsAI"
	vs_ai_shadow.position.y += 256
	add_child(vs_ai_shadow)
	var vs_ai: Button = $PlayLocal.duplicate()
	vs_ai.name = "VsAI"
	vs_ai.position.y += 256
	vs_ai.text = "VS AI"
	vs_ai.tooltip_text = "Play offline against computer opponents"
	vs_ai.pressed.connect(_show_vs_ai_popup)
	add_child(vs_ai)
	var statistics_shadow := $ButtonShadow_Friends.duplicate()
	statistics_shadow.name = "ButtonShadow_Statistics"
	statistics_shadow.position.y += 128
	add_child(statistics_shadow)
	var statistics_button: Button = $Friends.duplicate()
	statistics_button.name = "Statistics"
	statistics_button.position.y += 128
	statistics_button.text = "Statistics"
	statistics_button.pressed.connect(_show_statistics)
	add_child(statistics_button)


func _color_menu_buttons() -> void:
	var colors := {
		"PlayOnline": Color("4d91e8"), "PlayLocal": Color("57b948"),
		"Practice": Color("33b8b2"), "VsAI": Color("f08a32"), "Avatar": Color("a575e0"),
		"Friends": Color("e96eb4"), "Statistics": Color("f5d34c"),
		"Messages": Color("f26c60"), "Settings": Color("e6c79b"),
	}
	for button_name in colors:
		var button: Button = get_node(NodePath(button_name))
		var color: Color = colors[button_name]
		for state in ["normal", "hover", "pressed"]:
			var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
			style.bg_color = color.lightened(0.12) if state == "hover" else color.darkened(0.12) if state == "pressed" else color
			if state != "pressed" and button_name not in ["Messages", "Settings"]:
				style.border_color = color.darkened(0.32)
			button.add_theme_stylebox_override(state, style)
		var shadow: Panel = get_node_or_null(NodePath("ButtonShadow_" + button_name))
		if shadow != null:
			var style: StyleBoxFlat = shadow.get_theme_stylebox("panel").duplicate()
			style.bg_color = color.darkened(0.32)
			shadow.add_theme_stylebox_override("panel", style)


func _save_name() -> void:
	UserSettings.set_display_name(name_input.text)
	name_input.text = UserSettings.display_name


func _open_practice() -> void:
	_save_name()
	LanSession.begin_local("practice")
	get_tree().change_scene_to_file("res://ui/waiting_room/waiting_room.tscn")


const AI_LEVELS := [
	["easy", "EASY", "Slow, wobbly throws. Taya walks.", Color("3f9a4a")],
	["normal", "NORMAL", "Decent aim and quick reactions.", Color("d48a1c")],
	["hard", "HARD", "Near-perfect throws. Taya hunts you.", Color("c5271d")],
]
var ai_choice := "normal"
var ai_bots := 4

func _show_vs_ai_popup() -> void:
	_save_name()
	var view = UI.modal(self, "VS AI", "Offline match against computer opponents. Pick how tough they are.")
	view.layer.name = "VsAIPopup"
	var levels := HBoxContainer.new()
	levels.alignment = BoxContainer.ALIGNMENT_CENTER
	levels.add_theme_constant_override("separation", 18)
	view.content.add_child(levels)
	var detail := UI.label("", 22)
	detail.add_theme_color_override("font_color", Color("ffe29a"))
	var buttons: Array[Button] = []
	var refresh := func() -> void:
		for index in range(AI_LEVELS.size()):
			var level: Array = AI_LEVELS[index]
			var chosen: bool = level[0] == ai_choice
			var button: Button = buttons[index]
			button.text = ("▶ " if chosen else "") + level[1]
			var style := UI.panel(level[3] if chosen else Color("624228"), 6 if chosen else 4)
			if chosen: style.border_color = Color("fff0a8")
			for state in ["normal", "hover", "pressed", "focus"]:
				button.add_theme_stylebox_override(state, style)
			if chosen: detail.text = level[2]
	for level in AI_LEVELS:
		var button := UI.button(level[1], func() -> void: pass)
		button.name = "AI" + str(level[1]).capitalize()
		button.custom_minimum_size = Vector2(260, 72)
		button.pressed.connect(func() -> void:
			ai_choice = level[0]
			refresh.call()
		)
		levels.add_child(button)
		buttons.append(button)
	view.content.add_child(detail)
	var count_row := HBoxContainer.new()
	count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	count_row.add_theme_constant_override("separation", 18)
	view.content.add_child(count_row)
	var count := UI.label("", 28)
	count.custom_minimum_size.x = 300
	var set_count := func(value: int) -> void:
		ai_bots = clampi(value, 1, LanSession.MAX_PLAYERS - 1)
		count.text = "%d OPPONENT%s" % [ai_bots, "" if ai_bots == 1 else "S"]
	var fewer := UI.button("−", func() -> void: set_count.call(ai_bots - 1))
	var more := UI.button("+", func() -> void: set_count.call(ai_bots + 1))
	for button in [fewer, more]: button.custom_minimum_size = Vector2(72, 64)
	count_row.add_child(fewer)
	count_row.add_child(count)
	count_row.add_child(more)
	set_count.call(ai_bots)
	refresh.call()
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 20)
	view.content.add_child(actions)
	var start := UI.button("Start", func() -> void:
		LanSession.begin_vs_ai(ai_choice, ai_bots)
		get_tree().change_scene_to_file("res://ui/waiting_room/waiting_room.tscn")
	)
	start.name = "StartVsAI"
	actions.add_child(start)
	actions.add_child(UI.button("Back", view.layer.queue_free))
	buttons[AI_LEVELS.map(func(level: Array) -> String: return level[0]).find(ai_choice)].grab_focus()


func _show_statistics() -> void:
	var stats: Dictionary = UserSettings.statistics
	var body := "Wins: %d       Losses: %d\n\nSuccessful throws: %d\nCan knockdowns: %d\n\nSaved on this PC. Practice and developer games do not affect totals." % [stats.wins, stats.losses, stats.successful_throws, stats.can_knockdowns]
	var view = UI.modal(self, "YOUR STATISTICS", body)
	view.content.add_child(UI.button("Back", view.layer.queue_free))


func _show_online_popup() -> void:
	_save_name()
	if not online_view.is_empty() and is_instance_valid(online_view.layer): return
	online_view = UI.modal(self, "PLAY ONLINE", "Create a room or enter a friend's code. Up to 4 players.")
	var address := LineEdit.new()
	address.name = "OnlineCode"
	address.placeholder_text = "7-character room code"
	address.max_length = 9
	address.add_theme_color_override("font_placeholder_color", Color("765436"))
	address.custom_minimum_size = Vector2(0, 64)
	online_view.content.add_child(address)
	online_status = UI.label("", 22)
	online_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	online_view.content.add_child(online_status)
	online_buttons.clear()
	var create := UI.button("Create Room", func() -> void: _connect_online(true, ""))
	create.name = "CreateOnlineRoom"
	var join_button := UI.button("Join Room", func() -> void: _connect_online(false, address.text))
	join_button.name = "JoinOnlineRoom"
	for button in [create, join_button]:
		online_view.content.add_child(button)
		online_buttons.append(button)
	address.text_submitted.connect(func(_text: String) -> void:
		if not join_button.disabled: _connect_online(false, address.text)
	)
	online_view.content.add_child(UI.button("Back", func() -> void:
		LanSession.close_room()
		online_view.layer.queue_free()
		online_view = {}
	))
	address.grab_focus()

func _connect_online(create: bool, code: String) -> void:
	online_status.text = "Creating your online room..." if create else "Joining the online room..."
	var error := LanSession.host_online() if create else LanSession.join_online(code)
	for button in online_buttons:
		button.disabled = error == OK

func _online_ready() -> void:
	if LanSession.mode == "online" and LanSession.phase == "waiting":
		get_tree().change_scene_to_file.call_deferred("res://ui/waiting_room/waiting_room.tscn")

func _online_status_changed(message: String) -> void:
	if online_view.is_empty() or not is_instance_valid(online_view.layer): return
	online_status.text = message
	for button in online_buttons:
		button.disabled = LanSession.phase == "joining"
