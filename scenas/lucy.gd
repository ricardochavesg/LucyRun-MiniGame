## player_runner.gd ##
## PlayerRunner — Auto-runner + Flappy mode (Niveles 1-2-3 en una sola escena)
##
## ESCENA:
## PlayerRunner (CharacterBody2D)
## ├─ AnimatedSprite2D animaciones: walk, jump, fall, lucy_avion
## ├─ CollisionShape2D
## ├─ HitboxArea (Area2D) Mask: Layer 2 (Agua) + Layer 3 (Hazards)
## │   └─ CollisionShape2D
## ├─ AuraParticles (GPUParticles2D) puede ser null
## └─ WaterproofTimer (Timer)
##
## CAPAS:
## Layer 1 = World
## Layer 2 = Agua
## Layer 3 = Hazards
##
## GRUPOS:
## "Player"  → este nodo
## "Agua"    → zonas agua
## "hazards" → peligros

extends CharacterBody2D

# ── Señales ──────────────────────────────────────────────────────────────────

signal hit
signal lives_changed(new_lives: int)
signal waterproof_activated(time_left: float)
signal waterproof_expired
signal game_over

# ── Inspector: Movimiento ─────────────────────────────────────────────────────

@export_group("Movimiento")

@export var speed: float = 400.0
@export var jump_velocity: float = -520.0

## Impulso de aleteo en modo avión (más suave que el salto normal)
@export var flappy_velocity: float = -300.0

# ── Inspector: Física ─────────────────────────────────────────────────────────

@export_group("Física")

@export_range(0.5, 3.0, 0.1)
var gravity_scale: float = 1.0

@export_range(1.0, 3.0, 0.1)
var fall_gravity_multiplier: float = 1.6

# ── Inspector: Impermeabilidad ────────────────────────────────────────────────

@export_group("Impermeabilidad")

@export var waterproof_duration: float = 7.0

@export_range(1, 32, 1)
var agua_layer: int = 2

@export var waterproof_color: Color = Color(0.1, 0.55, 1.0, 1.0)

# ── Inspector: Vidas y Respawn ────────────────────────────────────────────────

@export_group("Vidas y Respawn")

@export var max_lives: int = 3
@export var override_spawn_position: Vector2 = Vector2.ZERO

@export_file("*.tscn")
var level_one_path: String = ""

# ── Estado ────────────────────────────────────────────────────────────────────

enum State {
	IDLE,
	JUMP,
	FALL,
	WATERPROOF,
	FLAPPY
}

var state: State = State.IDLE

# ── Runtime ───────────────────────────────────────────────────────────────────

var is_waterproof: bool = false
var lives: int = max_lives

var _spawn_position: Vector2
var _base_collision_mask: int

var _jump_requested: bool = false
var _is_dead: bool = false

var _flappy_unlocked: bool = false # persiste aunque muera — no se pierde el poder

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sprite_avion: AnimatedSprite2D = $AnimatedSprite2DAvion # nodo separado para el avión

@onready var waterproof_timer: Timer = $WaterproofTimer
@onready var hitbox_area: Area2D = $HitboxArea
@onready var aura_particles: GPUParticles2D = $AuraParticles # puede ser null

var _waterproof_tween: Tween
var _gravity: float

var _respawn_grace: bool = false # inmunidad breve post-respawn

# ════════════════════════════════════════════════════════════════════════════
# INIT
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("Player")

	lives = max_lives
	_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

	_spawn_position = override_spawn_position if override_spawn_position != Vector2.ZERO else global_position

	_base_collision_mask = collision_mask

	waterproof_timer.wait_time = waterproof_duration
	waterproof_timer.one_shot = true
	waterproof_timer.timeout.connect(_on_waterproof_expired)

	if hitbox_area:
		hitbox_area.area_entered.connect(_on_hitbox_area_entered)
		hitbox_area.body_entered.connect(_on_hitbox_body_entered)

	if aura_particles:
		aura_particles.emitting = false

	sprite_avion.visible = false

	hit.connect(_on_hit)

	call_deferred("_show_start_screen")

# ════════════════════════════════════════════════════════════════════════════
# INPUT
# ════════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if _is_dead:
		return

	if (event is InputEventScreenTouch and event.pressed) \
	or event.is_action_pressed("ui_accept"):
		_jump_requested = true

# ════════════════════════════════════════════════════════════════════════════
# PHYSICS PROCESS — rama por estado
# ════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if state == State.FLAPPY:
		_process_flappy(delta)
	else:
		_process_runner(delta)

# ── Runner (Niveles 1 y 2) ────────────────────────────────────────────────────

func _process_runner(delta: float) -> void:
	# Gravedad con multiplicador de caída
	if is_on_floor():
		velocity.y = 0.0
	else:
		var mult := fall_gravity_multiplier if velocity.y > 0.0 else 1.0
		velocity.y += _gravity * gravity_scale * mult * delta

	# Salto solo desde el suelo
	if is_on_floor() and _jump_requested:
		velocity.y = jump_velocity

	_jump_requested = false

	velocity.x = speed

	move_and_slide()

	_update_state()

# ── Flappy (Nivel 3) ──────────────────────────────────────────────────────────

func _process_flappy(delta: float) -> void:
	# Gravedad constante — sin multiplicador de caída (flappy clásico)
	velocity.y += _gravity * gravity_scale * delta

	velocity.x = speed

	# Aletazo: cualquier input da impulso hacia arriba, sin requisito de suelo
	if _jump_requested:
		velocity.y = flappy_velocity
		_jump_requested = false
		sprite_avion.play("lucy_avion")

	move_and_slide()

	# Inclinación según velocidad vertical — sube=nariz arriba, cae=nariz abajo
	var target_angle := clampf(velocity.y * 0.08, -35.0, 55.0)

	sprite_avion.rotation_degrees = lerpf(
		sprite_avion.rotation_degrees,
		target_angle,
		0.18
	)

	# Muerte al tocar pared o techo — suelo NO mata (puede aterrizar)
	if not _respawn_grace and (is_on_wall() or is_on_ceiling()):
		_handle_death()

# ════════════════════════════════════════════════════════════════════════════
# MÁQUINA DE ESTADOS (solo para el modo runner)
# ════════════════════════════════════════════════════════════════════════════

func _update_state() -> void:
	var new_state: State

	if is_waterproof:
		new_state = State.WATERPROOF
	elif is_on_floor():
		new_state = State.IDLE
	elif velocity.y < 0.0:
		new_state = State.JUMP
	else:
		new_state = State.FALL

	if new_state != state:
		_on_state_changed(state, new_state)

	state = new_state

func _on_state_changed(_from: State, to: State) -> void:
	match to:
		State.IDLE:
			sprite.play("walk")

		State.JUMP:
			sprite.play("jump")

		State.FALL:
			if sprite.sprite_frames.has_animation("fall"):
				sprite.play("fall")

		State.WATERPROOF:
			sprite.play("walk")

	# FLAPPY no pasa por aquí — se gestiona en _process_flappy

# ════════════════════════════════════════════════════════════════════════════
# MODO AVIÓN — API PÚBLICA (llamado por avion_pickup.gd)
# ════════════════════════════════════════════════════════════════════════════

func enable_flappy_mode() -> void:
	if _flappy_unlocked:
		return

	_flappy_unlocked = true

	state = State.FLAPPY

	velocity.y = flappy_velocity

	sprite.visible = false

	sprite_avion.visible = true
	sprite_avion.rotation_degrees = 0.0
	sprite_avion.play("lucy_avion")

# ════════════════════════════════════════════════════════════════════════════
# IMPERMEABILIDAD
# ════════════════════════════════════════════════════════════════════════════

func activate_waterproof() -> void:
	is_waterproof = true

	waterproof_timer.start(waterproof_duration)

	collision_mask = _base_collision_mask | (1 << (agua_layer - 1))

	if _waterproof_tween:
		_waterproof_tween.kill()

	sprite.modulate = Color.WHITE

	_waterproof_tween = create_tween().set_loops()

	_waterproof_tween.tween_property(
		sprite,
		"modulate",
		waterproof_color,
		0.4
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_waterproof_tween.tween_property(
		sprite,
		"modulate",
		waterproof_color.lightened(0.4),
		0.4
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if aura_particles:
		aura_particles.emitting = true

	waterproof_activated.emit(waterproof_duration)

func _on_waterproof_expired() -> void:
	is_waterproof = false

	collision_mask = _base_collision_mask

	if _waterproof_tween:
		_waterproof_tween.kill()

	_waterproof_tween = null

	create_tween().tween_property(
		sprite,
		"modulate",
		Color.WHITE,
		0.3
	).set_trans(Tween.TRANS_SINE)

	if aura_particles:
		aura_particles.emitting = false

	waterproof_expired.emit()

# ════════════════════════════════════════════════════════════════════════════
# DETECCIÓN DE PELIGROS
# ════════════════════════════════════════════════════════════════════════════

func _on_hitbox_area_entered(area: Area2D) -> void:
	# En flappy: el agua y los hazards matan
	# (sin inmunidad impermeable en modo avión)
	if state == State.FLAPPY:
		if area.is_in_group("Agua") or area.is_in_group("hazards"):
			_handle_death()
		return

	# Modo runner: el impermeable protege
	if is_waterproof:
		return

	if area.is_in_group("Agua") or area.is_in_group("hazards"):
		hit.emit()

func _on_hitbox_body_entered(body: Node2D) -> void:
	# La manguera tiene un StaticBody2D en Layer 2
	# — en flappy mata si toca
	if state == State.FLAPPY and body.is_in_group("hazards"):
		_handle_death()

func on_hazard_contact() -> void:
	if state == State.FLAPPY:
		_handle_death()
		return

	if is_waterproof:
		return

	hit.emit()

func fall_kill() -> void:
	_handle_death()

# ════════════════════════════════════════════════════════════════════════════
# VIDAS, MUERTE Y RESPAWN
# ════════════════════════════════════════════════════════════════════════════

func _on_hit() -> void:
	_handle_death()

func _handle_death() -> void:
	if _is_dead:
		return

	_is_dead = true

	_flappy_unlocked = false # pierde el poder al morir

	lives -= 1
	lives_changed.emit(lives)

	if lives <= 0:
		_show_game_over()
	else:
		_start_respawn()

func _start_respawn() -> void:
	_respawn_grace = true # activa inmunidad ANTES de mover

	if hitbox_area:
		hitbox_area.monitoring = false

	get_tree().paused = true

	_reset_to_checkpoint()

	_show_resume_button()

func _reset_to_checkpoint() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO

	# _flappy_unlocked ya es false (se perdió al morir)
	# → siempre vuelve en runner
	if _flappy_unlocked:
		state = State.FLAPPY

		sprite.visible = false

		sprite_avion.visible = true
		sprite_avion.rotation_degrees = 0.0
		sprite_avion.play("lucy_avion")
	else:
		state = State.IDLE

		sprite.visible = true

		sprite_avion.visible = false
		sprite_avion.rotation_degrees = 0.0

	# Resetea pickups del nivel
	# (excepto el avión — ya está desbloqueado)
	for pickup in get_tree().get_nodes_in_group("respawnable_pickup"):
		if pickup.has_method("reset_pickup"):
			pickup.reset_pickup()

func _show_resume_button() -> void:
	var canvas := CanvasLayer.new()

	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.layer = 99

	var bg := ColorRect.new()

	bg.color = Color(0.0, 0.0, 0.0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	canvas.add_child(bg)

	var btn := Button.new()

	btn.text = "▶ CONTINUAR"
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.custom_minimum_size = Vector2(260, 80)

	btn.add_theme_font_size_override("font_size", 30)

	btn.set_anchors_preset(Control.PRESET_CENTER)
	btn.position -= Vector2(130, 40)

	canvas.add_child(btn)

	get_tree().root.add_child(canvas)

	btn.pressed.connect(
		func() -> void:
			_is_dead = false

			get_tree().paused = false

			canvas.queue_free()

			# Reactivamos detección un frame después
			# — física ya está en posición limpia
			if hitbox_area:
				hitbox_area.set_deferred("monitoring", true)

			# Quitamos la gracia también deferred
			# — garantiza al menos 1 frame seguro
			set_deferred("_respawn_grace", false),
		CONNECT_DEFERRED
	)

func _show_start_screen() -> void:
	_show_overlay(
		"¡A JUGAR!",
		" INICIAR ",
		func(canvas: CanvasLayer) -> void:
			canvas.queue_free()
			get_tree().paused = false
	)

	get_tree().paused = true

func _show_game_over() -> void:
	game_over.emit()

	_show_overlay(
		"¡INTÉNTALO\nDE NUEVO!",
		"JUGAR DE NUEVO",
		func(canvas: CanvasLayer) -> void:
			get_tree().paused = false
			canvas.queue_free()

			# Reset completo — ignoramos checkpoints
			_flappy_unlocked = false

			_spawn_position = override_spawn_position if override_spawn_position != Vector2.ZERO else global_position

			if level_one_path.is_empty():
				get_tree().reload_current_scene()
			else:
				get_tree().change_scene_to_file(level_one_path)
	)

	get_tree().paused = true

## Pantalla reutilizable: inicio, game over, ganaste
## on_press recibe el canvas para que el callback lo libere como quiera

func _show_overlay(
	title: String,
	button_label: String,
	on_press: Callable
) -> void:
	var canvas := CanvasLayer.new()

	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.layer = 100

	var bg := ColorRect.new()

	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	canvas.add_child(bg)

	var box := VBoxContainer.new()

	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(360, 180)
	box.position -= Vector2(180, 90)

	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)

	canvas.add_child(box)

	var label := Label.new()

	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)

	box.add_child(label)

	var btn := Button.new()

	btn.text = button_label
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.custom_minimum_size = Vector2(240, 70)

	btn.add_theme_font_size_override("font_size", 26)

	box.add_child(btn)

	get_tree().root.add_child(canvas)

	btn.pressed.connect(
		func() -> void:
			on_press.call(canvas),
		CONNECT_DEFERRED
	)

# ── Checkpoint API ────────────────────────────────────────────────────────────

func set_checkpoint(new_pos: Vector2) -> void:
	_spawn_position = new_pos
