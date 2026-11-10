class_name Die
extends RefCounted

## Objeto físico de dado para Liar's Dice Roguelike.
## Soporta dados personalizados (Cargado, Cristal, Vampírico, Comodín y Maldito).

enum Type {
	NORMAL,   ## Dado estándar d6.
	LOADED,   ## Dado Cargado: 80% de probabilidad de sacar un 6.
	CRYSTAL,  ## Dado de Cristal: Duplica el daño al rival (pierde 2 dados), pero se rompe si te cazan el farol.
	VAMPIRIC, ## Dado Vampírico: Si aciertas al cantar Dudo, roba un dado del rival para ti.
	WILDCARD, ## Dado Comodín (Wild): Cuenta para cualquier número que se esté apostando.
	CURSED,   ## Dado Maldito: Nunca cuenta para ninguna apuesta (cara defectuosa).
}

var face: int = 1
var type: Type = Type.NORMAL

func _init(p_type: Type = Type.NORMAL) -> void:
	type = p_type

## Lanza el dado aplicando la probabilidad específica de su tipo.
func roll() -> void:
	match type:
		Type.LOADED:
			# 80% de probabilidad de cara 6, 20% aleatorio entre 1 y 5
			if randf() < 0.80:
				face = 6
			else:
				face = randi_range(1, 5)
		Type.CURSED:
			face = randi_range(1, 6) # Rueda normal pero no cuenta para apuestas
		_:
			face = randi_range(1, 6)

## Cambia el valor del dado a su cara geométrica opuesta (1<->6, 2<->5, 3<->4)
func flip_to_opposite() -> void:
	face = 7 - face

## Determina si este dado apoya la apuesta actual.
func counts_as(target_face: int, is_joker_round: bool) -> bool:
	if type == Type.CURSED:
		return false # El dado maldito jamás apoya ninguna apuesta
	if type == Type.WILDCARD:
		return true # Comodín puro: cuenta para cualquier cara sin excepción
	if face == 1 and not is_joker_round:
		return true # Regla tradicional de comodines en caras 1
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
		Type.CURSED:   return "X"
		_:             return ""
