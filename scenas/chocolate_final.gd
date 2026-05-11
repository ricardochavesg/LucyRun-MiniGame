## chocolate_final.gd
## Chocolate Final — Area2D
##
## ESCENA:
##   ChocolateFinal (Area2D)  ← este script
##     ├─ Sprite2D            (tu sprite del chocolate — ponlo grande)
##     ├─ CollisionShape2D
##     └─ SparkleParticles (CPUParticles2D)  — generado por código si no existe

extends Area2D

@export_group("Visual")
@export var bob_amplitude : float = 7.0
@export var bob_speed     : float = 1.8
@export var pulse_scale   : Vector2 = Vector2(1.15, 1.15)  # tamaño del pulso de brillo

@export_group("Pantalla de Victoria")
@export_file("*.tscn") var restart_scene: String = ""

@onready var sprite : Sprite2D = $Sprite2D

var _origin_y    : float
var _collected   : bool = false
var _pulse_tween : Tween


func _ready() -> void:
	_origin_y = position.y
	_setup_sparkles()
	_start_pulse()
	body_entered.connect(_on_body_entered)


# ── Flotación ─────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if _collected:
		return
	position.y = _origin_y + sin(Time.get_ticks_msec() * 0.001 * bob_speed) * bob_amplitude


# ── Partículas de brillo alrededor ───────────────────────────────────────────
func _setup_sparkles() -> void:
	# Busca el nodo si existe en la escena; si no, lo crea por código
	var existing := get_node_or_null("SparkleParticles")
	if existing:
		return

	var p := CPUParticles2D.new()
	p.name                     = "SparkleParticles"
	p.amount                   = 24
	p.lifetime                 = 1.2
	p.explosiveness            = 0.0
	p.randomness               = 0.6
	p.emission_shape           = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius   = sprite.texture.get_width() * sprite.scale.x * 0.55 \
								 if sprite and sprite.texture else 40.0
	p.direction                = Vector2(0.0, -1.0)
	p.spread                   = 180.0
	p.gravity                  = Vector2.ZERO
	p.initial_velocity_min     = 18.0
	p.initial_velocity_max     = 42.0
	p.scale_amount_min         = 2.0
	p.scale_amount_max         = 5.0

	# Degradado dorado → blanco → transparente
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.92, 0.2, 1.0))   # dorado
	grad.add_point(0.4, Color(1.0, 1.0, 1.0, 1.0))  # blanco
	grad.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))  # transparente
	p.color_ramp = grad

	add_child(p)


# ── Pulso de escala del sprite ────────────────────────────────────────────────
func _start_pulse() -> void:
	if not sprite:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(sprite, "scale", pulse_scale, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(sprite, "scale", Vector2.ONE, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ── Contacto con el Player ────────────────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("Player"):
		return
	_collected = true

	if _pulse_tween:
		_pulse_tween.kill()

	# Tween de celebración: crece y se va
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "scale", Vector2(2.2, 2.2), 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.35)\
		.set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(_show_win_screen)


# ── Pantalla de victoria ──────────────────────────────────────────────────────
func _show_win_screen() -> void:
	var canvas := CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.layer        = 100

	# Fondo festivo oscuro
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.0, 0.12, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	# Confeti centrado en pantalla — posición fija, no usa anchors (no es Control)
	var confeti := CPUParticles2D.new()
	confeti.position            = Vector2(ProjectSettings.get_setting("display/window/size/viewport_width") * 0.5,
										 ProjectSettings.get_setting("display/window/size/viewport_height") * 0.3)
	confeti.amount              = 80
	confeti.lifetime            = 3.0
	confeti.one_shot            = true
	confeti.explosiveness       = 0.7
	confeti.spread              = 180.0
	confeti.gravity             = Vector2(0.0, 120.0)
	confeti.initial_velocity_min = 180.0
	confeti.initial_velocity_max = 340.0
	confeti.scale_amount_min    = 4.0
	confeti.scale_amount_max    = 9.0
	var cg := Gradient.new()
	cg.colors  = [Color.YELLOW, Color.HOT_PINK, Color.CYAN, Color.LIME_GREEN, Color.ORANGE]
	cg.offsets = [0.0, 0.25, 0.5, 0.75, 1.0]
	confeti.color_ramp = cg
	canvas.add_child(confeti)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(380, 200)
	box.position           -= Vector2(190, 100)
	box.alignment           = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	canvas.add_child(box)

	var title := Label.new()
	title.text                                    = "🏆 ¡GANASTE! 🏆"
	title.horizontal_alignment                    = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.2))
	box.add_child(title)

	var sub := Label.new()
	sub.text                                    = "¡FELICIDADES!"
	sub.horizontal_alignment                    = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(sub)

	var btn := Button.new()
	btn.text                              = "🔄  JUGAR DE NUEVO"
	btn.process_mode                      = Node.PROCESS_MODE_ALWAYS
	btn.custom_minimum_size               = Vector2(280, 72)
	btn.add_theme_font_size_override("font_size", 24)
	box.add_child(btn)

	get_tree().root.add_child(canvas)

	# Disparamos el confeti DESPUÉS de añadir al árbol
	confeti.restart()

	get_tree().paused = true

	btn.pressed.connect(func() -> void:
		get_tree().paused = false
		canvas.queue_free()
		if restart_scene.is_empty():
			get_tree().reload_current_scene()
		else:
			get_tree().change_scene_to_file(restart_scene)
	, CONNECT_DEFERRED)
