class_name RelicManager
extends RefCounted

## Gestor de Reliquias: administra el inventario de pasivas del jugador
## y dispara los hooks en los momentos clave de la ronda.

const RelicClass = preload("res://Relic.gd")

var active_relics: Array = []

## Catálogo de reliquias disponibles para la tienda
static func get_all_available_relics() -> Array:
	var list: Array = []
	
	# 1. Moneda Falsa
	var r1 = RelicClass.new(
		"fake_coin",
		"Moneda Falsa",
		"Si cantas Dudo, añade +1 fantasma al conteo de dados en la mesa a tu favor.",
		6,
		"🪙"
	)
	list.append(r1)

	# 2. Lente de Cuarzo
	var r2 = RelicClass.new(
		"spy_lens",
		"Lente de Cuarzo",
		"Al empezar la ronda, revela permanentemente 1 dado al azar del rival.",
		7,
		"👁️"
	)
	list.append(r2)

	# 3. Imán de Ases
	var r3 = RelicClass.new(
		"ace_magnet",
		"Imán de Ases",
		"Los comodines (1) suman +1 extra al conteo en cualquier apuesta regular.",
		8,
		"🧲"
	)
	list.append(r3)

	# 4. Bolsa de Tahúr
	var r4 = RelicClass.new(
		"gambler_pouch",
		"Bolsa de Tahúr",
		"Ganas +4 de oro adicional cada vez que descubres un farol con éxito.",
		5,
		"💰"
	)
	list.append(r4)

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
		match r.id:
			"fake_coin":
				if player_called:
					bonus += 1
			"ace_magnet":
				if not is_joker_round:
					bonus += 1
			_:
				bonus += r.modify_dice_count(bet_face, is_joker_round, current_count, player_called)
	return bonus

func trigger_dudo_resolved(won_dudo: bool, context: Dictionary) -> void:
	for r in active_relics:
		r.on_dudo_resolved(won_dudo, context)
