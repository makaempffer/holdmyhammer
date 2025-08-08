extends Node3D
var current_area = null

func _process(delta):
	if current_area and Input.is_action_just_pressed("interact"):
		current_area.call("interact")  # if area has a method

func on_area_entered(area):
	current_area = area

func on_area_exited(area):
	if current_area == area:
		current_area = null
