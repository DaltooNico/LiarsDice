class_name Die
extends RefCounted

## Objeto físico de dado para Liar's Dice Roguelike.
## Soporta tipos especiales (Cargado, Cristal, Vampírico, Comodín).

enum Type {
	NORMAL,   ## Dado estándar d6.
	LOADED,   ## Sesgado a valores altos: tira 2 veces y guarda el mayor.
	CRYSTAL,  ## Cristal: visible para todos, otorga +3 oro al ganar la mano.
	VAMPIRIC, ## Vampírico: si puntúa en una mano ganada, recupera 1 dado perdido.
	WILDCARD, ## Comodín: siempre cuenta como cualquier cara.
}

var face: int = 1
var type: Type = Type.NORMAL

func _init(p_type: Type = Type.NORMAL) -> void:
	type = p_type

## Lanza el dado aplicando la lógica específica de su tipo.
func roll() -> void:
	match type:
		Type.LOADED:
			face = maxi(randi() % 6 + 1, randi() % 6 + 1)
		_:
			face = randi() % 6 + 1

## Determina si este dado cuenta para la cara apostada.
func counts_as(target_face: int, is_joker_round: bool) -> bool:
	if type == Type.WILDCARD:
		return true
	if face == 1 and not is_joker_round:
		return true
	return face == target_face

func to_display_string() -> String:
	var prefix := _type_prefix()
	return ("[" + prefix + str(face) + "]") if not prefix.is_empty() else str(face)

func _type_prefix() -> String:
	match type:
		Type.LOADED:   return "L"
		Type.CRYSTAL:  return "C"
		Type.VAMPIRIC: return "V"
		Type.WILDCARD: return "W"
		_:             return ""
