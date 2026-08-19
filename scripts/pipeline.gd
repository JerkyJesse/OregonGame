extends Node3D

const RD := preload("res://scripts/raid_director.gd")


func _enter_tree() -> void:
	Hud.enter_gameplay()


func _ready() -> void:
	RD.begin(self, "pipeline")


func spawn_loot(part: Dictionary, pos: Vector3) -> void:
	RD.spawn_loot(self, part, pos)
