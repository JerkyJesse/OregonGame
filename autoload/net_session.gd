extends Node

const PORT := 7777
const MAX_PLAYERS := 8

signal session_changed

var peer: ENetMultiplayerPeer
var late_join: bool = false
var wanted_scale: String = "scavenger"


func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_server_gone)


func is_online() -> bool:
	return peer != null and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	if not is_online():
		return true
	return multiplayer.is_server()


func host_game() -> Error:
	_drop()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	late_join = false
	if not multiplayer.peer_disconnected.is_connected(_on_peer_left):
		multiplayer.peer_disconnected.connect(_on_peer_left)
	session_changed.emit()
	return OK


func join_game(ip: String) -> Error:
	_drop()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		peer = null
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
	for _i in 360:
		await get_tree().process_frame
		if is_online():
			return OK
		if peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			_drop()
			return ERR_CANT_CONNECT
	_drop()
	return ERR_CANT_CONNECT


func disconnect_game() -> void:
	_drop()
	session_changed.emit()


func _on_peer_left(id: int) -> void:
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


func status_text() -> String:
	if not is_online():
		return "OFFLINE"
	if is_host():
		return "HOST  :%d  %d/%d" % [PORT, multiplayer.get_peers().size() + 1, MAX_PLAYERS]
	return "CLIENT  id %d" % multiplayer.get_unique_id()


func sanity_loot(part: Dictionary) -> bool:
	if part.is_empty() or str(part.get("id", "")) == "":
		return false
	var w := float(part.get("weight", 0.0))
	return w >= 0.0 and w < 400.0
