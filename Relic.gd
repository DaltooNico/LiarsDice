class_name Relic
extends RefCounted

## Clase base para todas las Reliquias pasivas del juego (estilo Balatro).
## Interceptan y modifican los eventos clave de la partida.

var id: String = "base_relic"
var name: String = "Reliquia Base"
var description: String = "Descripción de la reliquia"
var cost: int = 5
var icon_symbol: String = "[RELIQUIA]"

func _init(p_id: String = "", p_name: String = "", p_desc: String = "", p_cost: int = 5, p_icon: String = "[RELIQUIA]") -> void:
	if not p_id.is_empty():
		id = p_id
	if not p_name.is_empty():
		name = p_name
	if not p_desc.is_empty():
		description = p_desc
	cost = p_cost
	icon_symbol = p_icon

func on_round_start(_context: Dictionary) -> void:
	pass

func modify_dice_count(_bet_face: int, _is_joker_round: bool, _current_count: int, _player_called: bool) -> int:
	return 0

func on_dudo_resolved(_won_dudo: bool, _context: Dictionary) -> void:
	pass
