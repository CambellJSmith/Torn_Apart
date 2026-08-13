extends Node # Owns nearby interaction targeting separately from player movement.
class_name TornNearbyInteraction # Gives the composed interaction node a strongly typed project-wide class name.

@onready var _detector: Area3D = $detector # Caches the player-owned overlap detector.
var _prompt_ui: TornInteractionPrompt = null # Stores the composed prompt UI.
var _target: TornInteractable = null # Stores the nearest current target.

func configure_prompt_ui(prompt_ui: TornInteractionPrompt) -> void: # Supplies the persistent prompt component.
	_prompt_ui = prompt_ui # Stores the prompt for direct updates.

func update_target(player: Node3D) -> void: # Resolves the nearest overlapping interactable.
	var nearest: TornInteractable = null # Starts with no candidate.
	var nearest_distance: float = INF # Starts above every finite squared distance.
	for area: Area3D in _detector.get_overlapping_areas(): # Reads the physics-maintained overlap list.
		if area is TornInteractable: # Accepts only reusable interactable areas.
			var distance: float = player.global_position.distance_squared_to(area.global_position) # Measures candidate proximity efficiently.
			if distance < nearest_distance: # Keeps only the nearest candidate.
				nearest = area as TornInteractable # Stores the nearest typed interactable.
				nearest_distance = distance # Stores its squared distance.
	_target = nearest # Applies the resolved target.
	_refresh_prompt() # Synchronizes contextual UI.

func use_target(player: TornPlayerController) -> void: # Invokes the selected interactable directly.
	if _target == null: # Rejects use without a target.
		return # Leaves gameplay unchanged when nothing is nearby.
	var message: String = _target.interact(player) # Executes the interaction and captures optional feedback.
	if _prompt_ui != null and not message.is_empty(): # Checks whether feedback can be shown.
		_prompt_ui.show_message(message) # Displays short returned feedback.

func clear_target() -> void: # Clears stale targeting after teleports.
	_target = null # Removes the previous spatial target.
	_refresh_prompt() # Hides contextual UI immediately.

func _refresh_prompt() -> void: # Updates the contextual prompt from current target state.
	if _prompt_ui == null: # Rejects UI work before composition.
		return # Keeps targeting functional without UI.
	if _target == null: # Detects the no-target state.
		_prompt_ui.clear_context_prompt() # Hides the contextual prompt.
		return # Finishes no-target synchronization.
	_prompt_ui.set_context_prompt(_target.get_prompt_text()) # Shows the selected target action.
