extends CanvasLayer
 
@export var heart_full: Texture2D
@export var heart_empty: Texture2D
@export var max_lives: int = 3
 
@onready var lives_container: HBoxContainer = $LivesContainer
@onready var waterproof_bar: ProgressBar     = $WaterproofBar
 
var _player: CharacterBody2D
var _waterproof_timer_ref: Timer
var _waterproof_total: float = 7.0
 
 
func _ready() -> void:
	waterproof_bar.visible = false
 
	# Esperamos un frame para que el player exista en el árbol
	await get_tree().process_frame
	_connect_player()
 
 
func _connect_player() -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		push_warning("HudRunner: no se encontró nodo en grupo 'Player'")
		return
 
	_player = players[0] as CharacterBody2D
 
	_player.lives_changed.connect(_on_lives_changed)
	_player.waterproof_activated.connect(_on_waterproof_activated)
	_player.waterproof_expired.connect(_on_waterproof_expired)
 
	# Referencia al timer del player para la barra de progreso
	_waterproof_timer_ref = _player.get_node_or_null("WaterproofTimer")
 
	_refresh_hearts(_player.lives)
 
 
func _process(_delta: float) -> void:
	# Actualiza la barra de impermeabilidad en tiempo real
	if waterproof_bar.visible and _waterproof_timer_ref:
		var t := _waterproof_timer_ref.time_left / _waterproof_total
		waterproof_bar.value = t * 100.0
 
 
# ── Corazones ─────────────────────────────────────────────────────────────
 
func _refresh_hearts(current_lives: int) -> void:
	var hearts := lives_container.get_children()
	for i in range(hearts.size()):
		var heart := hearts[i] as TextureRect
		if heart == null:
			continue
		heart.texture = heart_full if i < current_lives else heart_empty
 
 
func _on_lives_changed(new_lives: int) -> void:
	_refresh_hearts(new_lives)
 
	# Feedback de parpadeo rápido en el corazón perdido
	var hearts := lives_container.get_children()
	if new_lives < hearts.size():
		var lost_heart := hearts[new_lives] as TextureRect
		if lost_heart:
			var tween := create_tween().set_loops(4)
			tween.tween_property(lost_heart, "modulate:a", 0.0, 0.1)
			tween.tween_property(lost_heart, "modulate:a", 1.0, 0.1)
 
 
# ── Barra Impermeable ─────────────────────────────────────────────────────
 
func _on_waterproof_activated(duration: float) -> void:
	_waterproof_total = duration
	waterproof_bar.value = 100.0
	waterproof_bar.visible = true
 
 
func _on_waterproof_expired() -> void:
	waterproof_bar.visible = false
 
