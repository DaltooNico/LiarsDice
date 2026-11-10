class_name DiceFace
extends Control

## Dado visual interactivo para Liar's Dice.
## Dibuja sus pips, sombra, bordes redondeados y efectos especiales según su tipo.
## Incluye animaciones de tirada, revelado escalonado (flip 3D falso) y resaltado.

const DIE_SIZE := Vector2(80.0, 80.0)
const PADDING  := 12.0
const PIP_R    := 7.0
const CORNER_R := 12

var face_value: int = 1:
	set(v):
		face_value = clampi(v, 1, 6)
		queue_redraw()

var face_down: bool = false:
	set(v):
		face_down = v
		queue_redraw()

var die_type: Die.Type = Die.Type.NORMAL:
	set(t):
		die_type = t
		queue_redraw()

var is_highlighted: bool = false:
	set(v):
		is_highlighted = v
		queue_redraw()

var is_loser: bool = false:
	set(v):
		is_loser = v
		queue_redraw()

func _init(p_face: int = 1, p_type: Die.Type = Die.Type.NORMAL, p_face_down: bool = false) -> void:
	face_value = p_face
	die_type = p_type
	face_down = p_face_down
	custom_minimum_size = DIE_SIZE
	pivot_offset = DIE_SIZE / 2.0

func _ready() -> void:
	custom_minimum_size = DIE_SIZE
	pivot_offset = DIE_SIZE / 2.0

# ── Pip positions (0.0 a 1.0 dentro del área útil) ───────────────────────────

static func _pip_layout(face: int) -> Array:
	match face:
		1: return [Vector2(0.5,  0.5)]
		2: return [Vector2(0.75, 0.28), Vector2(0.25, 0.72)]
		3: return [Vector2(0.75, 0.25), Vector2(0.5,  0.5),  Vector2(0.25, 0.75)]
		4: return [Vector2(0.25, 0.28), Vector2(0.75, 0.28), Vector2(0.25, 0.72), Vector2(0.75, 0.72)]
		5: return [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.5,  0.5),  Vector2(0.25, 0.75), Vector2(0.75, 0.75)]
		6: return [Vector2(0.25, 0.22), Vector2(0.75, 0.22), Vector2(0.25, 0.5),  Vector2(0.75, 0.5),  Vector2(0.25, 0.78), Vector2(0.75, 0.78)]
		_: return [Vector2(0.5,  0.5)]

# ── Colores según tipo y estado ───────────────────────────────────────────────

func _bg_color() -> Color:
	if is_loser:
		return Color(0.35, 0.1, 0.1, 0.6)
	if face_down:
		return Color(0.14, 0.22, 0.38) # Dorso azul oscuro misterioso
	match die_type:
		Die.Type.LOADED:   return Color(0.92, 0.78, 0.55) # Tono madera / dorado cargado
		Die.Type.CRYSTAL:  return Color(0.75, 0.92, 1.0, 0.85) # Cristal translúcido
		Die.Type.VAMPIRIC: return Color(0.48, 0.05, 0.08) # Carmesí profundo
		Die.Type.WILDCARD: return Color(1.0, 0.85, 0.25) # Dorado reluciente
		_:                 return Color(0.96, 0.94, 0.89) # Marfil clásico

func _pip_color() -> Color:
	if is_loser:
		return Color(0.6, 0.2, 0.2)
	match die_type:
		Die.Type.CRYSTAL:  return Color(0.08, 0.35, 0.70)
		Die.Type.VAMPIRIC: return Color(0.98, 0.75, 0.75)
		Die.Type.WILDCARD: return Color(0.35, 0.20, 0.0)
		_:                 return Color(0.12, 0.12, 0.14)

func _border_color() -> Color:
	if is_highlighted:
		return Color(1.0, 0.88, 0.2, 1.0) # Resaltado dorado si cuenta para la apuesta
	if is_loser:
		return Color(0.9, 0.2, 0.2, 0.8)
	if face_down:
		return Color(0.28, 0.42, 0.70)
	match die_type:
		Die.Type.LOADED:   return Color(0.65, 0.48, 0.22)
		Die.Type.CRYSTAL:  return Color(0.45, 0.80, 1.0)
		Die.Type.VAMPIRIC: return Color(0.85, 0.15, 0.20)
		Die.Type.WILDCARD: return Color(0.85, 0.65, 0.0)
		_:                 return Color(0.65, 0.60, 0.50)

# ── Dibujado ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	# 1. Sombra exterior
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	shadow.corner_radius_top_left = CORNER_R
	shadow.corner_radius_top_right = CORNER_R
	shadow.corner_radius_bottom_left = CORNER_R
	shadow.corner_radius_bottom_right = CORNER_R
	draw_style_box(shadow, Rect2(Vector2(4.0, 6.0), DIE_SIZE))

	# 2. Resplandor exterior si está resaltado
	if is_highlighted:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(1.0, 0.9, 0.3, 0.35)
		glow.corner_radius_top_left = CORNER_R + 3
		glow.corner_radius_top_right = CORNER_R + 3
		glow.corner_radius_bottom_left = CORNER_R + 3
		glow.corner_radius_bottom_right = CORNER_R + 3
		draw_style_box(glow, Rect2(Vector2(-3.0, -3.0), DIE_SIZE + Vector2(6.0, 6.0)))

	# 3. Cuerpo del dado
	var body := StyleBoxFlat.new()
	body.bg_color = _bg_color()
	body.corner_radius_top_left = CORNER_R
	body.corner_radius_top_right = CORNER_R
	body.corner_radius_bottom_left = CORNER_R
	body.corner_radius_bottom_right = CORNER_R
	var border_w: int = 3 if is_highlighted else 2
	body.border_width_left = border_w
	body.border_width_right = border_w
	body.border_width_top = border_w
	body.border_width_bottom = border_w
	body.border_color = _border_color()
	draw_style_box(body, Rect2(Vector2.ZERO, DIE_SIZE))

	if face_down:
		_draw_back_pattern()
	else:
		_draw_pips()
		_draw_type_indicator()

func _draw_back_pattern() -> void:
	# Patrón de rombo y puntos decorativo para el dorso
	var center := DIE_SIZE / 2.0
	var c_pattern := Color(0.35, 0.50, 0.80, 0.8)
	
	# Rombo central
	var diamond := PackedVector2Array([
		Vector2(center.x, center.y - 18),
		Vector2(center.x + 18, center.y),
		Vector2(center.x, center.y + 18),
		Vector2(center.x - 18, center.y)
	])
	draw_polyline(diamond, c_pattern, 2.0)
	draw_line(diamond[3], diamond[0], c_pattern, 2.0)
	
	# Puntos en las esquinas interiores
	var dots := [
		Vector2(0.28, 0.28), Vector2(0.72, 0.28),
		Vector2(0.28, 0.72), Vector2(0.72, 0.72),
		Vector2(0.5, 0.5)
	]
	for p in dots:
		draw_circle((p as Vector2) * DIE_SIZE, 3.5, c_pattern)

func _draw_pips() -> void:
	var usable := Rect2(PADDING, PADDING, DIE_SIZE.x - PADDING * 2.0, DIE_SIZE.y - PADDING * 2.0)
	var pip_c := _pip_color()
	
	for p in _pip_layout(face_value):
		var pos: Vector2 = usable.position + (p as Vector2) * usable.size
		# Sombra suave del pip
		draw_circle(pos + Vector2(0.5, 1.0), PIP_R, Color(0, 0, 0, 0.15))
		# Pip principal
		draw_circle(pos, PIP_R, pip_c)
		# Brillo interior del pip (estilo dados de casino)
		draw_circle(pos - Vector2(1.8, 1.8), PIP_R * 0.35, Color(1, 1, 1, 0.45))

func _draw_type_indicator() -> void:
	if die_type == Die.Type.NORMAL:
		return
	
	var badge_pos := Vector2(DIE_SIZE.x - 12.0, 12.0)
	var badge_c: Color
	match die_type:
		Die.Type.LOADED:   badge_c = Color(0.9, 0.6, 0.1)
		Die.Type.CRYSTAL:  badge_c = Color(0.3, 0.85, 1.0)
		Die.Type.VAMPIRIC: badge_c = Color(0.95, 0.2, 0.25)
		Die.Type.WILDCARD: badge_c = Color(1.0, 0.9, 0.1)
		_:                 badge_c = Color.WHITE
		
	draw_circle(badge_pos, 5.0, badge_c)
	draw_circle(badge_pos, 5.0, Color.WHITE, false, 1.5)

# ── Animaciones ────────────────────────────────────────────────────────────────

## Animación de bote al rodar dados con pequeño retardo
func play_roll_anim(delay: float = 0.0) -> void:
	scale = Vector2.ZERO
	rotation = randf_range(-0.3, 0.3)
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if delay > 0.0:
		t.tween_interval(delay)
	t.parallel().tween_property(self, "scale", Vector2.ONE, 0.28)
	t.parallel().tween_property(self, "rotation", 0.0, 0.28)

## Volteo tipo 3D de dorso a cara con efecto stagger
func play_reveal_anim(delay: float = 0.0) -> void:
	var t := create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_property(self, "scale", Vector2(0.05, 1.1), 0.12).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(func() -> void:
		face_down = false
	)
	t.tween_property(self, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Animación cuando el dado es eliminado de la mesa
func play_vanish_anim() -> void:
	is_loser = true
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2(0.0, 0.0), 0.35)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	t.parallel().tween_property(self, "rotation", 0.5, 0.35)
	t.tween_callback(queue_free)
