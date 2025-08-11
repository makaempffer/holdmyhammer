extends Node3D
@onready var fire_sound: AudioStreamPlayer3D = $FireSound


func play_fire_sound():
	if fire_sound and not fire_sound.playing:
		fire_sound.play()
