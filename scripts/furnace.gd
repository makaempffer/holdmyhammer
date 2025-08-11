extends MeshInstance3D

var powered: bool = false

@onready var fire: Node3D = $Fire

func _ready():
	fire.play_fire_sound()
