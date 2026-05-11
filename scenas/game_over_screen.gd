extends CanvasLayer
 
## Ruta del Nivel 1 — deja vacío para recargar la escena actual
@export_file("*.tscn") var level_one_path: String = ""
 
@onready var panel:        Panel  = $Panel
@onready var retry_button: Button = $Panel/VBoxContainer/RetryButton
 
 
func _ready() -> void:
	# Este nodo SIEMPRE procesa aunque el árbol esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
 
	# El árbol ya viene pausado desde el player — nos aseguramos
	get_tree().paused = true
 
	retry_button.pressed.connect(_on_retry_pressed)
 
	# Animación de entrada
	panel.modulate.a = 0.0
	panel.scale      = Vector2(0.85, 0.85)
 
	var tween := create_tween().set_parallel(true)
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)  # corre aunque esté pausado
	tween.tween_property(panel, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
 
 
func _on_retry_pressed() -> void:
	get_tree().paused = false
 
	if level_one_path.is_empty():
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(level_one_path)
 
