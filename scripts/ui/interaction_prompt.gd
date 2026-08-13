extends Control # Owns the screen-space contextual interaction prompt using ordinary Control nodes.
class_name TornInteractionPrompt # Gives the prompt UI a strongly typed project-wide class name.

const MESSAGE_DURATION_MSEC: int = 2200 # Defines how long short interaction feedback overrides the contextual prompt.

@onready var _panel: PanelContainer = $prompt_panel # Caches the panel that frames interaction text near the bottom of the screen.
@onready var _label: Label = $prompt_panel/prompt_label # Caches the label used for both contextual prompts and short messages.

var _context_prompt: String = "" # Stores the current nearby action text independently from temporary interaction feedback.
var _message_until_msec: int = 0 # Stores the monotonic engine tick when temporary feedback should stop overriding the prompt.

func _ready() -> void: # Initializes the prompt hidden until a nearby interactable is selected.
	_panel.visible = false # Prevents an empty panel from appearing before the interaction controller supplies context.

func _process(_delta: float) -> void: # Restores contextual prompt text after temporary interaction feedback expires.
	if _message_until_msec == 0: # Rejects per-frame work when no temporary message is active.
		return # Leaves the current contextual prompt untouched.
	if Time.get_ticks_msec() < _message_until_msec: # Keeps temporary feedback visible until its short display interval completes.
		return # Waits for a later rendered frame before restoring contextual text.
	_message_until_msec = 0 # Clears message priority after its display interval completes.
	_apply_context_prompt() # Restores the nearby interaction prompt or hides the panel when no target remains.

func set_context_prompt(prompt_text: String) -> void: # Stores the nearby interactable action without interrupting active feedback text.
	_context_prompt = prompt_text # Stores the latest contextual action supplied by interaction targeting.
	if _message_until_msec == 0: # Updates visible text immediately only when no temporary message has priority.
		_apply_context_prompt() # Applies the newly stored contextual prompt to the Control nodes.

func clear_context_prompt() -> void: # Clears the nearby action when the player leaves interaction range.
	_context_prompt = "" # Removes stale target text from persistent UI state.
	if _message_until_msec == 0: # Hides the panel immediately only when temporary feedback is not still active.
		_apply_context_prompt() # Re-evaluates panel visibility from the now-empty contextual prompt.

func show_message(message_text: String) -> void: # Displays short interaction feedback before returning to the contextual action prompt.
	_message_until_msec = Time.get_ticks_msec() + MESSAGE_DURATION_MSEC # Starts the temporary feedback interval using the monotonic engine clock.
	_label.text = message_text # Replaces contextual action text with the interaction result.
	_panel.visible = true # Ensures the feedback panel is visible for the complete message interval.

func _apply_context_prompt() -> void: # Applies stored contextual state to the visible Control nodes.
	if _context_prompt.is_empty(): # Detects when the player currently has no interaction target.
		_panel.visible = false # Hides the complete prompt panel rather than showing blank UI chrome.
		return # Finishes UI synchronization for the no-target state.
	_label.text = "button_x  %s" % _context_prompt # Shows the project input action name beside the target's concise prompt text.
	_panel.visible = true # Displays the prompt panel while a valid nearby interactable is selected.
