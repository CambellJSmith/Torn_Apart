extends Node # Owns nearby interaction targeting separately from movement.
class_name TornNearbyInteraction # Gives the composed interaction node a strongly typed class name.

@onready var _detector: Area3D = $detector # Caches the overlap detector.
var _prompt_ui: TornInteractionPrompt = null # Stores the composed prompt UI.
var _target: TornInteractable = null # Stores the nearest current target.

func configure_prompt_ui(prompt_ui: TornInteractionPrompt) -> void: # Supplies persistent prompt UI.
	_prompt_ui = prompt_ui # Stores the prompt for direct updates.

func update_target(actor: Node3D) -> void: # Resolves the nearest overlapping interactable.
	var nearest: TornInteractable = null # Starts with no candidate.
	var nearest_distance: float = INF # Starts above every finite squared distance.
	for area: Area3D in _detector.get_overlapping_areas(): # Reads the physics-maintained overlap list.
		if area is not TornInteractable: # Rejects unrelated areas.
			continue # Checks the next overlap.
		var distance: float = actor.global_position.distance_squared_to(area.global_position) # Measures candidate proximity.
		if distance >= nearest_distance: # Rejects farther candidates.
			continue # Checks the next overlap.
		nearest = area as TornInteractable # Stores the nearest typed target.
		nearest_distance = distance # Stores its squared distance.
	if nearest == _target: # Detects unchanged targeting.
		return # Avoids redundant UI work.
	_target = nearest # Applies the changed target.
	_refresh_prompt() # Synchronizes contextual UI.

func use_target(actor: Node3D) -> void: # Invokes the selected target directly.
	if _target == null: # Rejects use without a target.
		return # Leaves gameplay unchanged.
	var message: String = _target.interact(actor) # Executes the interaction and captures feedback.
	if _prompt_ui != null and not message.is_empty(): # Checks whether feedback can be shown.
		_prompt_ui.show_message(message) # Displays returned feedback.

func clear_target() -> void: # Clears stale targeting after teleports.
	_target = null # Removes the previous target.
	_refresh_prompt() # Hides contextual UI.

func _refresh_prompt() -> void: # Updates contextual prompt state.
	if _prompt_ui == null: # Rejects UI work before composition.
		return # Keeps targeting usable without UI.
	if _target == null: # Detects no target.
		_prompt_ui.clear_context_prompt() # Hides contextual UI.
		return # Finishes no-target handling.
	_prompt_ui.set_context_prompt(_target.get_prompt_text()) # Shows the selected target action.
