class_name Consumable
extends RefCounted

## Objeto consumible de un solo uso para sabotear al rival o salvar el turno (estilo Tarots de Balatro).

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

## Catálogo de consumibles disponibles en la tienda
static func get_catalog() -> Array:
	var list: Array = []
	
	list.append(SelfClass.new(
		"secret_reroll",
		"Cubilete Falso",
		"Relanza 1 de tus dados en secreto durante tu turno.",
		4,
		"🔄"
	))
	
	list.append(SelfClass.new(
		"phantom_die",
		"Dado Fantasma",
		"Añade un dado espectral invisible a la mesa que suma +1 a tu apuesta.",
		5,
		"👻"
	))
	
	list.append(SelfClass.new(
		"whiskey_shot",
		"Trago Fuerte",
		"Intimida al rival: lo fuerza a subir la cantidad obligatoriamente o dudar.",
		4,
		"🥃"
	))
	
	list.append(SelfClass.new(
		"spy_mirror",
		"Espejo de Mano",
		"Espía y revela 1 dado oculto del rival de inmediato.",
		5,
		"🔍"
	))
	
	return list
