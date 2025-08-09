# ForgeComboHUD.gd
extends CanvasLayer

@onready var progress: ProgressBar = $Control/MarginContainer/VBoxContainer/Progress

func show_hud():
	visible = true

func hide_hud():
	visible = false

func init_progress_bar(max):
	progress.min_value = 0
	progress.max_value = max

func set_progress(progress_amount):
	progress.value = progress_amount

func reset_combo():
	progress.value = 0

func add_hit(judgment: int):
	pass
