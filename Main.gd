extends Node2D

const EnemyAI = preload("res://EnemyAI.gd")
const DiceFace = preload("res://DiceFace.gd")

# ── Modelos de datos ───────────────────────────────────────────────────────────
var player_dice: Array[Die] = []
var enemy_dice:  Array[Die] = []

var player_dice_views: Array[DiceFace] = []
var enemy_dice_views:  Array[DiceFace] = []

# ── Estado de la mesa ──────────────────────────────────────────────────────────
var current_bet: Dictionary = {"quantity": 0, "face": 0}
var is_player_turn: bool = true
var is_thinking: bool = false

enum State { BETTING, ROUND_OVER, GAME_OVER }
var state: State = State.BETTING

const JOKER_FACE = 1
const FACE_SYMBOLS = ["", "⚀ (1)", "⚁ (2)", "⚂ (3)", "⚃ (4)", "⚄ (5)", "⚅ (6)"]

# ── Inteligencia Artificial del Rival ──────────────────────────────────────────
var enemy_ai: EnemyAI

# ── Registro de log en memoria ────────────────────────────────────────────────
var _log_buffer: String = ""

# ── Referencias UI ─────────────────────────────────────────────────────────────
@onready var game_log        : RichTextLabel = $UILayer/Margin/Layout/RightLogArea/LogPanel/Margin/VBox/GameLog
@onready var enemy_title     : Label         = $UILayer/Margin/Layout/LeftPlayArea/EnemyPanel/Margin/VBox/Header/EnemyTitle
@onready var enemy_count_lbl : Label         = $UILayer/Margin/Layout/LeftPlayArea/EnemyPanel/Margin/VBox/Header/EnemyCount
@onready var enemy_dice_row  : HBoxContainer = $UILayer/Margin/Layout/LeftPlayArea/EnemyPanel/Margin/VBox/EnemyDiceRow

@onready var bet_value_lbl   : RichTextLabel = $UILayer/Margin/Layout/LeftPlayArea/BetPanel/Margin/VBox/BetValue
@onready var turn_status_lbl : Label         = $UILayer/Margin/Layout/LeftPlayArea/BetPanel/Margin/VBox/TurnStatus

@onready var player_title    : Label         = $UILayer/Margin/Layout/LeftPlayArea/PlayerPanel/Margin/VBox/Header/PlayerTitle
@onready var player_count_lbl: Label         = $UILayer/Margin/Layout/LeftPlayArea/PlayerPanel/Margin/VBox/Header/PlayerCount
@onready var player_dice_row : HBoxContainer = $UILayer/Margin/Layout/LeftPlayArea/PlayerPanel/Margin/VBox/PlayerDiceRow

@onready var spin_quantity   : SpinBox       = $UILayer/Margin/Layout/LeftPlayArea/ControlsPanel/Margin/ControlsHBox/QuantitySpinBox
@onready var spin_face       : SpinBox       = $UILayer/Margin/Layout/LeftPlayArea/ControlsPanel/Margin/ControlsHBox/FaceSpinBox
@onready var btn_bet         : Button        = $UILayer/Margin/Layout/LeftPlayArea/ControlsPanel/Margin/ControlsHBox/BtnBet
@onready var btn_dudo        : Button        = $UILayer/Margin/Layout/LeftPlayArea/ControlsPanel/Margin/ControlsHBox/BtnDudo
@onready var btn_action      : Button        = $UILayer/Margin/Layout/LeftPlayArea/ControlsPanel/Margin/ControlsHBox/BtnAction

func _ready() -> void:
	# Inicializar rival con personalidad de tahúr
	enemy_ai = EnemyAI.new(EnemyAI.Personality.BLUFFER, "Jack 'Ojo de Cristal' [Farolero]")
	enemy_title.text = "RIVAL: " + enemy_ai.boss_name
	start_match(5, 5)

# ── Sistema de Log enriquecido con BBCode ──────────────────────────────────────

func log_msg(bbcode_text: String) -> void:
	_log_buffer += bbcode_text + "\n"
	game_log.text = _log_buffer

func _clear_log() -> void:
	_log_buffer = ""
	game_log.text = ""

# ── Ciclo de Vida: Partida y Ronda ─────────────────────────────────────────────

func start_match(player_count: int, enemy_count: int) -> void:
	player_dice = _create_dice(player_count)
	enemy_dice  = _create_dice(enemy_count)
	_clear_log()
	log_msg("[b][color=#f5d76e]═══ NUEVA PARTIDA DE LIAR'S DICE ═══[/color][/b]")
	log_msg("[color=#aaaaaa]El primero en quedarse sin dados en la mesa pierde.[/color]")
	start_round()

func start_round() -> void:
	is_thinking = false
	
	# Tirar dados físicos de ambos jugadores
	for die: Die in player_dice:
		die.roll()
	for die: Die in enemy_dice:
		die.roll()
		
	_sort_dice(player_dice)
	_sort_dice(enemy_dice)

	current_bet    = {"quantity": 0, "face": 0}
	is_player_turn = true
	_set_state(State.BETTING)

	_render_dice_views()
	_update_bet_display()
	_reset_spinboxes_for_turn()

	log_msg("\n[b][color=#70c080]─── Inicio de la Ronda ───[/color][/b]")
	log_msg("Mesa: Tienes [b]%d[/b] dados. El rival tiene [b]%d[/b]." % [player_dice.size(), enemy_dice.size()])
	log_msg("[color=#e0e0e0]Empiezas tú. Haz tu apuesta o subida.[/color]")

func _create_dice(count: int) -> Array[Die]:
	var hand: Array[Die] = []
	for _i in range(count):
		hand.append(Die.new())
	return hand

func _sort_dice(dice: Array[Die]) -> void:
	dice.sort_custom(func(a, b): return a.face < b.face)

# ── Renderizado y Animación de Dados Visuales ──────────────────────────────────

func _clear_dice_container(container: HBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()

func _render_dice_views() -> void:
	# 1. Limpiar filas de la mesa
	_clear_dice_container(player_dice_row)
	_clear_dice_container(enemy_dice_row)
	player_dice_views.clear()
	enemy_dice_views.clear()

	# 2. Instanciar dados del jugador (visibles y animados)
	for i in range(player_dice.size()):
		var die: Die = player_dice[i]
		var view := DiceFace.new(die.face, die.type, false)
		player_dice_row.add_child(view)
		player_dice_views.append(view)
		view.play_roll_anim(float(i) * 0.05)

	# 3. Instanciar dados del rival (boca abajo y secretos)
	for i in range(enemy_dice.size()):
		var die: Die = enemy_dice[i]
		var view := DiceFace.new(die.face, die.type, true)
		enemy_dice_row.add_child(view)
		enemy_dice_views.append(view)
		view.play_roll_anim(float(i) * 0.05)

	player_count_lbl.text = "%d dados" % player_dice.size()
	enemy_count_lbl.text  = "%d dados" % enemy_dice.size()

# ── Actualización de Interfaz ──────────────────────────────────────────────────

func _update_bet_display() -> void:
	if current_bet.quantity == 0:
		bet_value_lbl.text = "[center][b][color=#f5d76e]— Sin apuesta todavía —[/color][/b][/center]"
		turn_status_lbl.text = "Tu turno para abrir la mesa"
		turn_status_lbl.modulate = Color(0.6, 0.9, 0.6)
	else:
		var face_name: String = FACE_SYMBOLS[current_bet.face] if current_bet.face < FACE_SYMBOLS.size() else str(current_bet.face)
		bet_value_lbl.text = "[center][font_size=20][b][color=#ffffff]%d[/color][/b] dados de cara [b][color=#f5d76e]%s[/color][/b][/font_size][/center]" % [
			current_bet.quantity,
			face_name
		]
		if is_player_turn:
			turn_status_lbl.text = "¡Es tu turno! Sube la apuesta o canta Dudo"
			turn_status_lbl.modulate = Color(0.6, 0.9, 0.6)
		else:
			turn_status_lbl.text = "Turno del rival... evaluando mesa"
			turn_status_lbl.modulate = Color(0.9, 0.7, 0.5)

func _reset_spinboxes_for_turn() -> void:
	if current_bet.quantity == 0:
		spin_quantity.min_value = 1
		spin_quantity.value = 1
		spin_face.min_value = 2
		spin_face.value = 2
	else:
		# Sugerir siguiente apuesta válida automática
		if current_bet.face < 6:
			spin_quantity.value = current_bet.quantity
			spin_face.value = current_bet.face + 1
		else:
			spin_quantity.value = current_bet.quantity + 1
			spin_face.value = 2

func _set_state(new_state: State) -> void:
	state = new_state
	match new_state:
		State.BETTING:
			btn_bet.disabled   = (not is_player_turn) or is_thinking
			btn_dudo.disabled  = (current_bet.quantity == 0) or (not is_player_turn) or is_thinking
			btn_action.visible = false
			spin_quantity.editable = is_player_turn and not is_thinking
			spin_face.editable     = is_player_turn and not is_thinking
		State.ROUND_OVER:
			btn_bet.disabled   = true
			btn_dudo.disabled  = true
			btn_action.text    = "Siguiente Ronda"
			btn_action.visible = true
			spin_quantity.editable = false
			spin_face.editable     = false
		State.GAME_OVER:
			btn_bet.disabled   = true
			btn_dudo.disabled  = true
			btn_action.text    = "Revancha (Nueva Partida)"
			btn_action.visible = true
			spin_quantity.editable = false
			spin_face.editable     = false

# ── Interacción del Jugador ────────────────────────────────────────────────────

func _on_btn_bet_pressed() -> void:
	if state != State.BETTING or not is_player_turn or is_thinking:
		return

	var quantity := int(spin_quantity.value)
	var face     := int(spin_face.value)

	# Validación de subida estricta de Liar's Dice
	var is_valid: bool = false
	if current_bet.quantity == 0:
		is_valid = (quantity >= 1 and face >= 1 and face <= 6)
	elif quantity > current_bet.quantity:
		is_valid = true
	elif quantity == current_bet.quantity and face > current_bet.face:
		is_valid = true

	if is_valid:
		current_bet = {"quantity": quantity, "face": face}
		is_player_turn = false
		_set_state(State.BETTING)
		_update_bet_display()

		var f_str: String = FACE_SYMBOLS[face]
		log_msg("👤 [b]Has apostado:[/b] [color=#9ae6b4]%d al %s[/color]" % [quantity, f_str])
		
		# Iniciar turno del enemigo con retardo para suspense
		_start_enemy_turn_with_delay()
	else:
		log_msg("[color=#fc8181]⚠ Apuesta inválida. Sube la cantidad o la cara del dado.[/color]")

func _on_btn_dudo_pressed() -> void:
	if state != State.BETTING or not is_player_turn or current_bet.quantity == 0 or is_thinking:
		return

	log_msg("\n[b][color=#f56565]¡HAS CANTADO DUDO! Levantando cubiletes...[/color][/b]")
	resolve_dudo(true)

func _on_btn_action_pressed() -> void:
	match state:
		State.ROUND_OVER:
			start_round()
		State.GAME_OVER:
			start_match(5, 5)

# ── Turno del Enemigo (IA) ─────────────────────────────────────────────────────

func _start_enemy_turn_with_delay() -> void:
	is_thinking = true
	_set_state(State.BETTING)
	log_msg("[color=#aaaaaa]El rival está calculando probabilidades...[/color]")

	if is_inside_tree():
		var timer := get_tree().create_timer(1.2)
		await timer.timeout
	
	if state != State.BETTING:
		return
		
	is_thinking = false
	_process_enemy_turn()

func _process_enemy_turn() -> void:
	var decision: Dictionary = enemy_ai.decide_action(
		enemy_dice,
		player_dice.size(),
		current_bet,
		JOKER_FACE
	)

	if decision.get("action") == "dudo":
		log_msg("\n[b][color=#e53e3e]¡EL RIVAL CANTA DUDO SOBRE TU APUESTA![/color][/b]")
		resolve_dudo(false)
	else:
		var q: int = decision.get("quantity", current_bet.quantity + 1)
		var f: int = decision.get("face", current_bet.face)
		current_bet = {"quantity": q, "face": f}
		is_player_turn = true
		_set_state(State.BETTING)
		_update_bet_display()
		_reset_spinboxes_for_turn()

		var f_str: String = FACE_SYMBOLS[f]
		log_msg("🤖 [b]Rival sube a:[/b] [color=#fbd38d]%d dados al %s[/color]" % [q, f_str])

# ── Resolución de Farol (Dudo) ─────────────────────────────────────────────────

func resolve_dudo(player_called: bool) -> void:
	is_thinking = true
	_set_state(State.ROUND_OVER)
	btn_action.visible = false # Se activará tras completar las animaciones

	var bet_face       : int  = current_bet.face
	var bet_quantity   : int  = current_bet.quantity
	var is_joker_round : bool = (bet_face == JOKER_FACE)

	# 1. Revelar dados del enemigo con efecto flip 3D secuencial
	for i in range(enemy_dice_views.size()):
		var view: DiceFace = enemy_dice_views[i]
		view.play_reveal_anim(float(i) * 0.12)

	# Esperar a que terminen de voltearse los dados
	if is_inside_tree():
		var reveal_time: float = float(enemy_dice_views.size()) * 0.12 + 0.35
		await get_tree().create_timer(reveal_time).timeout

	# 2. Contar dados válidos y resaltarlos en pantalla
	var total_count: int = 0
	var f_str: String = FACE_SYMBOLS[bet_face]

	for i in range(player_dice.size()):
		var d: Die = player_dice[i]
		if d.counts_as(bet_face, is_joker_round):
			total_count += 1
			player_dice_views[i].is_highlighted = true

	for i in range(enemy_dice.size()):
		var d: Die = enemy_dice[i]
		if d.counts_as(bet_face, is_joker_round):
			total_count += 1
			enemy_dice_views[i].is_highlighted = true

	log_msg("───────────────────────────────────────")
	log_msg("🔍 [b]Resultado en la mesa:[/b] Hay [b][color=#f6e05e]%d[/color][/b] dado(s) de cara %s (Apuesta: [b]%d[/b])." % [
		total_count, f_str, bet_quantity
	])
	if not is_joker_round:
		log_msg("[color=#a0aec0]  *(Las caras 1 son comodines y suman a cualquier apuesta)*[/color]")

	var bet_was_true: bool = (total_count >= bet_quantity)
	var player_loses: bool

	if player_called:
		# El jugador dudó de la apuesta del rival
		player_loses = bet_was_true
		if bet_was_true:
			log_msg("[color=#fc8181]❌ La apuesta del rival era real. ¡Tu duda fue errónea![/color]")
		else:
			log_msg("[color=#68d391]🎯 ¡Cazaste el farol del rival! La apuesta era falsa.[/color]")
	else:
		# El rival dudó de la apuesta del jugador
		player_loses = not bet_was_true
		if player_loses:
			log_msg("[color=#fc8181]❌ ¡Te cazaron el farol! No había suficientes dados.[/color]")
		else:
			log_msg("[color=#68d391]🎯 ¡Tu apuesta era legítima! El rival dudó equivocadamente.[/color]")

	# 3. Eliminar dado del perdedor con animación
	if is_inside_tree():
		await get_tree().create_timer(0.6).timeout

	if player_loses:
		player_dice.pop_back()
		if not player_dice_views.is_empty():
			var dying_view: DiceFace = player_dice_views.pop_back()
			dying_view.play_vanish_anim()
		log_msg("[b][color=#e53e3e]💀 ¡Pierdes 1 dado![/color][/b] Te quedan: %d." % player_dice.size())
	else:
		enemy_dice.pop_back()
		if not enemy_dice_views.is_empty():
			var dying_view: DiceFace = enemy_dice_views.pop_back()
			dying_view.play_vanish_anim()
		log_msg("[b][color=#48bb78]💥 ¡El rival pierde 1 dado![/color][/b] Le quedan: %d." % enemy_dice.size())

	player_count_lbl.text = "%d dados" % player_dice.size()
	enemy_count_lbl.text  = "%d dados" % enemy_dice.size()

	# 4. Comprobar fin de partida o siguiente ronda
	if is_inside_tree():
		await get_tree().create_timer(0.5).timeout
	is_thinking = false

	if player_dice.is_empty():
		_end_game(false)
	elif enemy_dice.is_empty():
		_end_game(true)
	else:
		_set_state(State.ROUND_OVER)

func _end_game(player_won: bool) -> void:
	log_msg("═══════════════════════════════════════")
	if player_won:
		log_msg("[b][color=#f6e05e]🏆 ¡VICTORIA TOTAL! Has derrotado a %s.[/color][/b]" % enemy_ai.boss_name)
		log_msg("[color=#68d391]El rival se quedó sin dados en la mesa.[/color]")
	else:
		log_msg("[b][color=#e53e3e]💀 DERROTA. Te quedaste sin dados.[/color][/b]")
		log_msg("[color=#fc8181]Mejor suerte en la próxima mano, tahúr.[/color]")
	_set_state(State.GAME_OVER)
