## impermeable_pickup.gd
## ImpermeablePickup — Area2D
## Grupo: "respawnable_pickup" (el player lo reactiva al hacer respawn)

extends Area2D

@export var bob_amplitude: float = 6.0
@export var bob_speed: float     = 2.0

var _origin_y: float
var _collected: bool = false


func _ready() -> void:
	add_to_group("respawnable_pickup")
	_origin_y = position.y
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	if _collected:
		return
	position.y = _origin_y + sin(Time.get_ticks_msec() * 0.001 * bob_speed) * bob_amplitude


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("Player"):
		return

	if body.has_method("activate_waterproof"):
		body.activate_waterproof()

	_collected = true
	visible    = false
	set_deferred("monitoring", false)   # apaga detección sin error


## Llamado por el player al hacer respawn
func reset_pickup() -> void:
	_collected = false
	visible    = true
	monitoring = true
