## avion_pickup.gd
## Avión de papel — Area2D
## Activa el modo FLAPPY en el Player al tocarlo.
## NO pertenece al grupo "respawnable_pickup" porque el poder persiste.
##
## ESCENA:
##   AvionPickup (Area2D)  ← este script
##     ├─ AnimatedSprite2D   (animación "idle" — avión flotando)
##     └─ CollisionShape2D

extends Area2D

@export var bob_amplitude : float = 5.0
@export var bob_speed     : float = 2.2
@export var tilt_degrees  : float = 8.0

var _origin_y   : float
var _origin_rot : float
var _collected  : bool = false


func _ready() -> void:
	add_to_group("respawnable_pickup")   # reaparece al hacer respawn
	_origin_y   = position.y
	_origin_rot = rotation
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	if _collected:
		return
	var t := Time.get_ticks_msec() * 0.001
	position.y = _origin_y + sin(t * bob_speed) * bob_amplitude
	rotation   = _origin_rot + deg_to_rad(sin(t * bob_speed * 0.7) * tilt_degrees)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("Player"):
		return
	if not body.has_method("enable_flappy_mode"):
		return
	_collected = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)\
		.set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(func() -> void:
		body.enable_flappy_mode()
		visible    = false
		monitoring = false
	)


func reset_pickup() -> void:
	_collected        = false
	visible           = true
	scale             = Vector2.ONE
	modulate.a        = 1.0
	position.y        = _origin_y
	rotation          = _origin_rot
	monitoring        = true
