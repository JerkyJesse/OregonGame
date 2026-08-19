class_name PartData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var slot: String = "chest"
@export_range(0.0, 1.0) var condition: float = 1.0
@export var rarity: String = "common"
@export var scales: PackedStringArray = PackedStringArray(["light", "medium"])
@export var weight: float = 4.0
@export var volume: float = 1.0
@export var heat_gen: float = 0.0
@export var power_draw: float = 0.0
@export var power_output: float = 0.0
@export var durability: float = 80.0
@export var damage: float = 0.0
@export var value: int = 40
@export var is_weapon: bool = false
@export var weapon_kind: String = ""
@export var faction_tag: String = "scav"
@export var albedo: Color = Color(0.7, 0.7, 0.7)
@export var is_payload: bool = false


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"slot": slot,
		"condition": condition,
		"rarity": rarity,
		"scales": Array(scales),
		"weight": weight,
		"volume": volume,
		"heat_gen": heat_gen,
		"power_draw": power_draw,
		"power_output": power_output,
		"durability": durability,
		"damage": damage,
		"value": value,
		"is_weapon": is_weapon,
		"weapon_kind": weapon_kind,
		"faction_tag": faction_tag,
		"albedo": [albedo.r, albedo.g, albedo.b],
		"is_payload": is_payload,
		"paint_id": "",
		"uid": "",
	}
