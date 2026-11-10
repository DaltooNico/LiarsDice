extends Node2D

var player_dice : Array[int] = []
var enemy_dice : Array[int] = []
var current_bet : Dictionary = {"quantity": 0, "face": 0}
const JOKER_FACE = 1 

@onready var game_log = $UILayer/VBox/GameLog
@onready var player_label = $UILayer/VBox/PlayerArea/Label
@onready var enemy_label = $UILayer/VBox/EnemyArea/Label
@onready var spin_quantity = $UILayer/VBox/BettingPanel/QuantitySpinBox
@onready var spin_face = $UILayer/VBox/BettingPanel/FaceSpinBox

func _ready():
	start_round(5, 5)

func log_msg(msg: String):
	game_log.text += msg + "\n"

func start_round(player_count: int, enemy_count: int):
	player_dice = roll_dice(player_count)
	enemy_dice = roll_dice(enemy_count)
	current_bet = {"quantity": 0, "face": 0}
	
	player_label.text = "Tus dados: " + str(player_dice)
	enemy_label.text = "Dados rival: [Ocultos] (" + str(enemy_count) + " dados)"
	
	game_log.text = ""
	log_msg("--- ¡Comienza la ronda! ---")
	log_msg("Empiezas tú. Haz tu apuesta.")

func roll_dice(count: int) -> Array[int]:
	var hand : Array[int] = []
	for i in range(count):
		hand.append(randi() % 6 + 1)
	hand.sort()
	return hand

func _on_btn_bet_pressed():
	var quantity = int(spin_quantity.value)
	var face = int(spin_face.value)
	
	if quantity > current_bet.quantity or (quantity == current_bet.quantity and face > current_bet.face):
		current_bet = {"quantity": quantity, "face": face}
		log_msg("Has apostado: " + str(quantity) + " dados al " + str(face))
		# Turno del enemigo (básico)
		enemy_turn()
	else:
		log_msg("Apuesta inválida. Sube la cantidad o el valor de la cara.")

func enemy_turn():
	log_msg("El rival está pensando...")
	current_bet.quantity += 1 # IA muy simple
	log_msg("El rival apuesta: " + str(current_bet.quantity) + " dados al " + str(current_bet.face))
	spin_quantity.value = current_bet.quantity
	spin_face.value = current_bet.face

func _on_btn_dudo_pressed():
	log_msg("¡DUDO! Revisando la mesa...")
	enemy_label.text = "Dados rival: " + str(enemy_dice)
	var total_count = 0
	var is_joker_round = (current_bet.face == JOKER_FACE)
	
	for d in player_dice:
		if d == current_bet.face or (!is_joker_round and d == JOKER_FACE):
			total_count += 1
			
	for d in enemy_dice:
		if d == current_bet.face or (!is_joker_round and d == JOKER_FACE):
			total_count += 1

	log_msg("Total de " + str(current_bet.face) + "s en mesa (incluyendo comodines 1s): " + str(total_count))
	
	if total_count >= current_bet.quantity:
		log_msg("La apuesta era cierta. ¡Pierdes un dado!")
	else:
		log_msg("¡Era un farol! ¡El enemigo pierde un dado!")
