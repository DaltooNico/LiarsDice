extends Node2D

# ── Dice ───────────────────────────────────────────────────────────────────────
var player_dice: Array[Die] = []
var enemy_dice:  Array[Die] = []

# ── Bet state ──────────────────────────────────────────────────────────────────
var current_bet: Dictionary = {"quantity": 0, "face": 0}
var is_player_turn: bool = true

# ── Game state machine ─────────────────────────────────────────────────────────
enum State { BETTING, ROUND_OVER, GAME_OVER }
var state: State = State.BETTING

const JOKER_FACE = 1

# ── UI references ──────────────────────────────────────────────────────────────
@onready var game_log      = $UILayer/VBox/GameLog
@onready var player_label  = $UILayer/VBox/PlayerArea/Label
@onready var enemy_label   = $UILayer/VBox/EnemyArea/Label
@onready var spin_quantity = $UILayer/VBox/BettingPanel/QuantitySpinBox
@onready var spin_face     = $UILayer/VBox/BettingPanel/FaceSpinBox
@onready var btn_bet       = $UILayer/VBox/BettingPanel/BtnBet
@onready var btn_dudo      = $UILayer/VBox/BettingPanel/BtnDudo
@onready var btn_action    = $UILayer/VBox/BettingPanel/BtnAction

func _ready() -> void:
	start_match(5, 5)

# ── Logging ────────────────────────────────────────────────────────────────────

func log_msg(msg: String) -> void:
	game_log.text += msg + "\n"

# ── Match / Round lifecycle ────────────────────────────────────────────────────

func start_match(player_count: int, enemy_count: int) -> void:
	player_dice = _create_dice(player_count)
	enemy_dice  = _create_dice(enemy_count)
	game_log.text = ""
	log_msg("=== ¡Nueva partida! ===")
	start_round()

func start_round() -> void:
	for die in player_dice:
		die.roll()
	for die in enemy_dice:
		die.roll()
	_sort_dice(player_dice)
	_sort_dice(enemy_dice)

	current_bet    = {"quantity": 0, "face": 0}
	is_player_turn = true
	_set_state(State.BETTING)

	_update_player_label()
	enemy_label.text = "Dados rival: [Ocultos] (" + str(enemy_dice.size()) + " dados)"

	log_msg("\n--- ¡Comienza la ronda! ---")
	log_msg("Tienes %d dado(s). El rival tiene %d." % [player_dice.size(), enemy_dice.size()])
	log_msg("Empiezas tú. Haz tu apuesta.")

func _create_dice(count: int) -> Array[Die]:
	var hand: Array[Die] = []
	for _i in range(count):
		hand.append(Die.new())
	return hand

func _sort_dice(dice: Array[Die]) -> void:
	dice.sort_custom(func(a: Die, b: Die) -> bool: return a.face < b.face)

# ── UI helpers ─────────────────────────────────────────────────────────────────

func _update_player_label() -> void:
	var parts: Array[String] = []
	for die in player_dice:
		parts.append(die.to_display_string())
	player_label.text = "Tus dados: [" + ", ".join(parts) + "]"

func _set_state(new_state: State) -> void:
	state = new_state
	match new_state:
		State.BETTING:
			btn_bet.disabled   = false
			# Dudo is only valid once at least one bet has been made
			btn_dudo.disabled  = (current_bet.quantity == 0)
			btn_action.visible = false
		State.ROUND_OVER:
			btn_bet.disabled   = true
			btn_dudo.disabled  = true
			btn_action.text    = "Nueva Ronda"
			btn_action.visible = true
		State.GAME_OVER:
			btn_bet.disabled   = true
			btn_dudo.disabled  = true
			btn_action.text    = "Nueva Partida"
			btn_action.visible = true

# ── Button handlers ────────────────────────────────────────────────────────────

func _on_btn_bet_pressed() -> void:
	if state != State.BETTING or not is_player_turn:
		return

	var quantity := int(spin_quantity.value)
	var face     := int(spin_face.value)

	if quantity > current_bet.quantity or (quantity == current_bet.quantity and face > current_bet.face):
		current_bet    = {"quantity": quantity, "face": face}
		is_player_turn = false
		btn_dudo.disabled = true
		log_msg("Has apostado: %d dados al %d." % [quantity, face])
		enemy_turn()
	else:
		log_msg("Apuesta inválida. Debes subir la cantidad o el valor de cara.")

func _on_btn_dudo_pressed() -> void:
	if state != State.BETTING or not is_player_turn or current_bet.quantity == 0:
		return
	log_msg("¡DUDO!")
	resolve_dudo(true)

func _on_btn_action_pressed() -> void:
	match state:
		State.ROUND_OVER: start_round()
		State.GAME_OVER:  start_match(5, 5)

# ── Enemy AI (basic) ───────────────────────────────────────────────────────────

func enemy_turn() -> void:
	log_msg("El rival está pensando...")

	var total_dice   := player_dice.size() + enemy_dice.size()
	var new_quantity := current_bet.quantity + 1
	var new_face     := current_bet.face

	# When quantity would exceed total dice on the table, calling dudo is smarter
	if new_quantity > total_dice:
		log_msg("¡El rival DUDA de tu apuesta!")
		resolve_dudo(false)  # false = enemy called dudo on player's last bet
		return

	current_bet    = {"quantity": new_quantity, "face": new_face}
	is_player_turn = true
	btn_dudo.disabled = false  # player can now dudo the enemy's bet
	log_msg("El rival apuesta: %d dados al %d." % [new_quantity, new_face])
	spin_quantity.value = new_quantity
	spin_face.value     = new_face

# ── Dudo resolution ────────────────────────────────────────────────────────────

func resolve_dudo(player_called: bool) -> void:
	# Reveal the enemy's hand
	var parts: Array[String] = []
	for die in enemy_dice:
		parts.append(die.to_display_string())
	enemy_label.text = "Dados rival: [" + ", ".join(parts) + "]"

	var bet_face       := current_bet.face
	var bet_quantity   := current_bet.quantity
	var is_joker_round := (bet_face == JOKER_FACE)
	var total_count    := 0

	for d in player_dice:
		if d.counts_as(bet_face, is_joker_round):
			total_count += 1
	for d in enemy_dice:
		if d.counts_as(bet_face, is_joker_round):
			total_count += 1

	log_msg("→ Total de %ds en mesa: %d (apuesta: %d)" % [bet_face, total_count, bet_quantity])

	var bet_was_true := total_count >= bet_quantity

	# player_called = true  → player doubted the enemy's last bet
	# player_called = false → enemy doubted the player's last bet
	var player_loses: bool
	if player_called:
		player_loses = bet_was_true   # doubt was wrong if the bet held
	else:
		player_loses = not bet_was_true  # player bluffed if bet didn't hold

	if player_loses:
		player_dice.pop_back()
		log_msg("❌ ¡Pierdes un dado! Te quedan %d." % player_dice.size())
	else:
		enemy_dice.pop_back()
		log_msg("✅ ¡El rival pierde un dado! Le quedan %d." % enemy_dice.size())

	# Check end conditions
	if player_dice.is_empty():
		_end_game(false)
	elif enemy_dice.is_empty():
		_end_game(true)
	else:
		_set_state(State.ROUND_OVER)

func _end_game(player_won: bool) -> void:
	if player_won:
		log_msg("\n🏆 ¡HAS GANADO! El rival se quedó sin dados.")
	else:
		log_msg("\n💀 ¡HAS PERDIDO! Te quedaste sin dados.")
	_set_state(State.GAME_OVER)
