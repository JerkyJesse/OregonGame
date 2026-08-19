extends Node3D

const RD := preload("res://scripts/raid_director.gd")


func _enter_tree() -> void:
	Hud.enter_gameplay()


func _ready() -> void:
	RD.begin(self, "ash_yard")


func _process(_delta: float) -> void:
	if RunState.in_raid:
		RD.update_ash_objective(self)


func spawn_loot(part: Dictionary, pos: Vector3) -> void:
	RD.spawn_loot(self, part, pos)
