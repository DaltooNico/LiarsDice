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

# ── Log buffer (RichTextLabel.text getter is unreliable for appending) ─────────
var _log_buffer: String = ""

const JOKER_FACE = 1

# ── UI references ──────────────────────────────────────────────────────────────
@onready var game_log      : RichTextLabel = $UILayer/VBox/GameLog
@onready var player_label  : Label         = $UILayer/VBox/PlayerArea/Label
@onready var enemy_label   : Label         = $UILayer/VBox/EnemyArea/Label
@onready var spin_quantity : SpinBox       = $UILayer/VBox/BettingPanel/QuantitySpinBox
@onready var spin_face     : SpinBox       = $UILayer/VBox/BettingPanel/FaceSpinBox
@onready var btn_bet       : Button        = $UILayer/VBox/BettingPanel/BtnBet
@onready var btn_dudo      : Button        = $UILayer/VBox/BettingPanel/BtnDudo
@onready var btn_action    : Button        = $UILayer/VBox/BettingPanel/BtnAction

func _ready() -> void:
	start_match(5, 5)

# ── Logging ────────────────────────────────────────────────────────────────────

func log_msg(msg: String) -> void:
	_log_buffer += msg + "\n"
	game_log.text = _log_buffer

func _clear_log() -> void:
	_log_buffer = ""
	game_log.text = ""

# ── Match / Round lifecycle ────────────────────────────────────────────────────

func start_match(player_count: int, enemy_count: int) -> void:
	player_dice = _create_dice(player_count)
	enemy_dice  = _create_dice(enemy_count)
	_clear_log()
	log_msg("=== ¡Nueva partida! ===")
	start_round()

func start_round() -> void:
	for die: Die in player_dice:
		die.roll()
	for die: Die in enemy_dice:
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
	log_msg("Empiezas tu. Haz tu apuesta.")

func _create_dice(count: int) -> Array[Die]:
	var hand: Array[Die] = []
	for _i in range(count):
		hand.append(Die.new())
	return hand

func _sort_dice(dice: Array[Die]) -> void:
	dice.sort_custom(func(a, b): return a.face < b.face)

# ── UI helpers ─────────────────────────────────────────────────────────────────

func _update_player_label() -> void:
	var parts: Array[String] = []
	for die: Die in player_dice:
		parts.append(die.to_display_string())
	player_label.text = "Tus dados: [" + ", ".join(parts) + "]"

func _set_state(new_state: State) -> void:
	state = new_state
	match new_state:
		State.BETTING:
			btn_bet.disabled   = false
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
		log_msg("Apuesta invalida. Debes subir la cantidad o el valor de cara.")

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
	log_msg("El rival esta pensando...")

	var total_dice   : int = player_dice.size() + enemy_dice.size()
	var new_quantity : int = current_bet.quantity + 1
	var new_face     : int = current_bet.face

	if new_quantity > total_dice:
		log_msg("¡El rival DUDA de tu apuesta!")
		resolve_dudo(false)
		return

	current_bet    = {"quantity": new_quantity, "face": new_face}
	is_player_turn = true
	btn_dudo.disabled = false
	log_msg("El rival apuesta: %d dados al %d." % [new_quantity, new_face])
	spin_quantity.value = new_quantity
	spin_face.value     = new_face

# ── Dudo resolution ────────────────────────────────────────────────────────────

func resolve_dudo(player_called: bool) -> void:
	var parts: Array[String] = []
	for die: Die in enemy_dice:
		parts.append(die.to_display_string())
	enemy_label.text = "Dados rival: [" + ", ".join(parts) + "]"

	var bet_face       : int  = current_bet.face
	var bet_quantity   : int  = current_bet.quantity
	var is_joker_round : bool = (bet_face == JOKER_FACE)
	var total_count    : int  = 0

	for d: Die in player_dice:
		if d.counts_as(bet_face, is_joker_round):
			total_count += 1
	for d: Die in enemy_dice:
		if d.counts_as(bet_face, is_joker_round):
			total_count += 1

	log_msg("-> Total de %ds en mesa: %d (apuesta: %d)" % [bet_face, total_count, bet_quantity])

	var bet_was_true : bool = total_count >= bet_quantity
	var player_loses : bool

	if player_called:
		player_loses = bet_was_true
	else:
		player_loses = not bet_was_true

	if player_loses:
		player_dice.pop_back()
		log_msg("Pierdes un dado! Te quedan %d." % player_dice.size())
	else:
		enemy_dice.pop_back()
		log_msg("El rival pierde un dado! Le quedan %d." % enemy_dice.size())

	if player_dice.is_empty():
		_end_game(false)
	elif enemy_dice.is_empty():
		_end_game(true)
	else:
		_set_state(State.ROUND_OVER)

func _end_game(player_won: bool) -> void:
	if player_won:
		log_msg("\n¡HAS GANADO! El rival se quedo sin dados.")
	else:
		log_msg("\n¡HAS PERDIDO! Te quedaste sin dados.")
	_set_state(State.GAME_OVER)
