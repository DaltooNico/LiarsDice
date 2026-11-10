extends Node2D

const EnemyAI = preload("res://EnemyAI.gd")
const DiceFace = preload("res://DiceFace.gd")
const RelicManager = preload("res://RelicManager.gd")
const RelicScript = preload("res://Relic.gd")

# ── Roster de Encuentros (Estilo Balatro: 3 Rivales + 1 Jefe) ───────────────────
const ENCOUNTERS = [
	{
		"name": "Jack 'El Novato'",
		"title": "Novato del Callejón [Cauteloso]",
		"personality": EnemyAI.Personality.CAUTIOUS,
		"dice_count": 4,
		"reward": 4,
		"is_boss": false,
		"desc": "Juega sobre seguro. Canta Dudo si la apuesta parece improbable."
	},
	{
		"name": "Vargas 'El Sabueso'",
		"title": "Tahúr Callejero [Agresivo]",
		"personality": EnemyAI.Personality.AGGRESSIVE,
		"dice_count": 5,
		"reward": 5,
		"is_boss": false,
		"desc": "Agresivo. Presiona subiendo la apuesta para intimidar."
	},
	{
		"name": "Madame Farol",
		"title": "Apostadora Ciega [Farolera]",
		"personality": EnemyAI.Personality.BLUFFER,
		"dice_count": 5,
		"reward": 6,
		"is_boss": false,
		"desc": "Impredecible. Apuesta a caras que no tiene para tender trampas."
	},
	{
		"name": "👑 El Barón Tramposo",
		"title": "JEFE: El Barón Tramposo [Jefe]",
		"personality": EnemyAI.Personality.CHEATER_BOSS,
		"dice_count": 6,
		"reward": 15,
		"is_boss": true,
		"desc": "¡JEFE! Juega con 6 dados y posee un dado comodín dorado en su reserva."
	}
]

# ── Progreso de la Run (Roguelike) ─────────────────────────────────────────────
var current_ante: int = 1
var encounter_index: int = 0
var player_gold: int = 10
var relic_manager = null

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

@onready var shop_overlay         : PanelContainer = $UILayer/ShopOverlay
@onready var next_encounter_label : Label          = $UILayer/ShopOverlay/Margin/VBox/NextEncounterLabel
@onready var btn_next_match       : Button         = $UILayer/ShopOverlay/Margin/VBox/BtnNextMatch

func _ready() -> void:
	start_new_run()

# ── Sistema de Log enriquecido con BBCode ──────────────────────────────────────

func log_msg(bbcode_text: String) -> void:
	_log_buffer += bbcode_text + "\n"
	game_log.text = _log_buffer

func _clear_log() -> void:
	_log_buffer = ""
	game_log.text = ""

# ── Ciclo de Vida de la Run ────────────────────────────────────────────────────

func start_new_run() -> void:
	current_ante = 1
	encounter_index = 0
	player_gold = 10
	relic_manager = RelicManager.new()
	
	# La reserva inicial del jugador: 5 dados normales
	player_dice = _create_dice(5)
	
	_clear_log()
	log_msg("[b][color=#f5d76e]══════ INICIO DE NUEVA RUN (ANTE %d) ══════[/color][/b]" % current_ante)
	log_msg("[color=#aaaaaa]Supera a 3 rivales y derrota al Jefe para completar el Ante.[/color]")
	log_msg("[color=#aaaaaa]Solo podrás acceder a la Tienda al ganar cada combate.[/color]\n")
	
	start_encounter(encounter_index)

func start_encounter(idx: int) -> void:
	shop_overlay.visible = false
	var enc: Dictionary = ENCOUNTERS[idx]
	
	# Configurar IA rival
	enemy_ai = EnemyAI.new(enc.personality, enc.name)
	enemy_title.text = "RIVAL: " + enc.title
	
	# Crear dados del rival (si es el jefe, tiene 1 comodín especial)
	enemy_dice.clear()
	var rival_dice_count: int = enc.dice_count
	if enc.is_boss:
		enemy_dice.append(Die.new(Die.Type.WILDCARD)) # Dado tramposo del jefe
		for _i in range(rival_dice_count - 1):
			enemy_dice.append(Die.new())
	else:
		enemy_dice = _create_dice(rival_dice_count)

	# Asegurar que el jugador comience con al menos 5 dados (conservando especiales)
	while player_dice.size() < 5:
		player_dice.append(Die.new())

	_update_top_bar()
	
	if enc.is_boss:
		log_msg("\n[b][color=#e53e3e]⚠ ¡ADVERTENCIA DE JEFE! Te enfrentas a %s[/color][/b]" % enc.name)
		log_msg("[color=#feb2b2]%s[/color]" % enc.desc)
	else:
		log_msg("\n[b][color=#63b3ed]⚔ Encuentro %d/4: %s[/color][/b]" % [idx + 1, enc.title])
		log_msg("[color=#cbd5e0]%s[/color]" % enc.desc)

	start_round()

func start_round() -> void:
	is_thinking = false
	shop_overlay.visible = false
	
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

	log_msg("\n[b][color=#70c080]─── Nueva Mano ───[/color][/b]")
	log_msg("Mesa: Tienes [b]%d[/b] dados. El rival tiene [b]%d[/b]." % [player_dice.size(), enemy_dice.size()])

	# Reliquia: Lente de Cuarzo
	if relic_manager.has_relic("spy_lens") and not enemy_dice_views.is_empty():
		enemy_dice_views[0].face_down = false
		log_msg("[color=#63b3ed]👁️ [b]Lente de Cuarzo:[/b] Puedes espiar que el rival tiene un dado con cara %d![/color]" % enemy_dice[0].face)

	log_msg("[color=#e0e0e0]Empiezas tú. Haz tu apuesta.[/color]")

func _create_dice(count: int) -> Array[Die]:
	var hand: Array[Die] = []
	for _i in range(count):
		hand.append(Die.new())
	return hand

func _sort_dice(dice: Array[Die]) -> void:
	dice.sort_custom(func(a, b): return a.face < b.face)

# ── Renderizado y Animación de Dados ───────────────────────────────────────────

func _clear_dice_container(container: HBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()

func _render_dice_views() -> void:
	_clear_dice_container(player_dice_row)
	_clear_dice_container(enemy_dice_row)
	player_dice_views.clear()
	enemy_dice_views.clear()

	for i in range(player_dice.size()):
		var die: Die = player_dice[i]
		var view := DiceFace.new(die.face, die.type, false)
		player_dice_row.add_child(view)
		player_dice_views.append(view)
		view.play_roll_anim(float(i) * 0.05)

	for i in range(enemy_dice.size()):
		var die: Die = enemy_dice[i]
		var view := DiceFace.new(die.face, die.type, true)
		enemy_dice_row.add_child(view)
		enemy_dice_views.append(view)
		view.play_roll_anim(float(i) * 0.05)

	player_count_lbl.text = "%d dados" % player_dice.size()
	enemy_count_lbl.text  = "%d dados" % enemy_dice.size()

# ── Actualización de Interfaz ──────────────────────────────────────────────────

func _update_top_bar() -> void:
	var enc: Dictionary = ENCOUNTERS[encounter_index]
	var stage_text: String
	if enc.is_boss:
		stage_text = "👑 ANTE %d — Encuentro 4/4 (¡JEFE!)" % current_ante
	else:
		stage_text = "🏆 ANTE %d — Encuentro %d/4 (Rival)" % [current_ante, encounter_index + 1]
	stage_label.text = stage_text

	gold_label.text = "💰 Oro: %d" % player_gold
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
			btn_action.text    = "Ir a la Tienda 🛒"
			btn_action.visible = true
			spin_quantity.editable = false
			spin_face.editable     = false
		State.GAME_OVER:
			btn_bet.disabled   = true
			btn_dudo.disabled  = true
			btn_action.text    = "Reintentar Run (Nueva Partida)"
			btn_action.visible = true
			spin_quantity.editable = false
			spin_face.editable     = false
		State.RUN_WON:
			btn_bet.disabled   = true
			btn_dudo.disabled  = true
			btn_action.text    = "¡Victoria Total! (Nueva Run)"
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

		var f_str: String = FACE_SYMBOLS[face]
		log_msg("👤 [b]Has apostado:[/b] [color=#9ae6b4]%d al %s[/color]" % [quantity, f_str])
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
		State.MATCH_WON:
			_open_victory_shop()
		State.GAME_OVER, State.RUN_WON:
			start_new_run()

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

	# 2. Contar dados físicos
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

	# 3. Intercepción de Reliquias
	var relic_bonus: int = relic_manager.apply_dice_count_modifiers(bet_face, is_joker_round, physical_count, player_called)
	var final_count: int = physical_count + relic_bonus

	log_msg("───────────────────────────────────────")
	if relic_bonus != 0:
		log_msg("🔍 [b]Conteo Físico:[/b] %d  | [b][color=#f6e05e]Bonificación de Reliquias: +%d[/color][/b] → [b]Total Final: %d[/b]" % [
			physical_count, relic_bonus, final_count
		])
	else:
		log_msg("🔍 [b]Resultado en la mesa:[/b] Hay [b][color=#f6e05e]%d[/color][/b] dado(s) de cara %s (Apuesta: [b]%d[/b])." % [
			final_count, f_str, bet_quantity
		])

	var bet_was_true: bool = (final_count >= bet_quantity)
	var player_loses: bool

	if player_called:
		player_loses = bet_was_true
		if bet_was_true:
			log_msg("[color=#fc8181]❌ La apuesta del rival era real. ¡Tu duda fue errónea![/color]")
		else:
			log_msg("[color=#68d391]🎯 ¡Cazaste el farol del rival! La apuesta era falsa.[/color]")
			var gold_reward: int = 2
			if relic_manager.has_relic("gambler_pouch"):
				gold_reward += 4
				log_msg("[color=#f6e05e]💰 ¡Bolsa de Tahúr te otorga +4 oro extra![/color]")
			player_gold += gold_reward
			log_msg("[color=#f6e05e]+%d 🪙 de oro ganado por cazar el farol.[/color]" % gold_reward)
	else:
		player_loses = not bet_was_true
		if player_loses:
			log_msg("[color=#fc8181]❌ ¡Te cazaron el farol! No había suficientes dados.[/color]")
		else:
			log_msg("[color=#68d391]🎯 ¡Tu apuesta era legítima! El rival dudó equivocadamente.[/color]")
			player_gold += 2
			log_msg("[color=#f6e05e]+2 🪙 por defender tu apuesta.[/color]")

	_update_top_bar()

	# 4. Eliminar dado del perdedor
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

	# 5. Comprobar resolución del combate
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
	log_msg("═══════════════════════════════════════")
	log_msg("[b][color=#e53e3e]💀 DERROTA. Te has quedado sin dados.[/color][/b]")
	log_msg("[color=#fc8181]Tu run ha terminado en el Encuentro %d/4. ¡Mejor suerte la próxima vez![/color]" % (encounter_index + 1))
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
		# ¡Has vencido al Jefe de la Run!
		log_msg("\n[b][color=#f6e05e]🏆 ¡¡ANTE %d COMPLETADO CON ÉXITO!![/color][/b]" % current_ante)
		log_msg("[b][color=#68d391]¡Has derrotado al Barón Tramposo y completado la Run Roguelike![/color][/b]")
		_set_state(State.RUN_WON)
	else:
		log_msg("[color=#f5d76e]La Tienda está ahora abierta. Gasta tus ganancias antes del siguiente rival.[/color]")
		_set_state(State.MATCH_WON)
		# Abrir la tienda de victoria
		_open_victory_shop()

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
		# Fin del ante
		start_new_run()

func _on_btn_buy_loaded_pressed() -> void:
	if player_gold < 5:
		log_msg("[color=#fc8181]No tienes suficiente oro (cuesta 5 🪙).[/color]")
		return
	player_gold -= 5
	player_dice.append(Die.new(Die.Type.LOADED))
	_update_top_bar()
	_render_dice_views()
	log_msg("[color=#f6ad55]🎲 ¡Compraste un Dado Cargado! (Tira 2 veces y guarda el mayor).[/color]")

func _on_btn_buy_wildcard_pressed() -> void:
	if player_gold < 8:
		log_msg("[color=#fc8181]No tienes suficiente oro (cuesta 8 🪙).[/color]")
		return
	player_gold -= 8
	player_dice.append(Die.new(Die.Type.WILDCARD))
	_update_top_bar()
	_render_dice_views()
	log_msg("[color=#f6e05e]⭐ ¡Compraste un Dado Comodín! (Cuenta para cualquier cara).[/color]")

func _on_btn_recover_die_pressed() -> void:
	if player_gold < 4:
		log_msg("[color=#fc8181]No tienes suficiente oro (cuesta 4 🪙).[/color]")
		return
	player_gold -= 4
	player_dice.append(Die.new(Die.Type.NORMAL))
	_update_top_bar()
	_render_dice_views()
	log_msg("[color=#68d391]➕ ¡Has recuperado 1 dado para tu reserva![/color]")

func _on_btn_buy_relic_pressed() -> void:
	if player_gold < 6:
		log_msg("[color=#fc8181]No tienes suficiente oro (cuesta 6 🪙).[/color]")
		return

	var available: Array = RelicManager.get_all_available_relics()
	var unowned: Array = []
	for r in available:
		if not relic_manager.has_relic(r.id):
			unowned.append(r)

	if unowned.is_empty():
		log_msg("[color=#cbd5e0]Ya posees todas las reliquias disponibles en esta versión.[/color]")
		return

	var chosen = unowned.pick_random()
	player_gold -= 6
	relic_manager.add_relic(chosen)
	_update_top_bar()
	log_msg("[color=#f6e05e]🏺 ¡Nueva Reliquia Obtenida: [b]%s[/b]! %s[/color]" % [chosen.name, chosen.description])
