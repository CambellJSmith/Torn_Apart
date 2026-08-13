extends TornInteractable # Provides the first level's simple authored interaction without coupling message content to the generic interaction system.

const PROMPT_TEXT: String = "read_sign" # Defines the concise contextual action shown while the sign is targeted.
const MESSAGE_TEXT: String = "keep_to_the_fenced_islands. jump_on_slimes_to_squash_them." # Defines the short first-world message returned when the sign is read.

func get_prompt_text() -> String: # Overrides the generic interaction action with sign-specific context.
	return PROMPT_TEXT # Supplies the authored sign action to the nearby interaction prompt.

func interact(_actor: Node3D) -> String: # Handles the sign interaction through the generic 3D actor contract.
	return MESSAGE_TEXT # Returns short authored feedback for the persistent interaction UI.
