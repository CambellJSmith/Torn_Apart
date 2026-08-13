extends Node3D # Owns startup composition for the persistent player, active isolated level, camera, and UI.

const INPUT_SETUP := preload("res://scripts/input/input_setup.gd") # Loads the input configuration utility once.
@onready var _player: TornPlayerController = $player # Caches the persistent player.
@onready var _active_level: TornLevelContext = $active_level # Caches the active isolated level contract.
@onready var _camera_rig: TornCameraRig = $camera_rig # Caches the persistent follow camera.
@onready var _interaction_prompt: TornInteractionPrompt = $ui/interaction_prompt # Caches the persistent interaction prompt.

func _enter_tree() -> void: # Prepares input before child gameplay processing begins.
	INPUT_SETUP.ensure_default_actions() # Ensures expected keyboard and controller actions exist.

func _ready() -> void: # Connects persistent systems through direct composition.
	_player.configure_level(_active_level) # Gives the player level-owned spawn and recovery rules.
	_player.configure_interaction_ui(_interaction_prompt) # Gives interaction targeting persistent prompt UI.
	_camera_rig.configure(_player, _active_level) # Gives the camera explicit player and level dependencies.
