class_name RelicManager
extends RefCounted

## Gestor de Reliquias: administra las pasivas que rompen las reglas de la mesa.

const RelicClass = preload("res://Relic.gd")

var active_relics: Array = []

## Catálogo oficial de reliquias
static func get_all_available_relics() -> Array:
	var list: Array = []
	
	# 1. Monóculo de Rayos X
	list.append(RelicClass.new(
		"xray_monocle",
		"Monóculo de Rayos X",
		"Permite ver permanentemente 1 dado al azar del cubilete rival antes de empezar cada ronda.",
		6,
		"🧐"
	))

	# 2. Espejo Oculto
	list.append(RelicClass.new(
		"hidden_mirror",
		"Espejo Oculto",
		"Permite relanzar en secreto 1 de tus propios dados una vez por turno de apuestas.",
		7,
		"🪞"
	))

	# 3. Póliza de Seguro
	list.append(RelicClass.new(
		"insurance_policy",
		"Póliza de Seguro",
		"Si pierdes un dado por fallar al cantar Dudo o que te cacen, recibes +5 🪙 para la tienda.",
		5,
		"📜"
	))

	# 4. Báscula Trucada
	list.append(RelicClass.new(
		"rigged_scale",
		"Báscula Trucada",
		"Obliga a los rivales a incrementar la apuesta en al menos +2 dados en lugar de +1.",
		8,
		"⚖️"
	))

	return list

func add_relic(relic) -> void:
	active_relics.append(relic)

func has_relic(relic_id: String) -> bool:
	for r in active_relics:
		if r.id == relic_id:
			return true
	return false

# ── Hooks ──────────────────────────────────────────────────────────────────────

func trigger_round_start(context: Dictionary) -> void:
	for r in active_relics:
		r.on_round_start(context)

func apply_dice_count_modifiers(bet_face: int, is_joker_round: bool, current_count: int, player_called: bool) -> int:
	var bonus: int = 0
	for r in active_relics:
		bonus += r.modify_dice_count(bet_face, is_joker_round, current_count, player_called)
	return bonus

func trigger_dudo_resolved(won_dudo: bool, context: Dictionary) -> void:
	for r in active_relics:
		r.on_dudo_resolved(won_dudo, context)
