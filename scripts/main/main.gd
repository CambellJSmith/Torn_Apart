extends Node3D # Owns startup responsibilities for the playable prototype scene.

const INPUT_SETUP := preload("res://scripts/input/input_setup.gd") # Loads the input configuration utility once with the scene script.

func _enter_tree() -> void: # Prepares global runtime dependencies before child nodes begin gameplay processing.
	INPUT_SETUP.ensure_default_actions() # Ensures the expected keyboard and controller actions exist before the player reads input.
