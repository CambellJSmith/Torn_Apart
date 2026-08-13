extends Node3D # Follows the player independently from player movement.
class_name TornCameraRig # Gives the camera rig a strongly typed project-wide class name.

const FOLLOW_SHARPNESS: float = 7.5 # Controls how quickly the rig catches the player position.
const LOOK_HEIGHT: float = 0.9 # Places vertical focus near the paper character's visual center.
@onready var _camera: Camera3D = $Camera3D # Caches the owned camera.
var _target: TornPlayerController = null # Stores the composed player target.
var _level: TornLevelContext = null # Stores the active level camera bounds.

func _ready() -> void: # Prepares manual interpolation before composition.
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF) # Keeps this rendered-frame rig manually interpolated.
	set_process(false) # Prevents updates before dependencies are valid.

func configure(target: TornPlayerController, level: TornLevelContext) -> void: # Supplies player and level dependencies.
	_target = target # Stores the player explicitly.
	_level = level # Stores the active level explicitly.
	var initial_position: Vector3 = _target.global_position # Reads the authored player spawn.
	global_position = _get_target_rig_position(initial_position) # Starts at the clamped anchor.
	_aim_camera(initial_position.y) # Aims before the first rendered update.
	set_process(true) # Enables smooth following after composition.

func _process(delta: float) -> void: # Smoothly follows the interpolated player position.
	var target_position: Vector3 = _target.get_global_transform_interpolated().origin # Reads the render-interpolated player position once.
	var desired_position: Vector3 = _get_target_rig_position(target_position) # Calculates the level-clamped anchor.
	var blend_weight: float = 1.0 - exp(-FOLLOW_SHARPNESS * delta) # Builds stable frame-rate-independent smoothing.
	global_position = global_position.lerp(desired_position, blend_weight) # Smoothly catches the clamped anchor.
	_aim_camera(target_position.y) # Tracks jump height without swinging horizontally at camera bounds.

func _get_target_rig_position(target_position: Vector3) -> Vector3: # Converts player position into a ground-plane camera anchor.
	var desired_anchor: Vector3 = Vector3(target_position.x, 0.0, target_position.z) # Ignores jump height for rig translation.
	if _level == null: # Keeps isolated camera tests usable without a level.
		return desired_anchor # Returns the unclamped anchor.
	return _level.clamp_camera_anchor(desired_anchor) # Applies the active level's XZ bounds.

func _aim_camera(target_height: float) -> void: # Keeps horizontal orientation stable while following vertical player motion.
	var look_target: Vector3 = Vector3(global_position.x, target_height + LOOK_HEIGHT, global_position.z) # Uses the clamped rig anchor horizontally and player height vertically.
	_camera.look_at(look_target, Vector3.UP) # Applies the stable bounded camera orientation.
