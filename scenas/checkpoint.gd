extends Area2D
 
signal checkpoint_reached(position: Vector2)
 
var _activated: bool = false
 
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
 
 
func _ready() -> void:
	body_entered.connect(_on_body_entered)
 
	if anim_sprite:
		anim_sprite.play("idle")
 
 
func _on_body_entered(body: Node2D) -> void:
	if _activated or not body.is_in_group("Player"):
		return
 
	_activated = true
 
	if body.has_method("set_checkpoint"):
		body.set_checkpoint(global_position)
 
	checkpoint_reached.emit(global_position)
 
	if anim_sprite:
		anim_sprite.play("activated")
 
