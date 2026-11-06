extends "res://game/network_world.gd"

const CHARACTER_SELECT = preload("res://ui/character_select/character_select.tscn")
const PRACTICE_TUTORIAL = preload("res://ui/waiting_room/practice_tutorial.gd")

@export var local_player_id: int = 1

@onready var ready_panel: Control = $ReadyPanel/Player_ready
@onready var ready_button: Button = $HUD/Screen/ReadyButton
@onready var ready_status: Label = $HUD/Screen/ReadyStatus
@onready var start_button: Button = $HUD/Screen/StartButton
@onready var start_frame: Panel = $HUD/Screen/StartFrame
@onready var start_frame_style: StyleBoxFlat = start_frame.get_theme_stylebox("panel")
@onready var player: CharacterBody2D = $Player
@onready var practice_cans: Array[CharacterBody2D] = [$PracticeCan, $PracticeCan2, $PracticeCan3]

var practice_hits := 0
var practice_origins: Array[Vector2] = []
var start_glow: StyleBoxFlat
var starting := false
var room_code_button: Button
var bot_controls: PanelContainer
var bot_count_label: Label
var fewer_bots: Button
var more_bots: Button
var developer_map_picker: OptionButton
var developer_role_picker: OptionButton
var selection_overlay: Control
var tutorial: Node
var stage := "waiting"


func _ready() -> void:
	Music.play_music("lobby")
	if LanSession.mode == "menu":
		LanSession.begin_local("developer")
	setup_network_world()
	local_player_id = LanSession.local_id()
	player = actors[local_player_id]
	LanSession.roster_changed.connect(_roster_changed)
	start_glow = start_frame_style.duplicate()
	start_glow.shadow_color = Color(1.0, 0.72, 0.12, 0.9)
	start_glow.shadow_size = 22
	start_glow.shadow_offset = Vector2.ZERO
	ready_panel.readiness_changed.connect(_refresh_start_button)
	start_button.pressed.connect(_on_start_pressed)
	ready_button.toggled.connect(_on_ready_toggled)
	$HUD/Screen/LeaveButton.pressed.connect(_leave)
	$HUD/Screen/ResetPractice.pressed.connect(_reset_practice)
	for can in practice_cans:
		practice_origins.append(can.base.global_position)
		can.state_changed.connect(_on_can_state_changed.bind(can))
	_on_ready_toggled(false)
	_build_room_code()
	_build_bot_controls()
	_roster_changed()
	_refresh_start_button()
	if LanSession.mode == "practice":
		ready_button.hide()
		$HUD/Screen/ReadyFrame.hide()
		ready_status.hide()
		$ReadyPanel.hide()
		$HUD/Screen/Title.hide()
		$HUD/Screen/PracticeTitle.hide()
		$HUD/Screen/PracticeHits.hide()
		room_code_button.hide()
		$HUD/Screen/ResetPractice.text = "Restart"
		$HUD/Screen/ResetPractice.tooltip_text = "Restart the guided tutorial."
		$HUD/Screen/ResetFrame.offset_left = 52
		$HUD/Screen/ResetFrame.offset_right = 274
		$HUD/Screen/ResetPractice.offset_left = 60
		$HUD/Screen/ResetPractice.offset_right = 266
		tutorial = PRACTICE_TUTORIAL.new()
		add_child(tutorial)
	$HUD/Screen/ResetPractice.visible = LanSession.is_host()
	$HUD/Screen/ResetFrame.visible = LanSession.is_host()
	_open_character_select()


func _open_character_select() -> void:
	if int(LanSession.member(local_player_id).get("character", -1)) >= 0:
		return
	selection_overlay = CHARACTER_SELECT.instantiate() as Control
	selection_overlay.popup_mode = true
	$HUD/Screen.add_child(selection_overlay)


func _is_local_host() -> bool:
	return LanSession.is_host()


func _refresh_start_button() -> void:
	var host := _is_local_host()
	var can_start: bool = LanSession.can_start() and not starting
	start_button.visible = host and LanSession.mode != "practice"
	start_frame.visible = start_button.visible
	start_button.disabled = not can_start
	start_button.tooltip_text = "Start the game" if can_start else "Wait for another player, then choose characters and ready up." if LanSession.mode in ["lan", "online"] and LanSession.players.size() < 2 else "Every player must choose a character and be ready."
	start_frame.add_theme_stylebox_override("panel", start_glow if can_start else start_frame_style)
	$HUD/Screen/ReadyFrame.offset_left = -608.0 if host else -440.0
	$HUD/Screen/ReadyFrame.offset_right = -308.0 if host else -48.0
	ready_button.offset_left = -600.0 if host else -432.0
	ready_button.offset_right = -316.0 if host else -56.0
	ready_button.add_theme_font_size_override("font_size", 36 if host else 42)
	_refresh_bot_controls()


func _on_start_pressed() -> void:
	# Recheck at activation as readiness can change after the button was enabled.
	if starting or not LanSession.can_start():
		return
	starting = true
	_refresh_start_button()
	if not LanSession.start_match():
		starting = false
		ready_status.text = "COULDN'T START. TRY AGAIN."
		_refresh_start_button()


func _on_can_state_changed(_new_state: int, can: CharacterBody2D) -> void:
	if can.is_toppled():
		practice_hits += 1
		$HUD/Screen/PracticeHits.text = "%d %s" % [practice_hits, "HIT" if practice_hits == 1 else "HITS"]


func _reset_practice() -> void:
	if not LanSession.is_host():
		return
	if LanSession.mode == "practice" and is_instance_valid(tutorial):
		tutorial.restart()
		return
	# Keep the full Thrower scene's cancellation and retrieval behavior.
	player.set_taya_role(false)
	if is_instance_valid(player.active_slipper):
		player.active_slipper.queue_free()
	player.active_slipper = null
	for i in range(practice_cans.size()):
		var can := practice_cans[i]
		can.base.global_position = practice_origins[i]
		can.reset_for_preview(practice_origins[i])
	practice_hits = 0
	$HUD/Screen/PracticeHits.text = "0 HITS"


func _on_ready_toggled(is_ready: bool) -> void:
	if is_ready and int(LanSession.member(local_player_id).get("character", -1)) < 0:
		ready_button.set_pressed_no_signal(false)
		ready_status.text = "CHOOSE A CHARACTER FIRST"
		return
	LanSession.set_ready(is_ready)
	ready_status.text = "YOU ARE READY" if is_ready else "YOU ARE NOT READY"
	ready_button.text = "Not ready" if is_ready else "Ready"


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(selection_overlay):
			return
		_leave()


func _unhandled_input(event: InputEvent) -> void:
	if LanSession.mode != "practice" or not is_instance_valid(player) or is_instance_valid(selection_overlay):
		return
	if not event.is_action_pressed("special") and not event.is_action_released("special"):
		return
	var pressed := event.is_action_pressed("special")
	if pressed and event is InputEventMouseButton and get_viewport().gui_get_hovered_control() != null:
		return
	if player.is_taya:
		if pressed: player.begin_taya_stun_aim()
		else: player.release_taya_stun(UserSettings.aim_position(player))
	elif pressed and player.has_thrower_special() and player.skill_charge == 3:
		player.special_armed = not player.special_armed
		player.queue_redraw()
	get_viewport().set_input_as_handled()

func _local_inputs_enabled() -> bool:
	return not is_instance_valid(selection_overlay)


func _leave() -> void:
	LanSession.close_room()
	get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")


func _roster_changed() -> void:
	ready_panel.set_roster(LanSession.players)
	player = actors.get(local_player_id, player)
	var own: Dictionary = LanSession.member(local_player_id)
	if not own.is_empty():
		var character: int = int(own.character)
		ready_button.set_pressed_no_signal(own.ready)
		ready_button.text = "Not ready" if own.ready else "Ready"
		ready_button.disabled = character < 0
		ready_button.tooltip_text = "Choose a character first" if character < 0 else "Change your ready status"
		ready_status.text = "CHOOSE A CHARACTER FIRST" if character < 0 else "YOU ARE READY" if own.ready else "YOU ARE NOT READY"
	_refresh_start_button()


func _build_room_code() -> void:
	room_code_button = Button.new()
	room_code_button.name = "RoomCode"
	room_code_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	room_code_button.offset_left = -825
	room_code_button.offset_right = -630
	room_code_button.offset_top = -171 if LanSession.mode == "lan" else -145
	room_code_button.offset_bottom = -55
	room_code_button.add_theme_font_size_override("font_size", 20 if LanSession.mode == "lan" else 23)
	if LanSession.mode == "lan":
		room_code_button.text = "ROOM %s\n%s\nBUILD %s" % [LanSession.room_code, LanSession.host_address, LanSession.LAN_PROTOCOL.get_slice("-", 3)]
	elif LanSession.mode == "online":
		room_code_button.text = "ROOM CODE\n" + LanSession.room_code
	elif LanSession.mode == "developer":
		room_code_button.text = _developer_room_text()
	else:
		room_code_button.text = "PRACTICE"
	room_code_button.tooltip_text = "Copy online room code • Up to 4 players" if LanSession.mode == "online" else "Copy room code • UDP %d • Friends need the same game update" % LanSession.PORT if LanSession.mode == "lan" else "Developer games and practice do not change saved statistics."
	room_code_button.pressed.connect(func() -> void:
		if LanSession.mode in ["lan", "online"]:
			DisplayServer.clipboard_set(LanSession.room_code)
	)
	$HUD/Screen.add_child(room_code_button)


func _build_bot_controls() -> void:
	if LanSession.mode != "developer" or not LanSession.is_host():
		return
	var ui = preload("res://ui/game_ui.gd")
	bot_controls = PanelContainer.new()
	bot_controls.name = "BotCount"
	bot_controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bot_controls.offset_left = -440
	bot_controls.offset_right = -48
	bot_controls.offset_top = 688
	bot_controls.offset_bottom = 860
	var style: StyleBoxFlat = ui.panel()
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.content_margin_left = 18
	style.content_margin_right = 18
	bot_controls.add_theme_stylebox_override("panel", style)
	$HUD/Screen.add_child(bot_controls)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	bot_controls.add_child(controls)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	controls.add_child(row)
	bot_count_label = ui.label("", 22)
	bot_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(bot_count_label)
	fewer_bots = Button.new()
	more_bots = Button.new()
	for button in [fewer_bots, more_bots]:
		button.custom_minimum_size = Vector2(64, 44)
		button.add_theme_font_size_override("font_size", 28)
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, start_button.get_theme_stylebox(state))
		row.add_child(button)
	fewer_bots.text = "-"
	fewer_bots.tooltip_text = "Remove one bot"
	fewer_bots.pressed.connect(_change_bot_count.bind(-1))
	more_bots.text = "+"
	more_bots.tooltip_text = "Add one bot"
	more_bots.pressed.connect(_change_bot_count.bind(1))
	developer_map_picker = _developer_picker(controls, "MAP", ["RANDOM", "COURTYARD", "ESKINITA", "DUSTY YARD"])
	developer_map_picker.name = "DeveloperMap"
	developer_map_picker.select(LanSession.developer_map + 1)
	developer_map_picker.item_selected.connect(func(index: int) -> void:
		if not starting and LanSession.phase == "waiting": LanSession.developer_map = index - 1
	)
	developer_role_picker = _developer_picker(controls, "PLAY AS", ["RANDOM", "PLAYER", "TAYA"])
	developer_role_picker.name = "DeveloperRole"
	developer_role_picker.select(["random", "player", "taya"].find(LanSession.developer_role))
	developer_role_picker.item_selected.connect(func(index: int) -> void:
		if starting or LanSession.phase != "waiting": return
		LanSession.developer_role = ["random", "player", "taya"][index]
		if LanSession.developer_role == "player": LanSession.developer_bot_count = maxi(1, LanSession.developer_bot_count)
		_refresh_bot_controls()
	)
	_refresh_bot_controls()


func _developer_picker(controls: VBoxContainer, title: String, options: Array) -> OptionButton:
	var ui = preload("res://ui/game_ui.gd")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	controls.add_child(row)
	var label: Label = ui.label(title, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(220, 44)
	picker.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		picker.add_theme_stylebox_override(state, start_button.get_theme_stylebox(state))
	for option in options: picker.add_item(option)
	var popup := picker.get_popup()
	popup.theme = ui.theme()
	popup.add_theme_stylebox_override("panel", ui.panel())
	popup.add_theme_stylebox_override("hover", ui.panel(Color("168f43"), 2))
	popup.add_theme_font_size_override("font_size", 24)
	popup.add_theme_color_override("font_color", Color("fff5dc"))
	row.add_child(picker)
	return picker


func _change_bot_count(change: int) -> void:
	if LanSession.mode != "developer" or not LanSession.is_host() or LanSession.phase != "waiting" or starting:
		return
	var minimum := 1 if LanSession.developer_role == "player" else 0
	LanSession.developer_bot_count = maxi(minimum, LanSession.developer_bot_count + change)
	_refresh_bot_controls()


func _refresh_bot_controls() -> void:
	if bot_controls == null:
		return
	bot_controls.visible = not starting
	bot_count_label.text = "BOTS  %d" % LanSession.developer_bot_count
	fewer_bots.disabled = LanSession.developer_bot_count <= (1 if LanSession.developer_role == "player" else 0)
	more_bots.disabled = LanSession.developer_bot_count == LanSession.MAX_PLAYERS - 1
	bot_controls.tooltip_text = "Player needs at least one bot to be Taya." if LanSession.developer_role == "player" else "No opponents; solo mechanics test." if LanSession.developer_bot_count == 0 else "Bots join when you press Start."
	room_code_button.text = _developer_room_text()


func _extra_snapshot() -> Dictionary:
	return {"hits": practice_hits}


func _apply_extra_snapshot(data: Dictionary) -> void:
	practice_hits = int(data.get("hits", 0))
	$HUD/Screen/PracticeHits.text = "%d HITS" % practice_hits


func _developer_room_text() -> String:
	var count := LanSession.developer_bot_count
	if LanSession.is_vs_ai():
		return "VS AI · %s\n%d CPU" % [LanSession.ai_difficulty.to_upper(), count]
	return "DEVELOPER\n%d %s" % [count, "BOT" if count == 1 else "BOTS"]
