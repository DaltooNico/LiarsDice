class_name Die
extends RefCounted

## Represents a single physical die in the game.
## Encapsulates its type, current face value, and roll behavior.
## Future die types (Crystal, Vampiric, etc.) extend this by overriding
## [method roll] and [method counts_as].

enum Type {
	NORMAL,   ## Standard d6.
	LOADED,   ## Biased toward high values: rolls twice, keeps the max.
	CRYSTAL,  ## Transparent — face is auto-revealed to both players (future).
	VAMPIRIC, ## Counts double when it matches the bet face (future).
	WILDCARD, ## Always counts for any face, bypassing the joker-1 rule.
}

var face: int = 1
var type: Type = Type.NORMAL

func _init(p_type: Type = Type.NORMAL) -> void:
	type = p_type

## Roll this die, applying any type-specific behavior.
func roll() -> void:
	match type:
		Type.LOADED:
			# Roll twice, keep the higher result (biased toward high faces)
			face = max(randi() % 6 + 1, randi() % 6 + 1)
		_:
			face = randi() % 6 + 1

## Returns true if this die counts toward [param target_face] in the current
## bet context. This is the main hook for custom die behavior.
func counts_as(target_face: int, is_joker_round: bool) -> bool:
	# WILDCARD type dice always count for every face
	if type == Type.WILDCARD:
		return true
	# Standard joker rule: a 1 counts as any face unless it's a joker bet
	if face == 1 and not is_joker_round:
		return true
	return face == target_face

## Short display string: "4" for a normal die, "[L6]" for a Loaded die, etc.
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
