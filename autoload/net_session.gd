extends Node

const PORT := 7777
const MAX_PLAYERS := 8
const MAX_ADDR_LEN := 253
const ALLOWED_RAID_PATHS := [
	"res://scenes/raid.tscn",
	"res://scenes/pipeline.tscn",
]
const ALLOWED_MAPS := ["ash_yard", "pipeline"]
const ALLOWED_MODES := ["combat", "scav_wave", "late_drop"]

signal session_changed
signal peer_ready(id: int)

var peer: ENetMultiplayerPeer
var late_join: bool = false
var wanted_scale: String = "scavenger"
var raid_path: String = ""
var last_error: String = ""
## Stored for reconnect only — never shown on screen.
var join_address: String = ""


var _rx_ipv4: RegEx
var _rx_ipv6: RegEx


func _ready() -> void:
	_ensure_scrub_rx()
	multiplayer.peer_connected.connect(_on_peer_in)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	multiplayer.server_disconnected.connect(_on_server_gone)


func is_online() -> bool:
	return peer != null and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	if not is_online():
		return true
	return multiplayer.is_server()


func local_id() -> int:
	if not is_online():
		return 1
	return multiplayer.get_unique_id()


func host_game() -> Error:
	_drop()
	last_error = ""
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		last_error = scrub_visible("Could not host on port %d (%s). Close the other instance or wait a few seconds." % [PORT, error_string(err)])
		peer = null
		session_changed.emit()
		return err
	multiplayer.multiplayer_peer = peer
	late_join = false
	session_changed.emit()
	print("HOST_BIND status=", peer.get_connection_status(), " id=", multiplayer.get_unique_id())
	return OK


func join_game(address: String) -> Error:
	_drop()
	last_error = ""
	var target := sanitize_join_address(address)
	# Empty field → silent loopback for local smoke joins. Never shown in UI.
	if target == "":
		if address.strip_edges() == "":
			target = "127.0.0.1"
		else:
			last_error = "Join field looks invalid. Hostname only — no port."
			session_changed.emit()
			return ERR_INVALID_PARAMETER
	join_address = target
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(target, PORT)
	if err != OK:
		last_error = scrub_visible("Could not reach host on port %d (%s)." % [PORT, error_string(err)])
		join_address = ""
		peer = null
		session_changed.emit()
		return err
	multiplayer.multiplayer_peer = peer
	late_join = true
	wanted_scale = "scavenger"
	RunState.deploy_scale = "scavenger"
	RunState.raid_mode = "late_drop"
	session_changed.emit()
	return OK


func join_and_wait(address: String) -> Error:
	var err := join_game(address)
	if err != OK:
		return err
	for _i in 600:
		await get_tree().process_frame
		if not is_inside_tree():
			return ERR_CANT_CONNECT
		if is_online():
			return OK
		if peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			_drop()
			last_error = "Connection refused. Host a raid first, then join from the same network."
			return ERR_CANT_CONNECT
	_drop()
	last_error = "Timed out joining host on port %d." % PORT
	return ERR_CANT_CONNECT


func start_raid(path: String) -> void:
	var safe := sanitize_raid_path(path)
	if safe == "":
		return
	raid_path = safe
	if is_online() and is_host():
		rpc_enter_raid.rpc(safe, RunState.raid_map, RunState.raid_mode, RunState.faction)
	var tree := get_tree()
	if tree:
		tree.change_scene_to_file(safe)


func scene_for_map(map_id: String) -> String:
	if map_id == "pipeline":
		return "res://scenes/pipeline.tscn"
	return "res://scenes/raid.tscn"


func in_raid_scene() -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var path := tree.current_scene.scene_file_path
	return path.ends_with("raid.tscn") or path.ends_with("pipeline.tscn")


@rpc("authority", "call_remote", "reliable")
func rpc_enter_raid(path: String, map: String, mode: String, faction: String) -> void:
	var safe_path := sanitize_raid_path(path)
	var safe_map := sanitize_map(map)
	var safe_mode := sanitize_mode(mode)
	var safe_faction := sanitize_faction(faction)
	if safe_path == "" or safe_map == "" or safe_mode == "" or safe_faction == "":
		return
	if in_raid_scene() and get_tree().current_scene.scene_file_path == safe_path:
		return
	raid_path = safe_path
	RunState.raid_map = safe_map
	RunState.faction = safe_faction
	if late_join:
		RunState.deploy_scale = "scavenger"
		RunState.raid_mode = "late_drop"
	else:
		RunState.raid_mode = safe_mode
	var tree := get_tree()
	if tree == null:
		return
	print("NET_ENTER_RAID ", safe_path, " as ", local_id())
	tree.change_scene_to_file(safe_path)


@rpc("any_peer", "reliable")
func request_raid() -> void:
	if not is_host() or raid_path == "":
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		return
	var safe_path := sanitize_raid_path(raid_path)
	if safe_path == "":
		return
	rpc_enter_raid.rpc_id(id, safe_path, RunState.raid_map, RunState.raid_mode, RunState.faction)


func disconnect_game() -> void:
	raid_path = ""
	_drop()
	session_changed.emit()


func on_local_extracted() -> void:
	if not is_online():
		return
	if is_host():
		rpc_host_extracted.rpc()
		disconnect_game()
	else:
		_drop()
		session_changed.emit()


@rpc("authority", "call_remote", "reliable")
func rpc_host_extracted() -> void:
	Hud.show_banner(WorldLore.host_extracted_banner())
	get_tree().call_group("extract_zone", "finish_if_channeling")


func _on_peer_in(id: int) -> void:
	session_changed.emit()
	if is_host() and raid_path != "":
		var safe_path := sanitize_raid_path(raid_path)
		if safe_path != "":
			rpc_enter_raid.rpc_id(id, safe_path, RunState.raid_map, RunState.raid_mode, RunState.faction)
	peer_ready.emit(id)


func _on_peer_left(id: int) -> void:
	session_changed.emit()
	var tree := get_tree()
	if tree == null:
		return
	tree.call_group("loot", "clear_pending_grant", id)
	var n := tree.current_scene
	if n and n.has_node("Scavenger_%d" % id):
		n.get_node("Scavenger_%d" % id).queue_free()


func _on_server_gone() -> void:
	_drop()
	session_changed.emit()
	if RunState.in_raid:
		RunState.fail_raid("Host left the raid.")


func _drop() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	late_join = false
	raid_path = ""
	join_address = ""


func _ensure_scrub_rx() -> void:
	if _rx_ipv4 == null:
		_rx_ipv4 = RegEx.new()
		_rx_ipv4.compile("\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b")
	if _rx_ipv6 == null:
		_rx_ipv6 = RegEx.new()
		_rx_ipv6.compile("(?i)\\b(?:[0-9a-f]{1,4}:){2,7}[0-9a-f]{0,4}\\b")


## Strip IPv4/IPv6 from any string before it hits a label, banner, or status line.
func scrub_visible(text: String) -> String:
	_ensure_scrub_rx()
	var out := text
	out = _rx_ipv4.sub(out, "[hidden]", true)
	out = _rx_ipv6.sub(out, "[hidden]", true)
	return out


func status_text() -> String:
	if not is_online():
		return "OFFLINE"
	if is_host():
		return "HOST  :%d  %d/%d" % [PORT, multiplayer.get_peers().size() + 1, MAX_PLAYERS]
	return "CLIENT  :%d  id %d" % [PORT, multiplayer.get_unique_id()]


func sanitize_join_address(raw: String) -> String:
	var s := raw.strip_edges()
	if s == "":
		return ""
	if s.length() > MAX_ADDR_LEN:
		return ""
	# Reject whitespace / control / URL-ish junk that should never be a host.
	for i in s.length():
		var c := s.unicode_at(i)
		if c <= 32 or c == 127:
			return ""
	if s.find("/") >= 0 or s.find("\\") >= 0 or s.find("@") >= 0 or s.find("?") >= 0 or s.find("#") >= 0:
		return ""
	# Strip accidental port suffix — we always use PORT.
	if s.begins_with("[") and s.find("]") > 0:
		s = s.substr(1, s.find("]") - 1)
	elif s.count(":") == 1 and not s.begins_with(":"):
		var host_only := s.get_slice(":", 0)
		if host_only.is_valid_ip_address() or _looks_like_hostname(host_only):
			s = host_only
	if s.is_valid_ip_address():
		return s
	if _looks_like_hostname(s):
		return s.to_lower()
	return ""


func _looks_like_hostname(s: String) -> bool:
	if s.length() < 1 or s.length() > MAX_ADDR_LEN:
		return false
	if s.begins_with("-") or s.ends_with("-") or s.begins_with(".") or s.ends_with("."):
		return false
	for i in s.length():
		var ch := s[i]
		var ok := (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "-" or ch == "."
		if not ok:
			return false
	return true


func sanitize_raid_path(path: String) -> String:
	var p := path.strip_edges()
	if p in ALLOWED_RAID_PATHS:
		return p
	return ""


func sanitize_map(map_id: String) -> String:
	var m := map_id.strip_edges()
	if m in ALLOWED_MAPS:
		return m
	return ""


func sanitize_mode(mode: String) -> String:
	var m := mode.strip_edges()
	if m in ALLOWED_MODES:
		return m
	return ""


func sanitize_faction(faction: String) -> String:
	var f := faction.strip_edges()
	if f in RunState.FACTIONS:
		return f
	return ""


func sanity_loot(part: Dictionary) -> bool:
	if part.is_empty() or str(part.get("id", "")) == "":
		return false
	var id := str(part.get("id", ""))
	if id not in RunState.catalog_ids():
		return false
	var w := float(part.get("weight", 0.0))
	if w < 0.0 or w >= 400.0:
		return false
	var value := float(part.get("value", 0.0))
	if value < 0.0 or value > 100000.0:
		return false
	var cond := float(part.get("condition", 1.0))
	if cond < 0.0 or cond > 1.0:
		return false
	return true


## Compat alias — getter stays empty so leftover UI cannot print a host/IP.
var join_ip: String:
	get:
		return ""
	set(v):
		join_address = sanitize_join_address(str(v))
