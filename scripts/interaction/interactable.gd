extends Area3D # Provides the reusable collision-area contract for nearby player interactions.
class_name TornInteractable # Gives interactable areas a strongly typed project-wide base class.

func get_prompt_text() -> String: # Returns the short contextual action shown while this interactable is targeted.
	return "interact" # Supplies a safe generic prompt for interactables that do not override the text.

func interact(_actor: Node3D) -> String: # Performs the interactable's direct action against a generic 3D actor and optionally returns feedback text.
	return "" # Leaves the base interactable inert while specialized interactables provide their own behavior.
