extends RefCounted # Keeps input setup as a lightweight utility rather than a scene node.

const STICK_LEFT_NORTH: StringName = &"StickLeft_North" # Identifies the north movement action.
const STICK_LEFT_SOUTH: StringName = &"StickLeft_South" # Identifies the south movement action.
const STICK_LEFT_WEST: StringName = &"StickLeft_West" # Identifies the west movement action.
const STICK_LEFT_EAST: StringName = &"StickLeft_East" # Identifies the east movement action.
const BUTTON_A: StringName = &"Button_A" # Identifies the primary action button.
const BUTTON_START: StringName = &"Button_Start" # Identifies the start or pause button.
const STICK_DEADZONE: float = 0.20 # Controls analog movement deadzone handling.
const BUTTON_DEADZONE: float = 0.50 # Controls digital button deadzone handling.

static func ensure_default_actions() -> void: # Creates fallback keyboard and gamepad mappings when the project has no mappings yet.
	_ensure_axis_action(STICK_LEFT_NORTH, KEY_W, JOY_AXIS_LEFT_Y, -1.0) # Registers north movement defaults.
	_ensure_axis_action(STICK_LEFT_SOUTH, KEY_S, JOY_AXIS_LEFT_Y, 1.0) # Registers south movement defaults.
	_ensure_axis_action(STICK_LEFT_WEST, KEY_A, JOY_AXIS_LEFT_X, -1.0) # Registers west movement defaults.
	_ensure_axis_action(STICK_LEFT_EAST, KEY_D, JOY_AXIS_LEFT_X, 1.0) # Registers east movement defaults.
	_ensure_button_action(BUTTON_A, KEY_SPACE, JOY_BUTTON_A) # Registers the primary action defaults.
	_ensure_button_action(BUTTON_START, KEY_ESCAPE, JOY_BUTTON_START) # Registers the start action defaults.

static func _ensure_axis_action(action: StringName, physical_key: Key, axis: JoyAxis, axis_value: float) -> void: # Adds one movement action without overwriting user-defined mappings.
	if InputMap.has_action(action): # Preserves any action already configured by the project or player.
		return # Stops before modifying an existing action.
	InputMap.add_action(action, STICK_DEADZONE) # Creates the movement action with an analog-friendly deadzone.
	var key_event: InputEventKey = InputEventKey.new() # Creates the keyboard fallback event.
	key_event.physical_keycode = physical_key # Uses physical key position for layout-independent gameplay movement.
	InputMap.action_add_event(action, key_event) # Adds the keyboard event to the movement action.
	var axis_event: InputEventJoypadMotion = InputEventJoypadMotion.new() # Creates the gamepad axis fallback event.
	axis_event.axis = axis # Selects the gamepad stick axis used by this movement action.
	axis_event.axis_value = axis_value # Selects the direction on the chosen gamepad axis.
	InputMap.action_add_event(action, axis_event) # Adds the gamepad axis event to the movement action.

static func _ensure_button_action(action: StringName, physical_key: Key, button: JoyButton) -> void: # Adds one digital action without overwriting user-defined mappings.
	if InputMap.has_action(action): # Preserves any action already configured by the project or player.
		return # Stops before modifying an existing action.
	InputMap.add_action(action, BUTTON_DEADZONE) # Creates the digital action with an appropriate deadzone.
	var key_event: InputEventKey = InputEventKey.new() # Creates the keyboard fallback event.
	key_event.physical_keycode = physical_key # Uses physical key position for consistent gameplay controls.
	InputMap.action_add_event(action, key_event) # Adds the keyboard event to the digital action.
	var button_event: InputEventJoypadButton = InputEventJoypadButton.new() # Creates the gamepad button fallback event.
	button_event.button_index = button # Selects the gamepad button used by this action.
	InputMap.action_add_event(action, button_event) # Adds the gamepad button event to the digital action.
