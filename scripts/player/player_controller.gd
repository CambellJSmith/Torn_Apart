extends CharacterBody3D # Uses Godot's character body for controlled 3D movement and collision.
class_name TornPlayerController # Gives the player controller a strongly typed project-wide class name.

const MOVE_SPEED: float = 5.5 # Defines horizontal traversal speed.
const GROUND_ACCELERATION: float = 32.0 # Defines how quickly grounded movement reaches the requested speed.
const AIR_ACCELERATION: float = 10.0 # Defines how much directional control remains while airborne.
const JUMP_VELOCITY: float = 6.4 # Defines the upward launch speed for jumping.
const FALL_GRAVITY_MULTIPLIER: float = 1.35 # Makes the descending half of a jump feel more responsive.
const STICK_LEFT_NORTH: StringName = &"StickLeft_North" # References the north movement input action.
const STICK_LEFT_SOUTH: StringName = &"StickLeft_South" # References the south movement input action.
const STICK_LEFT_WEST: StringName = &"StickLeft_West" # References the west movement input action.
const STICK_LEFT_EAST: StringName = &"StickLeft_East" # References the east movement input action.
const BUTTON_A: StringName = &"Button_A" # References the jump input action.
const BUTTON_X: StringName = &"Button_X" # References the interaction-pose input action.

@onready var _paper_visual: TornPaperVisual = $paper_visual # Caches the composed paper visual controller.

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity")) # Reads the project's configured 3D gravity once for physics calculations.

func _physics_process(delta: float) -> void: # Advances movement at the fixed physics cadence.
	var input_vector: Vector2 = Input.get_vector(STICK_LEFT_WEST, STICK_LEFT_EAST, STICK_LEFT_NORTH, STICK_LEFT_SOUTH) # Combines keyboard or gamepad movement into one normalized vector.
	var requested_velocity: Vector3 = Vector3(input_vector.x, 0.0, input_vector.y) * MOVE_SPEED # Converts two-axis input into ground-plane velocity.
	var acceleration: float = GROUND_ACCELERATION # Starts with grounded acceleration for responsive movement.
	if not is_on_floor(): # Detects when the player is airborne.
		acceleration = AIR_ACCELERATION # Reduces steering authority while airborne.
	velocity.x = move_toward(velocity.x, requested_velocity.x, acceleration * delta) # Accelerates horizontal movement toward the requested X speed.
	velocity.z = move_toward(velocity.z, requested_velocity.z, acceleration * delta) # Accelerates depth movement toward the requested Z speed.
	_apply_vertical_movement(delta) # Applies gravity and jump behaviour independently from horizontal movement.
	move_and_slide() # Moves through the 3D world using CharacterBody3D collision and floor handling.
	_paper_visual.set_motion_direction(Vector3(velocity.x, 0.0, velocity.z)) # Passes current ground-plane motion to the visual component.
	_paper_visual.set_airborne(not is_on_floor()) # Passes post-move floor contact so jump presentation matches the actual physics state.
	_paper_visual.set_interacting(Input.is_action_pressed(BUTTON_X)) # Lets the supplied interaction pose override grounded locomotion while the interaction button is held.

func _apply_vertical_movement(delta: float) -> void: # Keeps jump and gravity logic isolated from horizontal movement.
	if is_on_floor(): # Checks whether the previous physics move established floor contact.
		if Input.is_action_just_pressed(BUTTON_A): # Detects a fresh jump press while grounded.
			velocity.y = JUMP_VELOCITY # Launches the player upward.
		else: # Handles grounded frames without a jump request.
			velocity.y = 0.0 # Prevents residual vertical velocity from accumulating on the floor.
		return # Finishes vertical processing for grounded movement.
	var gravity_multiplier: float = 1.0 # Starts airborne gravity at the normal project setting.
	if velocity.y < 0.0: # Detects the falling half of the jump arc.
		gravity_multiplier = FALL_GRAVITY_MULTIPLIER # Increases falling gravity for a tighter landing feel.
	velocity.y -= _gravity * gravity_multiplier * delta # Applies frame-rate-independent gravity to vertical velocity.
