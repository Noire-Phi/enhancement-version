extends Node

signal roster_changed
signal character_claim_result(index: int, accepted: bool)
signal connection_status_changed(message: String)
signal room_joined
signal room_closed(reason: String)
signal input_received(peer_id: int, packet: Dictionary)
signal throw_input_received(peer_id: int, pressed: bool, charge: int, at_time: float, aim: Vector2)
signal skill_requested(peer_id: int, pressed: bool, aim: Vector2)
signal world_snapshot_received(snapshot: Dictionary)
signal match_event_received(event: Dictionary)

const PROTOCOL := "canclash-rules-17"
const LAN_PROTOCOL := "canclash-lan-abilities-13"
const ONLINE_CAPACITY := 4
const PORT := 54652
const MAX_PLAYERS := 5
const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const COLORS := [Color("329dff"), Color("ff7344"), Color("51c878"), Color("bf83ff"), Color("ff6fae")]
const CHARACTERS := ["Hat Thrower", "Head Band", "Glasses Thrower", "Curly Haired", "Bullcap Head", "Leonardo", "Kay"]
const CHARACTER_SCENES := [
	"res://scenes/Thrower Hat Thrower.tscn", "res://scenes/Thrower Head Band.tscn",
	"res://scenes/Thrower Glasses Thrower.tscn", "res://scenes/Thrower Curly Haired.tscn",
	"res://scenes/Thrower Bullcap Head.tscn", "res://scenes/Thrower Leonardo.tscn",
	"res://scenes/Thrower Kay.tscn",
]

var players: Array[Dictionary] = []
var mode := "menu"
var phase := "menu"
var room_code := ""
var host_address := ""
var join_target := ""
var selected_map := 0
var selection_seed := 0
var match_id := ""
var results: Array = []
var join_deadline := 0.0
var tutorial_ready: Dictionary = {}
var last_input_time: Dictionary = {}
var input_deadline: Dictionary = {}
var event_sequence := 0
var online: Node
var online_sender := 0
var send_sequence := 0
var throw_sequence := 0
var world_sequence := 0
var received_world := -1
var received_event := -1
var received_inputs: Dictionary = {}
var received_throws: Dictionary = {}
var held_throws: Dictionary = {}
var outgoing_throw := false
var clock_offset := 0.0
var clock_tick := 0.0
var pending_clock := -1.0
var developer_map := -1 # -1 keeps normal random selection.
var developer_role := "random"
var developer_bot_count := 4:
	set(value):
		developer_bot_count = clampi(value, 0, MAX_PLAYERS - 1)
# Offline VS AI mode reuses the local developer room with tuned bots.
# Empty means bots play at full strength (developer testing).
const AI_DIFFICULTIES := ["easy", "normal", "hard"]
const AI_PROFILES := {
	# release: charge-meter spread around the sweet spot; aim: pixel error at the can;
	# think: seconds between movement decisions; lunge: Taya dash trigger range.
	"easy": {"release": 0.30, "aim": 70.0, "think": 0.45, "lunge": 170.0, "taya_sprint": false},
	"normal": {"release": 0.12, "aim": 30.0, "think": 0.2, "lunge": 230.0, "taya_sprint": true},
	"hard": {"release": 0.03, "aim": 6.0, "think": 0.0, "lunge": 290.0, "taya_sprint": true},
}
var ai_difficulty := ""

func is_vs_ai() -> bool:
	return mode == "developer" and ai_difficulty in AI_DIFFICULTIES

func bot_profile() -> Dictionary:
	return AI_PROFILES[ai_difficulty] if is_vs_ai() else {"release": 0.025, "aim": 0.0, "think": 0.0, "lunge": 290.0, "taya_sprint": true}

func begin_vs_ai(difficulty: String, bots: int) -> void:
	begin_local("developer")
	ai_difficulty = difficulty if difficulty in AI_DIFFICULTIES else "normal"
	room_code = "VS AI"
	developer_role = "random"
	developer_map = -1
	developer_bot_count = maxi(1, bots)

func _ready() -> void:
	online = preload("res://autoload/gdsync_transport.gd").new()
	online.name = "OnlineTransport"
	add_child(online)
	online.joined.connect(_online_joined)
	online.message_received.connect(_online_message)
	online.peer_left.connect(_peer_left)
	online.failed.connect(_failed)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func() -> void: _failed("Could not connect. Check the code/address and the host's firewall."))
	multiplayer.server_disconnected.connect(func() -> void: _failed("The host closed the room."))
	multiplayer.peer_disconnected.connect(_peer_left)

func is_networked() -> bool:
	return mode == "online" or multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer

func is_host() -> bool:
	return online.is_host() if mode == "online" else not is_networked() or multiplayer.is_server()

func local_id() -> int:
	return online.local_id() if mode == "online" else multiplayer.get_unique_id() if is_networked() else 1

func member(id: int) -> Dictionary:
	for entry in players:
		if entry.id == id:
			return entry
	return {}

func chosen_character() -> int:
	return CHARACTER_SCENES.find(UserSettings.selected_character_scene)

func _own_member(id: int, slot: int) -> Dictionary:
	return {"id": id, "name": UserSettings.display_name, "ready": false, "slot": slot, "character": -1, "color": COLORS[UserSettings.player_color_index], "bot": false}

func close_room() -> void:
	online.stop()
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	tutorial_ready.clear()
	last_input_time.clear()
	input_deadline.clear()
	mode = "menu"
	phase = "menu"
	room_code = ""
	ai_difficulty = ""
	host_address = ""
	join_target = ""
	join_deadline = 0.0
	held_throws.clear()
	received_inputs.clear()
	received_throws.clear()
	send_sequence = 0
	throw_sequence = 0
	world_sequence = 0
	received_world = -1
	event_sequence = 0
	received_event = -1
	outgoing_throw = false
	clock_offset = 0.0
	pending_clock = -1.0
	clock_tick = 0.0

func capacity() -> int:
	return ONLINE_CAPACITY if mode == "online" else MAX_PLAYERS

func clock_time() -> float:
	return Time.get_ticks_msec() / 1000.0 + (clock_offset if is_networked() and not is_host() else 0.0)

func host_online() -> Error:
	close_room()
	mode = "online"
	phase = "joining"
	join_deadline = Time.get_ticks_msec() / 1000.0 + 30.0
	return online.begin(true)

func join_online(raw: String) -> Error:
	close_room()
	var code := raw.strip_edges().to_upper().replace("-", "")
	if code.length() != 7 or not Array(code.split("")).all(func(c: String) -> bool: return CODE_ALPHABET.contains(c)):
		connection_status_changed.emit("Enter the 7-character online room code.")
		return ERR_INVALID_PARAMETER
	mode = "online"
	phase = "joining"
	join_deadline = Time.get_ticks_msec() / 1000.0 + 30.0
	return online.begin(false, code)

func _online_joined(creator: bool) -> void:
	room_code = online.code
	if creator:
		phase = "waiting"
		join_deadline = 0.0
		players.append(_own_member(1, 0))
		roster_changed.emit()
		room_joined.emit()
	else:
		_connected()

func _send(method: String, arguments: Array = [], id: int = 0, reliable: bool = true) -> void:
	if mode == "online":
		online.send(id, method, arguments, reliable)
	elif is_networked():
		var target := Callable(self, method)
		if id == 0: target.rpc.callv(arguments)
		else: target.rpc_id.callv([id] + arguments)

func _sender_id() -> int:
	return online_sender if mode == "online" else multiplayer.get_remote_sender_id()

func _online_message(sender: int, method: String, arguments: Array) -> void:
	var requests := {"_register": 3, "_request_ready": 1, "_request_character": 1, "_tutorial_ack": 0, "_submit_input": 1, "_throw_edge": 5, "_request_skill": 2, "_clock_ping": 1}
	var updates := {"_sync_roster": 2, "_character_result": 2, "_begin_selection": 3, "_world_state": 2, "_match_event": 1, "_show_results": 1, "_reject": 1, "_clock_pong": 2}
	if is_host():
		if sender <= 1 or not requests.has(method) or arguments.size() != requests[method]: return
	else:
		if sender != 1 or not updates.has(method) or arguments.size() != updates[method]: return
	var expected := {
		"_register": [TYPE_STRING, TYPE_INT, TYPE_STRING], "_request_ready": [TYPE_BOOL], "_request_character": [TYPE_INT],
		"_tutorial_ack": [], "_submit_input": [TYPE_DICTIONARY], "_request_skill": [TYPE_BOOL, TYPE_VECTOR2],
		"_throw_edge": [TYPE_BOOL, TYPE_INT, TYPE_INT, TYPE_FLOAT, TYPE_VECTOR2],
		"_clock_ping": [TYPE_FLOAT], "_clock_pong": [TYPE_FLOAT, TYPE_FLOAT],
		"_sync_roster": [TYPE_ARRAY, TYPE_STRING], "_character_result": [TYPE_INT, TYPE_BOOL], "_begin_selection": [TYPE_INT, TYPE_INT, TYPE_STRING],
		"_world_state": [TYPE_PACKED_BYTE_ARRAY, TYPE_INT], "_match_event": [TYPE_DICTIONARY],
		"_show_results": [TYPE_ARRAY], "_reject": [TYPE_STRING],
	}
	for index in range(arguments.size()):
		if typeof(arguments[index]) != expected[method][index]: return
	online_sender = sender
	Callable(self, method).callv(arguments)
	online_sender = 0

@rpc("authority", "call_remote", "reliable")
func _reject(reason: String) -> void:
	_failed(reason)

func begin_local(local_mode: String = "developer") -> void:
	close_room()
	mode = local_mode
	phase = "waiting"
	room_code = "DEV" if mode == "developer" else "PRACTICE"
	players.append(_own_member(1, 0))
	roster_changed.emit()

func host_room() -> Error:
	close_room()
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("0.0.0.0")
	var error := peer.create_server(PORT, MAX_PLAYERS - 1)
	if error != OK:
		connection_status_changed.emit("Couldn't open LAN port %d (error %d). Check whether another app is using it." % [PORT, error])
		return error
	multiplayer.multiplayer_peer = peer
	mode = "lan"
	phase = "waiting"
	host_address = _lan_address()
	room_code = encode_address(host_address)
	players.append(_own_member(1, 0))
	roster_changed.emit()
	return OK

func join_room(address_or_code: String) -> Error:
	close_room()
	var target := address_or_code.strip_edges()
	if not target.is_valid_ip_address():
		target = decode_code(target)
	if target.is_empty():
		connection_status_changed.emit("Enter a valid room code or the host's LAN IP address.")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(target, PORT)
	if error != OK:
		connection_status_changed.emit("Couldn't open the connection. Check the address.")
		return error
	multiplayer.multiplayer_peer = peer
	mode = "lan"
	phase = "joining"
	join_target = target
	join_deadline = Time.get_ticks_msec() / 1000.0 + 10.0
	connection_status_changed.emit("Connecting to %s:%d..." % [target, PORT])
	return OK

func _connected() -> void:
	_send("_register", [UserSettings.display_name, UserSettings.player_color_index, LAN_PROTOCOL if mode == "lan" else PROTOCOL], 1)
	_request_clock()

@rpc("any_peer", "call_remote", "reliable")
func _register(player_name: String, color_index: int, protocol: String) -> void:
	if not is_host(): return
	var sender := _sender_id()
	if protocol != (LAN_PROTOCOL if mode == "lan" else PROTOCOL):
		_send("_reject", ["Different game version. Everyone must use the same updated build."], sender)
		return
	if phase != "waiting":
		_send("_reject", ["This match has already started."], sender)
		return
	if sender <= 1 or not member(sender).is_empty():
		return
	if players.size() >= capacity():
		_send("_reject", ["This room is full (%d players)." % capacity()], sender)
		return
	if color_index < 0 or color_index >= COLORS.size():
		_send("_reject", ["Invalid player color. Update your game and try again."], sender)
		return
	var used: Array = players.map(func(entry: Dictionary) -> int: return entry.slot)
	var slot := 0
	while used.has(slot):
		slot += 1
	var clean := UserSettings.clean_name(player_name)
	players.append({"id": sender, "name": clean if not clean.is_empty() else "Player", "ready": false, "slot": slot, "character": -1, "color": COLORS[color_index], "bot": false})
	_publish_roster()

func _publish_roster() -> void:
	roster_changed.emit()
	if is_networked() and is_host():
		_send("_sync_roster", [players, room_code])

@rpc("authority", "call_remote", "reliable")
func _sync_roster(roster: Array, code: String) -> void:
	players.assign(roster)
	room_code = code
	var was_joining := phase == "joining"
	var own_registered := not member(local_id()).is_empty()
	if was_joining and own_registered:
		phase = "waiting"
		join_deadline = 0.0
	roster_changed.emit()
	if was_joining and own_registered:
		room_joined.emit()

func set_ready(value: bool) -> void:
	if is_host():
		_apply_ready(local_id(), value)
	else:
		_send("_request_ready", [value], 1)

func select_character(index: int) -> bool:
	if is_host():
		return _apply_character(local_id(), index)
	if phase != "waiting" or index < 0 or index >= CHARACTERS.size():
		return false
	_send("_request_character", [index], 1)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _request_character(index: int) -> void:
	if is_host():
		var sender := _sender_id()
		if sender <= 1 or member(sender).is_empty():
			return
		_send("_character_result", [index, _apply_character(sender, index)], sender)

@rpc("authority", "call_remote", "reliable")
func _character_result(index: int, accepted: bool) -> void:
	character_claim_result.emit(index, accepted)

func _apply_character(id: int, index: int) -> bool:
	var entry := member(id)
	if phase != "waiting" or entry.is_empty() or index < 0 or index >= CHARACTERS.size():
		return false
	entry.character = index
	entry.ready = false
	_publish_roster()
	return true

@rpc("any_peer", "call_remote", "reliable")
func _request_ready(value: bool) -> void:
	if is_host():
		_apply_ready(_sender_id(), value)

func _apply_ready(id: int, value: bool) -> void:
	var entry := member(id)
	if phase != "waiting" or entry.is_empty():
		return
	if value and (entry.character < 0 or entry.character >= CHARACTERS.size()):
		return
	entry.ready = value
	_publish_roster()

func all_ready() -> bool:
	if players.is_empty():
		return false
	for entry in players:
		if not entry.ready or entry.character < 0 or entry.character >= CHARACTERS.size():
			return false
	return true

func can_start() -> bool:
	return is_host() and phase == "waiting" and all_ready() and (mode == "developer" or players.size() >= 2)

func start_match() -> bool:
	if not can_start():
		return false
	if mode == "developer" and developer_role == "player":
		developer_bot_count = maxi(1, developer_bot_count)
	add_developer_bots()
	_publish_roster()
	selection_seed = randi()
	selected_map = developer_map if mode == "developer" and developer_map in range(3) else int(selection_seed % 3)
	match_id = "%s-%d-%d" % [room_code, Time.get_unix_time_from_system(), selection_seed]
	tutorial_ready.clear()
	phase = "roulette"
	if is_networked():
		_send("_begin_selection", [selected_map, selection_seed, match_id])
		if mode == "online": online.close_admission()
	_open_selection()
	return true

func add_developer_bots() -> void:
	if mode != "developer":
		return
	var available := range(CHARACTERS.size())
	for entry in players:
		available.erase(entry.character)
	for slot in range(1, developer_bot_count + 1):
		if member(-slot).is_empty():
			players.append({"id": -slot, "name": ("CPU %d" if is_vs_ai() else "Bot %d") % slot, "ready": true, "slot": slot, "character": available.pop_front(), "color": COLORS[slot], "bot": true})

@rpc("authority", "call_remote", "reliable")
func _begin_selection(map_index: int, seed_value: int, id: String) -> void:
	selected_map = map_index
	selection_seed = seed_value
	match_id = id
	tutorial_ready.clear()
	phase = "roulette"
	_open_selection()

func _open_selection() -> void:
	get_tree().change_scene_to_file.call_deferred("res://ui/map_select/map_select.tscn")

func acknowledge_tutorial() -> void:
	if is_host():
		tutorial_ready[local_id()] = true
	else:
		_send("_tutorial_ack", [], 1)

@rpc("any_peer", "call_remote", "reliable")
func _tutorial_ack() -> void:
	var sender := _sender_id()
	if is_host() and phase == "match" and not member(sender).is_empty():
		tutorial_ready[sender] = true

func humans_ready_for_match() -> bool:
	return players.all(func(entry: Dictionary) -> bool: return entry.bot or tutorial_ready.has(entry.id))

func send_input(packet: Dictionary) -> void:
	if not is_networked() or is_host(): return
	send_sequence += 1
	packet["sequence"] = send_sequence
	var pressed: bool = packet.get("throw", false)
	if pressed != outgoing_throw:
		outgoing_throw = pressed
		throw_sequence += 1
		_send("_throw_edge", [pressed, throw_sequence, int(packet.get("charge_id", 0)), clock_time(), packet.get("aim", Vector2.ZERO)], 1)
	_send("_submit_input", [packet], 1, false)

func request_skill(pressed: bool, aim: Vector2) -> void:
	if is_networked() and not is_host() and phase == "match":
		_send("_request_skill", [pressed, aim], 1)

@rpc("any_peer", "call_remote", "reliable")
func _request_skill(pressed: bool, aim: Vector2) -> void:
	var sender := _sender_id()
	if is_host() and phase == "match" and not member(sender).is_empty() and aim.is_finite():
		skill_requested.emit(sender, pressed, aim.clamp(Vector2(-10000, -10000), Vector2(10000, 10000)))

@rpc("any_peer", "call_remote", "reliable")
func _throw_edge(pressed: bool, sequence: int, charge: int, at_time: float, aim: Vector2) -> void:
	var sender := _sender_id()
	if not is_host() or member(sender).is_empty() or not phase in ["waiting", "match"] or not aim.is_finite(): return
	if sequence <= int(received_throws.get(sender, -1)): return
	received_throws[sender] = sequence
	held_throws[sender] = pressed
	throw_input_received.emit(sender, pressed, charge, at_time, aim.clamp(Vector2(-10000, -10000), Vector2(10000, 10000)))

func _request_clock() -> void:
	pending_clock = Time.get_ticks_msec() / 1000.0
	_send("_clock_ping", [pending_clock], 1)

@rpc("any_peer", "call_remote", "reliable")
func _clock_ping(sent: float) -> void:
	if is_host() and not member(_sender_id()).is_empty():
		_send("_clock_pong", [sent, clock_time()], _sender_id())

@rpc("authority", "call_remote", "reliable")
func _clock_pong(sent: float, host_time: float) -> void:
	if sent != pending_clock or not is_finite(host_time): return
	var now := Time.get_ticks_msec() / 1000.0
	var round_trip := now - sent
	if round_trip >= 0.0 and round_trip <= 2.0:
		clock_offset = host_time + round_trip * 0.5 - now
	pending_clock = -1.0

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_input(packet: Dictionary) -> void:
	var sender := _sender_id()
	if not is_host() or member(sender).is_empty() or not phase in ["waiting", "match"]:
		return
	var sequence := int(packet.get("sequence", -1))
	if sequence <= int(received_inputs.get(sender, -1)): return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_input_time.get(sender, 0.0)) < 0.006:
		return
	var move = packet.get("move")
	var aim = packet.get("aim")
	if not move is Vector2 or not aim is Vector2 or not move.is_finite() or not aim.is_finite():
		return
	var clean := {"move": move.limit_length(), "aim": aim.clamp(Vector2(-10000, -10000), Vector2(10000, 10000))}
	for key in ["sprint", "interact", "lunge", "throw"]:
		clean[key] = packet.get(key, false) == true
	clean["throw"] = held_throws.get(sender, false)
	if mode == "lan": clean["sequence"] = sequence
	received_inputs[sender] = sequence
	last_input_time[sender] = now
	input_deadline[sender] = now + 0.5
	input_received.emit(sender, clean)

func publish_world(snapshot: Dictionary) -> void:
	if is_networked() and is_host():
		world_sequence += 1
		snapshot["sequence"] = world_sequence
		var bytes := var_to_bytes(snapshot)
		_send("_world_state", [bytes.compress(FileAccess.COMPRESSION_ZSTD), bytes.size()], 0, false)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _world_state(payload: PackedByteArray, original_size: int) -> void:
	if original_size <= 0 or original_size > 65536:
		return
	var snapshot = bytes_to_var(payload.decompress(original_size, FileAccess.COMPRESSION_ZSTD))
	if snapshot is Dictionary and int(snapshot.get("sequence", -1)) > received_world:
		received_world = int(snapshot.sequence)
		world_snapshot_received.emit(snapshot)

func publish_event(event: Dictionary) -> void:
	event_sequence += 1
	event["sequence"] = event_sequence
	match_event_received.emit(event)
	if is_networked() and is_host():
		_send("_match_event", [event])

@rpc("authority", "call_remote", "reliable")
func _match_event(event: Dictionary) -> void:
	if int(event.get("sequence", -1)) <= received_event: return
	received_event = int(event.sequence)
	match_event_received.emit(event)

func finish_match(rankings: Array) -> void:
	if not is_host() or phase != "match":
		return
	results = rankings
	phase = "results"
	if is_networked():
		_send("_show_results", [rankings])
	get_tree().change_scene_to_file.call_deferred("res://ui/results/results.tscn")

@rpc("authority", "call_remote", "reliable")
func _show_results(rankings: Array) -> void:
	results = rankings
	phase = "results"
	get_tree().change_scene_to_file.call_deferred("res://ui/results/results.tscn")

func _peer_left(id: int) -> void:
	if not is_host():
		return
	players = players.filter(func(entry: Dictionary) -> bool: return entry.id != id)
	tutorial_ready.erase(id)
	input_deadline.erase(id)
	held_throws.erase(id)
	received_inputs.erase(id)
	received_throws.erase(id)
	_publish_roster()

func _failed(reason: String) -> void:
	close_room()
	connection_status_changed.emit(reason)
	room_closed.emit(reason)

func _process(_delta: float) -> void:
	if is_networked() and not is_host() and phase in ["waiting", "match"]:
		clock_tick += _delta
		if clock_tick >= 2.0:
			clock_tick = 0.0
			_request_clock()
	if join_deadline > 0.0 and Time.get_ticks_msec() / 1000.0 > join_deadline:
		_failed("Connection timed out. Check your internet connection and online code." if mode == "online" else "Could not reach %s:%d. Use the host's current IP, allow UDP %d on Private networks, and check that both PCs have the same game update." % [join_target, PORT, PORT])
	if is_host():
		var now := Time.get_ticks_msec() / 1000.0
		for id in input_deadline.keys():
			if now > input_deadline[id]:
				input_received.emit(id, {"move": Vector2.ZERO, "aim": Vector2.ZERO})
				input_deadline.erase(id)

func _lan_address() -> String:
	var addresses := IP.get_local_addresses()
	if OS.get_name() == "Windows":
		# The default route identifies the active adapter when host-only adapters are also present.
		var output: Array = []
		if OS.execute("route.exe", ["PRINT", "-4"], output) == OK:
			var best_address := ""
			var best_metric := 2147483647
			for chunk in output:
				for line in str(chunk).split("\n"):
					var fields := line.strip_edges().replace("\t", " ").split(" ", false)
					if fields.size() < 5 or fields[0] != "0.0.0.0" or fields[1] != "0.0.0.0":
						continue
					if addresses.has(fields[3]) and fields[4].is_valid_int() and int(fields[4]) < best_metric:
						best_address = fields[3]
						best_metric = int(fields[4])
			if not best_address.is_empty():
				return best_address
	for prefix in ["10.", "192.168.", "172."]:
		for address in addresses:
			if address.begins_with(prefix) and address.is_valid_ip_address() and not address.contains(":"):
				return address
	return "127.0.0.1"

func encode_address(address: String) -> String:
	var parts := address.split(".")
	if parts.size() != 4:
		return ""
	var value: int = 0
	for part in parts:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
			return ""
		value = (value << 8) | int(part)
	var code := ""
	for i in range(7):
		code = CODE_ALPHABET[value & 31] + code
		value >>= 5
	return code

func decode_code(raw: String) -> String:
	var code := raw.strip_edges().to_upper().replace("-", "")
	if code.length() != 7:
		return ""
	var value: int = 0
	for character in code:
		var digit := CODE_ALPHABET.find(character)
		if digit < 0:
			return ""
		value = (value << 5) | digit
	if value > 0xffffffff:
		return ""
	return "%d.%d.%d.%d" % [(value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, value & 255]
