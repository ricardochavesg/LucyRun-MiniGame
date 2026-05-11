## manguera.gd
## Manguera (WaterStream) — Node2D
##
## ESCENA:
##   Manguera (Node2D)  ← este script
##     ├─ DamageArea (Area2D)
##     └─ Platform (StaticBody2D)
##
## Rotá el Node2D desde el editor para apuntar el chorro.
## 0° = hacia abajo. Todo el visual y partículas se generan por código.

extends Node2D

@export_group("Dimensiones")
@export var stream_length : float = 200.0
@export var stream_width  : float = 22.0

@export_group("Visual Pixel Art")
@export var stream_color   : Color = Color(0.18, 0.52, 1.0,  0.90)
@export var highlight_color: Color = Color(0.65, 0.88, 1.0,  0.80)
@export var dark_color     : Color = Color(0.08, 0.25, 0.70, 0.90)
@export var splash_color   : Color = Color(0.55, 0.82, 1.0,  1.00)
## Velocidad de scroll de las rayas internas (px/s)
@export var flow_speed     : float = 120.0
## Tamaño de cada "cubito" pixel art
@export var cube_size      : int   = 4

@export_group("Capas de Física")
@export_range(1, 32, 1) var agua_layer  : int = 2
@export_range(1, 32, 1) var damage_layer: int = 3

# ── Nodos generados en _ready ─────────────────────────────────────────────
@onready var damage_area: Area2D       = $DamageArea
@onready var platform   : StaticBody2D = $Platform

# ── Partículas (creadas por código) ──────────────────────────────────────
var _flow_particles   : CPUParticles2D   # cubitos que bajan por el chorro
var _splash_particles : CPUParticles2D   # splash en la punta

# ── Runtime ───────────────────────────────────────────────────────────────
var _time : float = 0.0          # reloj para el scroll de rayas
var _cube_tex : ImageTexture     # textura 4×4 blanca reutilizable


# ═══════════════════════════════════════════════════════════════════════════
# INIT
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_cube_tex = _make_square_tex(cube_size)
	_setup_shapes()
	_setup_layers()
	_setup_flow_particles()
	_setup_splash_particles()
	damage_area.body_entered.connect(_on_damage_body_entered)


# ── Textura cuadrada pixel art ────────────────────────────────────────────
func _make_square_tex(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


# ── Colisiones ────────────────────────────────────────────────────────────
func _setup_shapes() -> void:
	var offset := Vector2(0.0, stream_length * 0.5)

	for body in [damage_area, platform]:
		var shape      := RectangleShape2D.new()
		shape.size      = Vector2(stream_width, stream_length)
		var col        := CollisionShape2D.new()
		col.shape       = shape
		col.position    = offset
		body.add_child(col)


func _setup_layers() -> void:
	platform.collision_layer    = 1 << (agua_layer   - 1)
	platform.collision_mask     = 0
	damage_area.collision_layer = 1 << (damage_layer - 1)
	damage_area.collision_mask  = 1


# ── Partículas del flujo (cubitos bajando) ────────────────────────────────
func _setup_flow_particles() -> void:
	_flow_particles               = CPUParticles2D.new()
	_flow_particles.texture       = _cube_tex
	_flow_particles.amount        = 18
	_flow_particles.lifetime      = stream_length / flow_speed
	_flow_particles.explosiveness = 0.0
	_flow_particles.randomness    = 0.25

	# Emisor: línea horizontal en la boca del chorro
	_flow_particles.emission_shape      = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_flow_particles.emission_rect_extents = Vector2(stream_width * 0.35, 1.0)
	_flow_particles.position            = Vector2(0.0, 2.0)   # boca

	# Dirección: hacia abajo (local → heredada por la rotación del Node2D)
	_flow_particles.direction           = Vector2(0.0, 1.0)
	_flow_particles.spread              = 4.0
	_flow_particles.gravity             = Vector2.ZERO
	_flow_particles.initial_velocity_min = flow_speed * 0.85
	_flow_particles.initial_velocity_max = flow_speed * 1.15

	# Escala pixel art — sin suavizado
	_flow_particles.scale_amount_min    = 1.0
	_flow_particles.scale_amount_max    = 1.8

	# Paleta azul: oscuro → claro → transparente
	var grad := Gradient.new()
	grad.set_color(0, highlight_color)
	grad.add_point(0.5,  stream_color)
	grad.add_point(0.85, dark_color)
	grad.add_point(1.0,  Color(stream_color.r, stream_color.g, stream_color.b, 0.0))
	_flow_particles.color_ramp = grad

	add_child(_flow_particles)


# ── Partículas de splash (en la punta) ───────────────────────────────────
func _setup_splash_particles() -> void:
	_splash_particles               = CPUParticles2D.new()
	_splash_particles.texture       = _cube_tex
	_splash_particles.amount        = 12
	_splash_particles.lifetime      = 0.45
	_splash_particles.explosiveness = 0.6
	_splash_particles.randomness    = 0.5
	_splash_particles.position      = Vector2(0.0, stream_length)  # punta

	# Salen en abanico hacia los lados (efecto impacto)
	_splash_particles.direction     = Vector2(0.0, 1.0)
	_splash_particles.spread        = 75.0
	_splash_particles.gravity       = Vector2(0.0, 180.0)
	_splash_particles.initial_velocity_min = 40.0
	_splash_particles.initial_velocity_max = 90.0
	_splash_particles.scale_amount_min = 0.8
	_splash_particles.scale_amount_max = 1.6

	var sg := Gradient.new()
	sg.set_color(0, splash_color)
	sg.add_point(1.0, Color(splash_color.r, splash_color.g, splash_color.b, 0.0))
	_splash_particles.color_ramp = sg

	add_child(_splash_particles)


# ═══════════════════════════════════════════════════════════════════════════
# PROCESO
# ═══════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()   # redibuja cada frame para el scroll de rayas


# ═══════════════════════════════════════════════════════════════════════════
# VISUAL — _draw() pixel art con rayas animadas
# ═══════════════════════════════════════════════════════════════════════════

func _draw() -> void:
	var hw     := stream_width * 0.5
	var length := stream_length

	# ── 1. Cuerpo oscuro (sombra interna) ────────────────────────────────
	draw_rect(Rect2(-hw, 0.0, stream_width, length), dark_color)

	# ── 2. Relleno principal scrolleado por cubos ─────────────────────────
	# Dividimos el chorro en "cubos" de (cube_size × cube_size) que se alternan
	# entre stream_color y highlight_color para simular movimiento de píxel.
	var cs     := float(cube_size)
	var cols   := int(stream_width  / cs)
	var rows   := int(stream_length / cs) + 2
	var scroll := fmod(_time * flow_speed, cs * 2.0)

	for row in range(rows):
		for col in range(cols):
			var x := -hw + col * cs
			var y := row * cs - scroll
			if y + cs < 0.0 or y > length:
				continue
			# Patrón de tablero para alternar colores
			var is_highlight := (row + col) % 2 == 0
			var c := highlight_color if is_highlight else stream_color
			# Clip manual: no salir del largo del chorro
			var draw_y      := maxf(y, 0.0)
			var draw_height := minf(y + cs, length) - draw_y
			if draw_height > 0.0:
				draw_rect(Rect2(x, draw_y, cs, draw_height), c)

	# ── 3. Borde izquierdo (foam claro) ──────────────────────────────────
	draw_rect(Rect2(-hw, 0.0, cs, length), highlight_color)

	# ── 4. Borde derecho (sombra) ─────────────────────────────────────────
	draw_rect(Rect2(hw - cs, 0.0, cs, length), dark_color)

	# ── 5. Rayas de brillo diagonal que bajan (efecto corriente) ──────────
	var stripe_offset := fmod(_time * flow_speed * 0.6, length)
	for i in range(3):
		var sy := stripe_offset + i * (length / 3.0)
		if sy > length:
			sy -= length
		var alpha  := 0.35
		var s_col  := Color(1.0, 1.0, 1.0, alpha)
		draw_rect(Rect2(-hw + cs, sy, stream_width - cs * 2.0, cs), s_col)

	# ── 6. Boca del chorro — rectángulo más brillante ─────────────────────
	draw_rect(Rect2(-hw, 0.0, stream_width, cs * 2.0), highlight_color)


# ═══════════════════════════════════════════════════════════════════════════
# DAÑO
# ═══════════════════════════════════════════════════════════════════════════

func _on_damage_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if body.has_method("on_hazard_contact"):
		body.on_hazard_contact()
