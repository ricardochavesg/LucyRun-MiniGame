extends Area2D
 
 
func _ready() -> void:
	body_entered.connect(_on_body_entered)
 
 
func _on_body_entered(body: Node2D) -> void:
	print("KillZone tocado por: ", body.name)   # ← borra esta línea cuando funcione
 
	if not body.is_in_group("Player"):
		return
 
	if body.has_method("fall_kill"):
		body.fall_kill()
