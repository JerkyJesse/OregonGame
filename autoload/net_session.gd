extends Node

const PORT := 7777
const MAX_PLAYERS := 8

signal session_changed
signal peer_ready(id: int)

var peer: ENetMultiplayerPeer
var late_join: bool = false
var wanted_scale: String = "scavenger"
var raid_path: String = ""
var last_error: String = ""
var join_ip: String = "127.0.0.1"


func _ready() -> void:
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
		last_error = "Could not host on port %d (%s). Close the other instance or wait a few seconds." % [PORT, error_string(err)]
		peer = null
		session_changed.emit()
		return err
	multiplayer.multiplayer_peer = peer
	late_join = false
	session_changed.emit()
	print("HOST_BIND status=", peer.get_connection_status(), " id=", multiplayer.get_unique_id())
	return OK


func join_game(ip: String) -> Error:
	_drop()
	last_error = ""
	var target := ip.strip_edges()
	if target == "":
		target = "127.0.0.1"
	join_ip = target
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(target, PORT)
	if err != OK:
		last_error = "Could not reach %s:%d (%s)." % [target, PORT, error_string(err)]
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


func join_and_wait(ip: String) -> Error:
	var err := join_game(ip)
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
			last_error = "Connection refused. Host a raid first, then join that PC's LAN IP."
			return ERR_CANT_CONNECT
	_drop()
	last_error = "Timed out joining %s:%d." % [join_ip, PORT]
	return ERR_CANT_CONNECT


func start_raid(path: String) -> void:
	raid_path = path
	if is_online() and is_host():
		rpc_enter_raid.rpc(path, RunState.raid_map, RunState.raid_mode, RunState.faction)
	var tree := get_tree()
	if tree:
		tree.change_scene_to_file(path)


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
	if path == "" or not path.begins_with("res://"):
		return
	if in_raid_scene() and get_tree().current_scene.scene_file_path == path:
		return
	raid_path = path
	RunState.raid_map = map
	RunState.faction = faction
	if late_join:
		RunState.deploy_scale = "scavenger"
		RunState.raid_mode = "late_drop"
	else:
		RunState.raid_mode = mode
	var tree := get_tree()
	if tree == null:
		return
	print("NET_ENTER_RAID ", path, " as ", local_id())
	tree.change_scene_to_file(path)


@rpc("any_peer", "reliable")
func request_raid() -> void:
	if not is_host() or raid_path == "":
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		return
	rpc_enter_raid.rpc_id(id, raid_path, RunState.raid_map, RunState.raid_mode, RunState.faction)


func disconnect_game() -> void:
	raid_path = ""
	_drop()
	session_changed.emit()


func _on_peer_in(id: int) -> void:
	session_changed.emit()
	if is_host() and raid_path != "":
		rpc_enter_raid.rpc_id(id, raid_path, RunState.raid_map, RunState.raid_mode, RunState.faction)
	peer_ready.emit(id)


func _on_peer_left(id: int) -> void:
	session_changed.emit()
	var tree := get_tree()
	if tree == null:
		return
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


func lan_ips() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for addr in IP.get_local_addresses():
		var a := str(addr)
		if a.find(":") >= 0:
			continue
		if a.begins_with("127.") or a.begins_with("0.") or a.begins_with("169.254."):
			continue
		out.append(a)
	return out


func lan_ip_text() -> String:
	var ips := lan_ips()
	if ips.is_empty():
		return "127.0.0.1"
	return ", ".join(ips)


func status_text() -> String:
	if not is_online():
		return "OFFLINE"
	if is_host():
		return "HOST  %s:%d  %d/%d" % [lan_ip_text(), PORT, multiplayer.get_peers().size() + 1, MAX_PLAYERS]
	return "CLIENT  %s:%d  id %d" % [join_ip, PORT, multiplayer.get_unique_id()]


func sanity_loot(part: Dictionary) -> bool:
	if part.is_empty() or str(part.get("id", "")) == "":
		return false
	var w := float(part.get("weight", 0.0))
	return w >= 0.0 and w < 400.0
