extends Node2D

const EnemyAI = preload("res://EnemyAI.gd")
const DiceFace = preload("res://DiceFace.gd")
const RelicManager = preload("res://RelicManager.gd")
const RelicScript = preload("res://Relic.gd")
const ConsumableClass = preload("res://Consumable.gd")

# ── Roster de Encuentros (Estilo Balatro: 3 Rivales + 1 Jefe) ───────────────────
const ENCOUNTERS = [
	{
		"name": "Jack 'El Novato'",
		"title": "Novato del Callejón",
		"avatar": "👤 JACK",
		"personality": EnemyAI.Personality.CAUTIOUS,
		"dice_count": 4,
		"reward": 5,
		"is_boss": false,
		"desc": "Juega sobre seguro. Canta Dudo si la apuesta parece improbable."
	},
	{
		"name": "Vargas 'El Sabueso'",
		"title": "Tahúr Callejero",
		"avatar": "🐺 VARGAS",
		"personality": EnemyAI.Personality.AGGRESSIVE,
		"dice_count": 5,
		"reward": 6,
		"is_boss": false,
		"desc": "Agresivo. Sube las apuestas constantemente para intimidar."
	},
	{
		"name": "Madame Farol",
		"title": "Apostadora Ciega",
		"avatar": "🎭 MADAME",
		"personality": EnemyAI.Personality.BLUFFER,
		"dice_count": 5,
		"reward": 7,
		"is_boss": false,
		"desc": "Impredecible. Miente sobre caras que no tiene para tender trampas."
	},
	{
		"name": "👑 El Barón Tramposo",
		"title": "JEFE: El Barón Tramposo",
		"avatar": "👑 EL BARÓN",
		"personality": EnemyAI.Personality.CHEATER_BOSS,
		"dice_count": 6,
		"reward": 15,
		"is_boss": true,
		"desc": "¡JEFE! Posee 6 dados, dado comodín y castigo doble si te caza el farol."
	}
]

# ── Progreso de la Run (Roguelike) ─────────────────────────────────────────────
var current_ante: int = 1
var encounter_index: int = 0
var player_gold: int = 10
var relic_manager = null
var player_consumables: Array = [] # Máximo 2 trucos

# ── Modificadores temporales de consumibles ─────────────────────────────────────
var phantom_dice_bonus: int = 0
var force_enemy_raise: bool = false

# ── Modelos de datos de dados ──────────────────────────────────────────────────
var player_dice: Array[Die] = []
var enemy_dice:  Array[Die] = []

var player_dice_views: Array[DiceFace] = []
var enemy_dice_views:  Array[DiceFace] = []

# ── Estado de la mesa ──────────────────────────────────────────────────────────
var current_bet: Dictionary = {"quantity": 0, "face": 0}
var is_player_turn: bool = true
var is_thinking: bool = false

enum State { BETTING, ROUND_OVER, MATCH_WON, GAME_OVER, RUN_WON }
var state: State = State.BETTING

const JOKER_FACE = 1
const FACE_SYMBOLS = ["", "⚀ (1)", "⚁ (2)", "⚂ (3)", "⚃ (4)", "⚄ (5)", "⚅ (6)"]

# ── Inteligencia Artificial del Rival ──────────────────────────────────────────
var enemy_ai: EnemyAI

# ── Registro de log en memoria ────────────────────────────────────────────────
var _log_buffer: String = ""

# ── Referencias UI ─────────────────────────────────────────────────────────────
@onready var stage_label     : Label         = $UILayer/Margin/Layout/LeftPlayArea/TopBar/StagePanel/Margin/StageLabel
@onready var gold_label      : Label         = $UILayer/Margin/Layout/LeftPlayArea/TopBar/GoldLabel
@onready var relics_label    : Label         = $UILayer/Margin/Layout/LeftPlayArea/TopBar/RelicsLabel

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

# ── Panel Lateral Derecho (Panel de Control Táctico) ───────────────────────────
@onready var rival_avatar    : Label         = $UILayer/Margin/Layout/RightSideArea/RivalBox/Margin/VBox/Header/RivalAvatar
@onready var rival_mood      : Label         = $UILayer/Margin/Layout/RightSideArea/RivalBox/Margin/VBox/Header/RivalMood
@onready var rival_speech    : Label         = $UILayer/Margin/Layout/RightSideArea/RivalBox/Margin/VBox/RivalSpeech

@onready var odds_label      : Label         = $UILayer/Margin/Layout/RightSideArea/OraclePanel/Margin/VBox/OddsLabel
@onready var odds_bar        : ProgressBar   = $UILayer/Margin/Layout/RightSideArea/OraclePanel/Margin/VBox/OddsBar
@onready var odds_details    : Label         = $UILayer/Margin/Layout/RightSideArea/OraclePanel/Margin/VBox/OddsDetails

@onready var slot1_btn       : Button        = $UILayer/Margin/Layout/RightSideArea/ConsumablesPanel/Margin/VBox/SlotsHBox/Slot1Btn
@onready var slot2_btn       : Button        = $UILayer/Margin/Layout/RightSideArea/ConsumablesPanel/Margin/VBox/SlotsHBox/Slot2Btn
@onready var game_log        : RichTextLabel = $UILayer/Margin/Layout/RightSideArea/LogPanel/Margin/VBox/GameLog

# ── Tienda ─────────────────────────────────────────────────────────────────────
@onready var shop_overlay         : PanelContainer = $UILayer/ShopOverlay
@onready var next_encounter_label : Label          = $UILayer/ShopOverlay/Margin/VBox/NextEncounterLabel
@onready var btn_next_match       : Button         = $UILayer/ShopOverlay/Margin/VBox/BtnNextMatch

func _ready() -> void:
	# Conectar cambios de los spinboxes para actualizar el oráculo de probabilidad en vivo
	spin_quantity.value_changed.connect(_on_bet_inputs_changed)
	spin_face.value_changed.connect(_on_bet_inputs_changed)
	start_new_run()

func _on_bet_inputs_changed(_val: float) -> void:
	if state == State.BETTING and is_player_turn and not is_thinking:
		_update_oracle_preview(int(spin_quantity.value), int(spin_face.value))

# ── Sistema de Log enriquecido con BBCode ──────────────────────────────────────

func log_msg(bbcode_text: String) -> void:
	_log_buffer += bbcode_text + "\n"
	game_log.text = _log_buffer

func _clear_log() -> void:
	_log_buffer = ""
	game_log.text = ""

# ── Ciclo de Vida de la Run Roguelike ──────────────────────────────────────────

func start_new_run() -> void:
	current_ante = 1
	encounter_index = 0
	player_gold = 10
	relic_manager = RelicManager.new()
	player_consumables.clear()
	
	# Dar al jugador 1 truco de inicio
	player_consumables.append(ConsumableClass.new("secret_reroll", "Cubilete Falso", "Relanza 1 de tus dados en secreto.", 4, "🔄"))

	player_dice = _create_dice(5)
	
	_clear_log()
	log_msg("[b][color=#f5d76e]═══ INICIO DE RUN — ANTE %d ═══[/color][/b]" % current_ante)
	log_msg("[color=#aaaaaa]Vence a 3 rivales y al Jefe de la mesa para triunfar.[/color]")
	
	start_encounter(encounter_index)

func start_encounter(idx: int) -> void:
	shop_overlay.visible = false
	phantom_dice_bonus = 0
	force_enemy_raise = false
	
	var enc: Dictionary = ENCOUNTERS[idx]
	enemy_ai = EnemyAI.new(enc.personality, enc.name)
	enemy_title.text = "RIVAL: " + enc.title
	rival_avatar.text = enc.avatar

	# Dados del rival
	enemy_dice.clear()
	var rival_count: int = enc.dice_count
	if enc.is_boss:
		enemy_dice.append(Die.new(Die.Type.WILDCARD))
		for _i in range(rival_count - 1):
			enemy_dice.append(Die.new())
	else:
		enemy_dice = _create_dice(rival_count)

	# Restaurar reserva del jugador hasta un mínimo de 5 dados (manteniendo dados especiales)
	while player_dice.size() < 5:
		player_dice.append(Die.new())

	_update_top_bar()
	_update_consumables_ui()
	_set_rival_speech("«Ocupa tu silla, tahúr. No saldrás con mis monedas.»", "[ Listo ]")

	log_msg("\n[b][color=#63b3ed]─── Encuentro %d/4: %s ───[/color][/b]" % [idx + 1, enc.title])
	start_round()

func start_round() -> void:
	is_thinking = false
	shop_overlay.visible = false
	phantom_dice_bonus = 0
	force_enemy_raise = false
	
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
	_update_top_bar()
	_update_consumables_ui()
	_update_oracle_display()

	log_msg("[color=#70c080]🎲 Mano lanzada. Tienes %d dados | Rival: %d dados.[/color]" % [player_dice.size(), enemy_dice.size()])

	# Reliquia: Lente de Cuarzo
	if relic_manager.has_relic("spy_lens") and not enemy_dice_views.is_empty():
		enemy_dice_views[0].face_down = false
		log_msg("[color=#63b3ed]👁️ [Lente de Cuarzo] Dado rival espiado: cara %d.[/color]" % enemy_dice[0].face)

	_set_rival_speech("«Haz tu primera apuesta. Veamos de qué pasta estás hecho.»", "[ Esperando ]")

func _create_dice(count: int) -> Array[Die]:
	var hand: Array[Die] = []
	for _i in range(count):
		hand.append(Die.new())
	return hand

func _sort_dice(dice: Array[Die]) -> void:
	dice.sort_custom(func(a, b): return a.face < b.face)

# ── Renderizado y Manejo de Dados ──────────────────────────────────────────────

func _clear_dice_container(container: HBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()

func _render_dice_views() -> void:
	_clear_dice_container(player_dice_row)
	_clear_dice_container(enemy_dice_row)
	player_dice_views.clear()
	enemy_dice_views.clear()

	# Dados del jugador
	for i in range(player_dice.size()):
		var die: Die = player_dice[i]
		var view := DiceFace.new(die.face, die.type, false)
		player_dice_row.add_child(view)
		player_dice_views.append(view)
		view.play_roll_anim(float(i) * 0.05)

	# Dados del rival (Cristal es visible siempre)
	for i in range(enemy_dice.size()):
		var die: Die = enemy_dice[i]
		var is_face_down: bool = (die.type != Die.Type.CRYSTAL)
		var view := DiceFace.new(die.face, die.type, is_face_down)
		enemy_dice_row.add_child(view)
		enemy_dice_views.append(view)
		view.play_roll_anim(float(i) * 0.05)

	player_count_lbl.text = "%d dados" % player_dice.size()
	enemy_count_lbl.text  = "%d dados" % enemy_dice.size()

# ── Oráculo Táctico de Probabilidad (Estadística Real) ──────────────────────────

func _update_oracle_display() -> void:
	if current_bet.quantity == 0:
		odds_label.text = "ESTIMACIÓN: — [INICIO]"
		odds_label.modulate = Color(0.6, 0.8, 1.0)
		odds_bar.value = 100.0
		odds_details.text = "Haz la primera apuesta de la mano"
	else:
		_calculate_and_render_odds(current_bet.quantity, current_bet.face)

func _update_oracle_preview(q: int, f: int) -> void:
	_calculate_and_render_odds(q, f)

func _calculate_and_render_odds(q: int, f: int) -> void:
	var is_joker: bool = (f == JOKER_FACE)
	
	# Contar dados propios que coinciden
	var my_matches: int = 0
	for d: Die in player_dice:
		if d.counts_as(f, is_joker):
			my_matches += 1

	if phantom_dice_bonus > 0:
		my_matches += phantom_dice_bonus

	var unseen_dice: int = enemy_dice.size()
	var needed: int = q - my_matches
	
	# Probabilidad de cada dado oculto
	var p: float = (1.0 / 6.0) if is_joker else (2.0 / 6.0)
	var expected_rival: float = float(unseen_dice) * p
	var total_expected: float = float(my_matches) + expected_rival

	var prob_percent: float = 0.0
	if needed <= 0:
		prob_percent = 100.0
	elif needed > unseen_dice:
		prob_percent = 0.0
	else:
		# Aproximación binomial acumulada
		prob_percent = _binomial_at_least(unseen_dice, needed, p) * 100.0

	odds_bar.value = prob_percent
	
	var tag: String
	var tag_color: Color
	if prob_percent >= 70.0:
		tag = "[ FAVORABLE ]"
		tag_color = Color(0.3, 0.9, 0.4)
	elif prob_percent >= 40.0:
		tag = "[ ARRIESGADA ]"
		tag_color = Color(0.95, 0.8, 0.2)
	elif prob_percent >= 15.0:
		tag = "[ FAROL FUERTE ]"
		tag_color = Color(0.95, 0.5, 0.2)
	else:
		tag = "[ FAROL EXTREMO ]"
		tag_color = Color(0.95, 0.25, 0.25)

	odds_label.text = "PROBABILIDAD: %d%% %s" % [int(prob_percent), tag]
	odds_label.modulate = tag_color
	odds_details.text = "Tus dados: %d | Rival est.: ~%.1f | Total est.: ~%.1f" % [my_matches, expected_rival, total_expected]

func _binomial_at_least(n: int, k: int, p: float) -> float:
	var total_p: float = 0.0
	for i in range(k, n + 1):
		total_p += _comb(n, i) * pow(p, float(i)) * pow(1.0 - p, float(n - i))
	return clampf(total_p, 0.0, 1.0)

func _comb(n: int, k: int) -> float:
	if k < 0 or k > n: return 0.0
	if k == 0 or k == n: return 1.0
	var res: float = 1.0
	for i in range(1, k + 1):
		res = res * float(n - (k - i)) / float(i)
	return res

# ── Panel del Rival y Diálogos Dinámicos ────────────────────────────────────────

func _set_rival_speech(quote: String, mood_text: String) -> void:
	rival_speech.text = quote
	rival_mood.text = mood_text

# ── Interfaz y Controles ───────────────────────────────────────────────────────

func _update_top_bar() -> void:
	var enc: Dictionary = ENCOUNTERS[encounter_index]
	stage_label.text = "ANTE %d [%d/4%s]" % [current_ante, encounter_index + 1, " 👑" if enc.is_boss else ""]
	gold_label.text = "$ %d" % player_gold
	
	if relic_manager == null or relic_manager.active_relics.is_empty():
		relics_label.text = "Reliquias: (ninguna)"
	else:
		var icons: Array[String] = []
		for r in relic_manager.active_relics:
			icons.append(r.icon_symbol + " " + r.name)
		relics_label.text = "Reliquias: " + ", ".join(icons)

func _update_bet_display() -> void:
	if current_bet.quantity == 0:
		bet_value_lbl.text = "[center][b][color=#f5d76e]— Sin apuesta todavía —[/color][/b][/center]"
		turn_status_lbl.text = "Tu turno para abrir la apuesta"
		turn_status_lbl.modulate = Color(0.6, 0.9, 0.6)
	else:
		var face_name: String = FACE_SYMBOLS[current_bet.face] if current_bet.face < FACE_SYMBOLS.size() else str(current_bet.face)
		bet_value_lbl.text = "[center][font_size=20][b][color=#ffffff]%d[/color][/b] dados de cara [b][color=#f5d76e]%s[/color][/b][/font_size][/center]" % [
			current_bet.quantity,
			face_name
		]
		if is_player_turn:
			turn_status_lbl.text = "¡Es tu turno! Sube la apuesta o canta DUDO"
			turn_status_lbl.modulate = Color(0.6, 0.9, 0.6)
		else:
			turn_status_lbl.text = "Turno del rival... calculando"
			turn_status_lbl.modulate = Color(0.9, 0.7, 0.5)

func _reset_spinboxes_for_turn() -> void:
	if current_bet.quantity == 0:
		spin_quantity.min_value = 1
		spin_quantity.value = 1
		spin_face.min_value = 2
		spin_face.value = 2
	else:
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
			btn_action.text    = "Siguiente Mano"
			btn_action.visible = true
			spin_quantity.editable = false
			spin_face.editable     = false
		State.MATCH_WON:
			btn_bet.disabled   = true
			btn_dudo.disabled  = true
			btn_action.text    = "Ir al Mercado 🛒"
			btn_action.visible = true
			spin_quantity.editable = false
			spin_face.editable     = false
		State.GAME_OVER:
			btn_bet.disabled   = true
			btn_dudo.disabled  = true
			btn_action.text    = "Reintentar Run"
			btn_action.visible = true
			spin_quantity.editable = false
			spin_face.editable     = false
		State.RUN_WON:
			btn_bet.disabled   = true
			btn_dudo.disabled  = true
			btn_action.text    = "¡Victoria Total!"
			btn_action.visible = true
			spin_quantity.editable = false
			spin_face.editable     = false

# ── Interacción del Jugador ────────────────────────────────────────────────────

func _on_btn_bet_pressed() -> void:
	if state != State.BETTING or not is_player_turn or is_thinking:
		return

	var quantity := int(spin_quantity.value)
	var face     := int(spin_face.value)

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
		_update_oracle_display()

		var f_str: String = FACE_SYMBOLS[face]
		log_msg("👤 [b]Apuestas:[/b] [color=#9ae6b4]%d al %s[/color]" % [quantity, f_str])
		
		# Reacción del rival
		if quantity >= player_dice.size() + 2:
			_set_rival_speech("«¿%d dados? Me parece que estás apostando humo...»" % quantity, "[ Sospecha ]")
		else:
			_set_rival_speech("«Buena subida. Déjame revisar mis dados...»", "[ Pensativo ]")

		_start_enemy_turn_with_delay()
	else:
		log_msg("[color=#fc8181]⚠ Apuesta inválida. Sube la cantidad o la cara del dado.[/color]")

func _on_btn_dudo_pressed() -> void:
	if state != State.BETTING or not is_player_turn or current_bet.quantity == 0 or is_thinking:
		return

	_set_rival_speech("«¡¿DUDO?! ¡Pues destapemos la mesa ahora mismo!»", "[ ¡DESAFÍO! ]")
	log_msg("\n[b][color=#f56565]¡HAS CANTADO DUDO! Levantando cubiletes...[/color][/b]")
	resolve_dudo(true)

func _on_btn_action_pressed() -> void:
	match state:
		State.ROUND_OVER:
			start_round()
		State.MATCH_WON:
			_open_victory_shop()
		State.GAME_OVER, State.RUN_WON:
			start_new_run()

# ── Turno del Enemigo (IA) ─────────────────────────────────────────────────────

func _start_enemy_turn_with_delay() -> void:
	is_thinking = true
	_set_state(State.BETTING)
	_set_rival_speech("«Mmm... calculando cuántos dados hay en la mesa...»", "[ Calculando ]")

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

	# Si se usó el consumible 'Trago de Whisky', fuerza al rival a subir la cantidad
	if force_enemy_raise and decision.get("action") == "bet":
		decision["quantity"] = maxi(decision.get("quantity", current_bet.quantity + 1), current_bet.quantity + 1)
		force_enemy_raise = false

	if decision.get("action") == "dudo":
		_set_rival_speech("«¡NO TE CREO NADA! ¡CANTO DUDO A TU APUESTA!»", "[ ¡DUDO! ]")
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
		_update_oracle_display()

		var f_str: String = FACE_SYMBOLS[f]
		_set_rival_speech("«Subo a %d dados de cara %d. ¿Vas a dudar o te atreves a más?»" % [q, f], "[ Seguro ]")
		log_msg("🤖 [b]Rival sube a:[/b] [color=#fbd38d]%d dados al %s[/color]" % [q, f_str])

# ── Resolución de Farol (Dudo) ─────────────────────────────────────────────────

func resolve_dudo(player_called: bool) -> void:
	is_thinking = true
	_set_state(State.ROUND_OVER)
	btn_action.visible = false

	var bet_face       : int  = current_bet.face
	var bet_quantity   : int  = current_bet.quantity
	var is_joker_round : bool = (bet_face == JOKER_FACE)

	# 1. Revelar dados del enemigo
	for i in range(enemy_dice_views.size()):
		var view: DiceFace = enemy_dice_views[i]
		view.play_reveal_anim(float(i) * 0.12)

	if is_inside_tree():
		var reveal_time: float = float(enemy_dice_views.size()) * 0.12 + 0.35
		await get_tree().create_timer(reveal_time).timeout

	# 2. Conteo de dados
	var physical_count: int = 0
	var f_str: String = FACE_SYMBOLS[bet_face]

	for i in range(player_dice.size()):
		var d: Die = player_dice[i]
		if d.counts_as(bet_face, is_joker_round):
			physical_count += 1
			player_dice_views[i].is_highlighted = true

	for i in range(enemy_dice.size()):
		var d: Die = enemy_dice[i]
		if d.counts_as(bet_face, is_joker_round):
			physical_count += 1
			enemy_dice_views[i].is_highlighted = true

	# Bonificaciones de reliquias y consumibles
	var relic_bonus: int = relic_manager.apply_dice_count_modifiers(bet_face, is_joker_round, physical_count, player_called)
	var final_count: int = physical_count + relic_bonus + phantom_dice_bonus
	phantom_dice_bonus = 0

	log_msg("───────────────────────────────────────")
	log_msg("🔍 [b]Mesa:[/b] %d dados de cara %s (Apuesta: %d)." % [final_count, f_str, bet_quantity])

	var bet_was_true: bool = (final_count >= bet_quantity)
	var player_loses: bool

	if player_called:
		player_loses = bet_was_true
		if bet_was_true:
			_set_rival_speech("«¡Jajaja! ¡Te dije que no mentía! Pierdes un dado.»", "[ Victorioso ]")
			log_msg("[color=#fc8181]❌ La apuesta del rival era cierta. ¡Tu duda falló![/color]")
		else:
			_set_rival_speech("«¡Maldita sea! ¿Cómo supiste que estaba mintiendo...?»", "[ Derrotado ]")
			log_msg("[color=#68d391]🎯 ¡Cazaste el farol del rival con éxito![/color]")
			
			var gold_gain: int = 2
			if relic_manager.has_relic("gambler_pouch"):
				gold_gain += 4
				log_msg("[color=#f6e05e]💰 ¡Bolsa de Tahúr otorga +4 oro extra![/color]")
			player_gold += gold_gain
			log_msg("[color=#f6e05e]+%d 🪙 ganados por cazar el farol.[/color]" % gold_gain)
	else:
		player_loses = not bet_was_true
		if player_loses:
			_set_rival_speech("«¡Cazado! Sabía perfectamente que no tenías suficientes dados.»", "[ Burlón ]")
			log_msg("[color=#fc8181]❌ ¡Te cazaron el farol! No había suficientes dados.[/color]")
		else:
			_set_rival_speech("«¡Imposible! ¡Tu apuesta era real...! Me equivoqué al dudar.»", "[ Frustrado ]")
			log_msg("[color=#68d391]🎯 ¡Tu apuesta era legítima! El rival dudó equivocadamente.[/color]")
			player_gold += 2

	# Efectos especiales de dados del jugador si gana la ronda
	if not player_loses:
		for d: Die in player_dice:
			if d.type == Die.Type.CRYSTAL:
				player_gold += 3
				log_msg("[color=#63b3ed]💎 ¡Dado de Cristal otorga +3 oro extra![/color]")
			elif d.type == Die.Type.VAMPIRIC and d.counts_as(bet_face, is_joker_round):
				player_dice.append(Die.new())
				log_msg("[color=#fc8181]🩸 ¡Dado Vampírico drenó vida al rival y te dio +1 dado![/color]")

	_update_top_bar()

	# 3. Eliminar dado del perdedor
	if is_inside_tree():
		await get_tree().create_timer(0.6).timeout

	var enc: Dictionary = ENCOUNTERS[encounter_index]
	var dice_lost: int = 1
	# Si es el Jefe y el jugador perdió, aplica "Castigo Doble"
	if player_loses and enc.is_boss:
		dice_lost = 2
		log_msg("[color=#e53e3e]👑 ¡CASTIGO DEL JEFE! El Barón te arrebata 2 dados en vez de 1.[/color]")

	if player_loses:
		for _l in range(dice_lost):
			if not player_dice.is_empty():
				player_dice.pop_back()
			if not player_dice_views.is_empty():
				var dying: DiceFace = player_dice_views.pop_back()
				dying.play_vanish_anim()
		log_msg("[b][color=#e53e3e]💀 ¡Pierdes %d dado(s)![/color][/b] Te quedan: %d." % [dice_lost, player_dice.size()])
	else:
		enemy_dice.pop_back()
		if not enemy_dice_views.is_empty():
			var dying: DiceFace = enemy_dice_views.pop_back()
			dying.play_vanish_anim()
		log_msg("[b][color=#48bb78]💥 ¡El rival pierde 1 dado![/color][/b] Le quedan: %d." % enemy_dice.size())

	player_count_lbl.text = "%d dados" % player_dice.size()
	enemy_count_lbl.text  = "%d dados" % enemy_dice.size()

	# 4. Comprobar resolución del combate
	if is_inside_tree():
		await get_tree().create_timer(0.5).timeout
	is_thinking = false

	if player_dice.is_empty():
		_handle_player_defeat()
	elif enemy_dice.is_empty():
		_handle_match_victory()
	else:
		_set_state(State.ROUND_OVER)

# ── Victoria / Derrota de Combate ─────────────────────────────────────────────

func _handle_player_defeat() -> void:
	_set_rival_speech("«La mesa siempre gana, forastero. Se te acabaron los dados.»", "[ Victorioso ]")
	log_msg("═══════════════════════════════════════")
	log_msg("[b][color=#e53e3e]💀 DERROTA. Te has quedado sin dados.[/color][/b]")
	log_msg("[color=#fc8181]Tu run ha terminado en el Encuentro %d/4. ¡Reinténtalo![/color]" % (encounter_index + 1))
	_set_state(State.GAME_OVER)

func _handle_match_victory() -> void:
	var enc: Dictionary = ENCOUNTERS[encounter_index]
	var reward: int = enc.reward
	player_gold += reward
	_update_top_bar()

	log_msg("═══════════════════════════════════════")
	log_msg("[b][color=#f6e05e]🎉 ¡HAS DERROTADO A %s![/color][/b]" % enc.name)
	log_msg("[color=#68d391]Recompensa de combate: +%d 🪙 de oro.[/color]" % reward)

	if enc.is_boss:
		_set_rival_speech("«¡No puede ser...! ¡Mi trono de dados... derrumbado!»", "[ ¡DERROTADO! ]")
		log_msg("\n[b][color=#f6e05e]🏆 ¡¡ANTE %d COMPLETADO CON ÉXITO!![/color][/b]" % current_ante)
		log_msg("[b][color=#68d391]¡Has derrotado al Barón Tramposo y conquistado la Run![/color][/b]")
		_set_state(State.RUN_WON)
	else:
		_set_rival_speech("«Bien jugado... Me he quedado sin dados. Pasa a la trastienda.»", "[ Derrotado ]")
		log_msg("[color=#f5d76e]El Mercado está abierto. Gasta tus ganancias antes del siguiente duelo.[/color]")
		_set_state(State.MATCH_WON)
		_open_victory_shop()

# ── Consumibles de Manga (Uso en vivo) ─────────────────────────────────────────

func _update_consumables_ui() -> void:
	if player_consumables.size() > 0:
		var c1 = player_consumables[0]
		slot1_btn.text = "%s %s" % [c1.icon_symbol, c1.name]
		slot1_btn.disabled = false
	else:
		slot1_btn.text = "[ Vacío ]"
		slot1_btn.disabled = true

	if player_consumables.size() > 1:
		var c2 = player_consumables[1]
		slot2_btn.text = "%s %s" % [c2.icon_symbol, c2.name]
		slot2_btn.disabled = false
	else:
		slot2_btn.text = "[ Vacío ]"
		slot2_btn.disabled = true

func _on_slot1_btn_pressed() -> void:
	_use_consumable_at_index(0)

func _on_slot2_btn_pressed() -> void:
	_use_consumable_at_index(1)

func _use_consumable_at_index(idx: int) -> void:
	if idx >= player_consumables.size() or state != State.BETTING or not is_player_turn or is_thinking:
		return

	var c = player_consumables[idx]
	player_consumables.remove_at(idx)
	_update_consumables_ui()

	match c.id:
		"secret_reroll":
			# Relanza 1 dado del jugador que no coincida con la apuesta actual
			if not player_dice.is_empty():
				var picked: Die = player_dice.pick_random()
				picked.roll()
				_sort_dice(player_dice)
				_render_dice_views()
				_update_oracle_display()
				log_msg("[color=#b794f4]🔄 [Cubilete Falso] Relanzaste 1 dado en secreto: ahora es cara %d.[/color]" % picked.face)
		"phantom_die":
			phantom_dice_bonus += 1
			_update_oracle_display()
			log_msg("[color=#b794f4]👻 [Dado Fantasma] ¡Añadido +1 dado espectral a la mesa para tu favor![/color]")
		"whiskey_shot":
			force_enemy_raise = true
			log_msg("[color=#b794f4]🥃 [Trago Fuerte] ¡El rival está intimidado y obligado a subir la cantidad o dudar![/color]")
		"spy_mirror":
			# Revela un dado oculto del rival
			for view: DiceFace in enemy_dice_views:
				if view.face_down:
					view.face_down = false
					log_msg("[color=#b794f4]🔍 [Espejo de Mano] Descubriste un dado rival: cara %d.[/color]" % view.face_value)
					break

# ── Tienda de Victoria (Solo tras ganar el encuentro) ──────────────────────────

func _open_victory_shop() -> void:
	shop_overlay.visible = true
	var next_idx: int = encounter_index + 1
	if next_idx < ENCOUNTERS.size():
		var next_enc: Dictionary = ENCOUNTERS[next_idx]
		if next_enc.is_boss:
			next_encounter_label.text = "⚠️ ¡ATENCIÓN! PRÓXIMO COMBATE: %s (6 dados)" % next_enc.name
			next_encounter_label.modulate = Color(1.0, 0.3, 0.3)
			btn_next_match.text = "Enfrentar al Jefe 👑"
		else:
			next_encounter_label.text = "Próximo Rival: %s (%d dados)" % [next_enc.name, next_enc.dice_count]
			next_encounter_label.modulate = Color(0.9, 0.8, 0.4)
			btn_next_match.text = "Siguiente Rival ➡️"

func _on_btn_next_match_pressed() -> void:
	shop_overlay.visible = false
	encounter_index += 1
	if encounter_index < ENCOUNTERS.size():
		start_encounter(encounter_index)
	else:
		start_new_run()

func _on_btn_buy_loaded_pressed() -> void:
	if player_gold < 5:
		log_msg("[color=#fc8181]No tienes suficiente oro (5 🪙).[/color]")
		return
	player_gold -= 5
	player_dice.append(Die.new(Die.Type.LOADED))
	_update_top_bar()
	_render_dice_views()
	log_msg("[color=#f6ad55]🎲 Compraste un Dado Cargado (tira 2 veces, guarda el mayor).[/color]")

func _on_btn_buy_wildcard_pressed() -> void:
	if player_gold < 8:
		log_msg("[color=#fc8181]No tienes suficiente oro (8 🪙).[/color]")
		return
	player_gold -= 8
	player_dice.append(Die.new(Die.Type.WILDCARD))
	_update_top_bar()
	_render_dice_views()
	log_msg("[color=#f6e05e]⭐ Compraste un Dado Comodín (vale por cualquier cara).[/color]")

func _on_btn_buy_crystal_pressed() -> void:
	if player_gold < 6:
		log_msg("[color=#fc8181]No tienes suficiente oro (6 🪙).[/color]")
		return
	player_gold -= 6
	player_dice.append(Die.new(Die.Type.CRYSTAL))
	_update_top_bar()
	_render_dice_views()
	log_msg("[color=#63b3ed]💎 Compraste un Dado de Cristal (+3 oro al ganar la mano).[/color]")

func _on_btn_buy_vampiric_pressed() -> void:
	if player_gold < 7:
		log_msg("[color=#fc8181]No tienes suficiente oro (7 🪙).[/color]")
		return
	player_gold -= 7
	player_dice.append(Die.new(Die.Type.VAMPIRIC))
	_update_top_bar()
	_render_dice_views()
	log_msg("[color=#fc8181]🩸 Compraste un Dado Vampírico (cura 1 dado al puntuar al ganar).[/color]")

func _on_btn_buy_trick_pressed() -> void:
	if player_gold < 4:
		log_msg("[color=#fc8181]No tienes suficiente oro (4 🪙).[/color]")
		return
	if player_consumables.size() >= 2:
		log_msg("[color=#fc8181]¡Mochila llena! Máximo 2 trucos a la vez.[/color]")
		return
	var catalog := ConsumableClass.get_catalog()
	var trick = catalog.pick_random()
	player_gold -= 4
	player_consumables.append(trick)
	_update_top_bar()
	_update_consumables_ui()
	log_msg("[color=#b794f4]🧪 ¡Nuevo truco adquirido: %s %s! %s[/color]" % [trick.icon_symbol, trick.name, trick.description])

func _on_btn_buy_relic_pressed() -> void:
	if player_gold < 6:
		log_msg("[color=#fc8181]No tienes suficiente oro (6 🪙).[/color]")
		return

	var available: Array = RelicManager.get_all_available_relics()
	var unowned: Array = []
	for r in available:
		if not relic_manager.has_relic(r.id):
			unowned.append(r)

	if unowned.is_empty():
		log_msg("[color=#cbd5e0]Ya posees todas las reliquias disponibles.[/color]")
		return

	var chosen = unowned.pick_random()
	player_gold -= 6
	relic_manager.add_relic(chosen)
	_update_top_bar()
	log_msg("[color=#f6e05e]🏺 ¡Nueva Reliquia: [b]%s[/b]! %s[/color]" % [chosen.name, chosen.description])

func _on_btn_recover_die_pressed() -> void:
	if player_gold < 4:
		log_msg("[color=#fc8181]No tienes suficiente oro (4 🪙).[/color]")
		return
	player_gold -= 4
	player_dice.append(Die.new(Die.Type.NORMAL))
	_update_top_bar()
	_render_dice_views()
	log_msg("[color=#68d391]➕ ¡Has recuperado 1 dado para tu cubilete![/color]")
