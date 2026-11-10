class_name EnemyAI
extends RefCounted

## Motor de Inteligencia Artificial para Rivales de Liar's Dice.
## Modela perfiles de personalidad (Cauteloso, Agresivo, Farolero, Jefe Tramposo)
## calculando probabilidades estadísticas reales de los dados ocultos.

enum Personality {
	CAUTIOUS,   ## Juega sobre seguro. Canta Dudo pronto si la apuesta excede lo probable.
	AGGRESSIVE, ## Sube las apuestas con fuerza para intimidar al jugador.
	BLUFFER,    ## Farolea frecuentemente apostando a caras de las que tiene pocos o ningun dado.
	CHEATER_BOSS## Jefe tramposo: tiene intuición sobrenatural (percibe dados del jugador).
}

var personality: Personality = Personality.CAUTIOUS
var boss_name: String = "Tahúr Novato"

func _init(p_personality: Personality = Personality.CAUTIOUS, p_name: String = "Rival") -> void:
	personality = p_personality
	boss_name = p_name

## Decide la siguiente acción del rival.
## Retorna un diccionario:
##   {"action": "dudo"}  o  {"action": "bet", "quantity": int, "face": int}
func decide_action(
	enemy_dice: Array[Die],
	player_dice_count: int,
	current_bet: Dictionary,
	joker_face: int = 1,
	min_raise_step: int = 1,
	is_ordago: bool = false
) -> Dictionary:
	# Si el jugador lanzó un Órdago (All-In), el rival está obligado a responder únicamente con Dudo
	if is_ordago:
		return {"action": "dudo"}

	var my_dice_count: int = enemy_dice.size()
	var total_dice: int = my_dice_count + player_dice_count
	var cur_q: int = current_bet.quantity
	var cur_f: int = current_bet.face

	# Si es la primera jugada de la ronda (nadie ha apostado)
	if cur_q == 0:
		return _make_initial_bet(enemy_dice, total_dice, joker_face)

	# Si la apuesta actual ya supera el total físico de dados en la mesa: Dudo inmediato
	if cur_q > total_dice:
		return {"action": "dudo"}

	# 1. Contar cuántos dados propios apoyan la apuesta actual
	var is_joker_round: bool = (cur_f == joker_face)
	var my_matches: int = 0
	for d: Die in enemy_dice:
		if d.counts_as(cur_f, is_joker_round):
			my_matches += 1

	# 2. Esperanza matemática sobre los dados ocultos del jugador
	var p: float = (1.0 / 6.0) if is_joker_round else (2.0 / 6.0)
	var expected_player_matches: float = float(player_dice_count) * p
	var expected_total_table: float = float(my_matches) + expected_player_matches

	# 3. Evaluar umbral de duda según la personalidad
	var doubt_threshold: float = 0.0
	match personality:
		Personality.CAUTIOUS:
			doubt_threshold = expected_total_table + 0.6
		Personality.AGGRESSIVE:
			doubt_threshold = expected_total_table + 1.8
		Personality.BLUFFER:
			doubt_threshold = expected_total_table + randf_range(0.4, 2.2)
		Personality.CHEATER_BOSS:
			doubt_threshold = expected_total_table + 0.95

	if float(cur_q) > doubt_threshold:
		return {"action": "dudo"}

	# 4. Decidir subida de apuesta (respetando min_raise_step si hay Báscula Trucada)
	return _make_raise(enemy_dice, total_dice, cur_q, cur_f, joker_face, min_raise_step)

func _make_initial_bet(enemy_dice: Array[Die], total_dice: int, joker_face: int) -> Dictionary:
	var counts := _count_faces(enemy_dice, joker_face)
	var best_face: int = _get_best_face(counts, joker_face)
	
	match personality:
		Personality.BLUFFER:
			if randf() < 0.35:
				var weak_face: int = randi_range(2, 6)
				return {"action": "bet", "quantity": maxi(1, int(total_dice * 0.2)), "face": weak_face}
		Personality.AGGRESSIVE:
			var strong_q: int = maxi(1, counts.get(best_face, 1) + 1)
			return {"action": "bet", "quantity": strong_q, "face": best_face}

	var base_q: int = maxi(1, counts.get(best_face, 1))
	return {"action": "bet", "quantity": base_q, "face": best_face}

func _make_raise(
	enemy_dice: Array[Die],
	total_dice: int,
	cur_q: int,
	cur_f: int,
	joker_face: int,
	min_raise_step: int = 1
) -> Dictionary:
	var counts := _count_faces(enemy_dice, joker_face)
	var best_face: int = _get_best_face(counts, joker_face)

	# Si hay Báscula Trucada (min_raise_step >= 2), el rival está obligado a subir la cantidad
	if min_raise_step >= 2:
		var target_q: int = cur_q + min_raise_step
		if counts.get(best_face, 0) > counts.get(cur_f, 0):
			return {"action": "bet", "quantity": target_q, "face": best_face}
		else:
			return {"action": "bet", "quantity": target_q, "face": cur_f}

	# Si es Farolero, posibilidad de cambiar a una cara falsa
	if personality == Personality.BLUFFER and randf() < 0.28:
		var bluff_face: int = randi_range(2, 6)
		if bluff_face > cur_f:
			return {"action": "bet", "quantity": cur_q, "face": bluff_face}
		else:
			return {"action": "bet", "quantity": cur_q + 1, "face": bluff_face}

	# Si podemos subir la cara manteniendo la cantidad y nos favorece:
	if best_face > cur_f and counts.get(best_face, 0) >= 2:
		return {"action": "bet", "quantity": cur_q, "face": best_face}

	# Subir cantidad de la apuesta actual o cambiar a nuestra mejor cara con cantidad +1
	if counts.get(best_face, 0) > counts.get(cur_f, 0):
		return {"action": "bet", "quantity": cur_q + 1, "face": best_face}
	else:
		return {"action": "bet", "quantity": cur_q + 1, "face": cur_f}

func _count_faces(enemy_dice: Array[Die], joker_face: int) -> Dictionary:
	var counts := {}
	for face in range(1, 7):
		counts[face] = 0

	for d: Die in enemy_dice:
		counts[d.face] = counts.get(d.face, 0) + 1
		if d.face == joker_face:
			for f in range(2, 7):
				counts[f] = counts.get(f, 0) + 1
	return counts

func _get_best_face(counts: Dictionary, joker_face: int) -> int:
	var best_f: int = 2
	var max_c: int = -1
	for f in range(2, 7):
		var c: int = counts.get(f, 0)
		if c > max_c:
			max_c = c
			best_f = f
	return best_f
