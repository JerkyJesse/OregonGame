extends Node3D

const RD := preload("res://scripts/raid_director.gd")

var _loot_seq := 0
var _peer_cb: Callable


func _enter_tree() -> void:
	Hud.enter_gameplay()


func _ready() -> void:
	RD.begin(self, "pipeline")
	_peer_cb = _on_peer_ready
	if not NetSession.peer_ready.is_connected(_peer_cb):
		NetSession.peer_ready.connect(_peer_cb)
	call_deferred("_log_spawn")


func _exit_tree() -> void:
	if _peer_cb.is_valid() and NetSession.peer_ready.is_connected(_peer_cb):
		NetSession.peer_ready.disconnect(_peer_cb)


func _on_peer_ready(id: int) -> void:
	RD.spawn_proxy(self, id)


func _process(_delta: float) -> void:
	if RunState.in_raid:
		RD.update_raid_objective(self)


func spawn_loot(part: Dictionary, pos: Vector3) -> void:
	_loot_seq += 1
	var drop_name := "NetLoot_%d" % _loot_seq
	RD.spawn_loot(self, part, pos, drop_name)
	if NetSession.is_online() and NetSession.is_host():
		rpc_spawn_loot.rpc(part, pos, drop_name)


@rpc("authority", "call_remote", "reliable")
func rpc_spawn_loot(part: Dictionary, pos: Vector3, drop_name: String) -> void:
	if not NetSession.sanity_loot(part):
		return
	RD.spawn_loot(self, part, pos, drop_name)


func occupation_answer(pos: Vector3) -> void:
	RD.occupation_answer(self, pos)


func _log_spawn() -> void:
	var n := get_node_or_null(RD.player_node_name(NetSession.local_id()))
	if n is Node3D:
		print("PIPELINE_SPAWN name=%s pos=%s" % [n.name, (n as Node3D).global_position])
	else:
		print("PIPELINE_SPAWN missing local scavenger")
