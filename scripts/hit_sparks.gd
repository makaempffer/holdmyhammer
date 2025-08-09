extends Node3D

@onready var debris: GPUParticles3D = $Debris
@onready var smoke: GPUParticles3D = $Smoke
@onready var metal_hit_sound: AudioStreamPlayer3D = $MetalHitSound
@onready var fire: GPUParticles3D = $Fire

func hit():
	debris.emitting = true
	smoke.emitting = false
	fire.emitting = false
	metal_hit_sound.pitch_scale = randf_range(0.9, 1.1)
	metal_hit_sound.volume_db = randf_range(0.9, 1.1)
	metal_hit_sound.play()
	await get_tree().create_timer(2.0).timeout
	queue_free()
