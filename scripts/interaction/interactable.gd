extends Area3D # Provides the reusable collision-area contract for nearby player interactions.
class_name TornInteractable # Gives interactable areas a strongly typed project-wide base class.

func get_prompt_text() -> String: # Returns the short contextual action shown while this interactable is targeted.
	return "interact" # Supplies a safe generic prompt for interactables that do not override the text.

func interact(_actor: TornPlayerController) -> String: # Performs the interactable's direct gameplay action and optionally returns short message text.
	return "" # Leaves the base interactable inert while allowing specialized interactables to return feedback text.
