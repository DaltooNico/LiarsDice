class_name Consumable
extends RefCounted

## Objeto consumible de un solo uso para sabotear al rival o salvar el turno (Trampas bajo la manga).

const SelfClass = preload("res://Consumable.gd")

var id: String = ""
var name: String = ""
var description: String = ""
var cost: int = 4
var icon_symbol: String = "🧪"

func _init(p_id: String = "", p_name: String = "", p_desc: String = "", p_cost: int = 4, p_icon: String = "🧪") -> void:
	id = p_id
	name = p_name
	description = p_desc
	cost = p_cost
	icon_symbol = p_icon

## Catálogo oficial de consumibles
static func get_catalog() -> Array:
	var list: Array = []
	
	# 1. Trago de Whisky
	list.append(SelfClass.new(
		"whiskey_shot",
		"Trago de Whisky",
		"Fuerza al oponente a re-tirar inmediatamente 2 de sus dados ocultos.",
		4,
		"🥃"
	))

	# 2. Giro de Dado
	list.append(SelfClass.new(
		"die_flip",
		"Giro de Dado",
		"Voltea uno de tus dados a su cara geométrica opuesta (1↔6, 2↔5, 3↔4).",
		5,
		"🔄"
	))

	# 3. Órdago / All-In
	list.append(SelfClass.new(
		"all_in",
		"Órdago (All-In)",
		"Lanza un órdago: obliga al rival a responder únicamente con Dudo, impidiéndole subir la apuesta.",
		6,
		"⚡"
	))
	
	return list
