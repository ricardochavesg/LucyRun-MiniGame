extends Area2D
 
 
func _ready() -> void:
	# Aseguramos el grupo aunque no se haya marcado en el editor
	add_to_group("Agua")
	body_entered.connect(_on_body_entered)
 
 
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and body.has_method("on_hazard_contact"):
		body.on_hazard_contact()
 
