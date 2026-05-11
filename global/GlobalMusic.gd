extends Node

var music_player: AudioStreamPlayer

func _ready() -> void:
	# Configuramos el reproductor de audio
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	# Cargamos tu archivo de música (asegúrate de que la ruta sea correcta)
	var stream = load("" ) 
	music_player.stream = stream
	
	# Configuración para bucle infinito y persistencia
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS # No se detiene si el juego se pausa
	music_player.autoplay = true
	
	# Reproducir
	music_player.play()

func play_music():
	if not music_player.playing:
		music_player.play()

func stop_music():
	music_player.stop()
