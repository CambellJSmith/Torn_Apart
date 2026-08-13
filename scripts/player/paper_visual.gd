extends Node3D # Controls only the presentation and animation state of the flat paper character.
class_name TornPaperVisual # Gives the visual component a strongly typed project-wide class name.

const IDLE_TEXTURE: Texture2D = preload("res://assets/player/player_idle_front.png") # Loads the normalized front-facing idle artwork once.
const INTERACT_TEXTURE: Texture2D = preload("res://assets/player/player_interact_front.png") # Loads the normalized front-facing interaction artwork once.
const WALK_TEXTURE: Texture2D = preload("res://assets/player/player_walk_right.png") # Loads the optimized side-facing walk sprite sheet once.
const FRONT_PIXEL_SIZE: float = 0.016 # Keeps front-facing artwork at the intended world-space scale.
const WALK_PIXEL_SIZE: float = 0.026 # Keeps the walk artwork slightly smaller than the front-facing poses.
const WALK_HORIZONTAL_FRAMES: int = 4 # Describes the horizontal frame layout of the walk sheet.
const WALK_VERTICAL_FRAMES: int = 2 # Describes the vertical frame layout of the walk sheet.
const WALK_FRAME_COUNT: int = WALK_HORIZONTAL_FRAMES * WALK_VERTICAL_FRAMES # Derives the number of walk frames from the sheet layout.
const WALK_FRAMES_PER_SECOND: float = 10.0 # Controls the playback cadence of the walk cycle.
const MOTION_EPSILON: float = 0.01 # Filters tiny movement values from visual animation decisions.

@onready var _sprite: Sprite3D = $sprite # Caches the single billboard sprite used for every player visual state.

var _motion_direction: Vector3 = Vector3.ZERO # Stores player movement used to select and orient visual animation.
var _walk_frame_accumulator: float = 0.0 # Accumulates fractional walk frames without allocating animation objects.
var _last_horizontal_facing: float = 1.0 # Remembers the last meaningful horizontal direction for left-right mirroring.
var _is_interacting: bool = false # Stores whether the front-facing interaction pose should override locomotion.

func _ready() -> void: # Initializes the billboard with the neutral front-facing artwork.
	_apply_single_frame_state(IDLE_TEXTURE) # Applies the idle texture before the first visual update.

func _process(delta: float) -> void: # Updates presentation independently from gameplay physics.
	_update_visual_state(delta) # Selects the correct texture, frame, scale, and horizontal orientation.

func set_motion_direction(direction: Vector3) -> void: # Accepts movement information from the composed player controller.
	_motion_direction = direction # Stores the latest ground-plane movement for animation selection.
	if absf(direction.x) > MOTION_EPSILON: # Detects meaningful horizontal movement that establishes facing.
		_last_horizontal_facing = signf(direction.x) # Remembers whether the side-facing walk art should use its source orientation or be mirrored.

func set_interacting(is_interacting: bool) -> void: # Accepts the current interaction-button state from the player controller.
	_is_interacting = is_interacting # Stores the interaction override for the next presentation update.

func _update_visual_state(delta: float) -> void: # Resolves the visual state with interaction taking priority over locomotion.
	if _is_interacting: # Checks whether the interaction pose currently has priority.
		_apply_single_frame_state(INTERACT_TEXTURE) # Shows the supplied front-facing talking or explaining pose.
		return # Prevents locomotion animation from overriding the interaction pose.
	if _motion_direction.length_squared() <= MOTION_EPSILON * MOTION_EPSILON: # Checks whether ground-plane motion is effectively stopped.
		_apply_single_frame_state(IDLE_TEXTURE) # Returns the billboard to the supplied front-facing idle pose.
		return # Prevents walk animation work while stationary.
	_apply_walk_state(delta) # Advances the supplied walk sheet whenever the player is moving.

func _apply_single_frame_state(texture: Texture2D) -> void: # Configures the billboard for a standalone idle or interaction image.
	if _sprite.texture != texture or _sprite.hframes != 1 or _sprite.vframes != 1: # Avoids redundant resource and sheet-layout writes every frame.
		_sprite.texture = texture # Switches the billboard to the requested standalone texture.
		_sprite.hframes = 1 # Treats the standalone texture as one horizontal frame.
		_sprite.vframes = 1 # Treats the standalone texture as one vertical frame.
		_sprite.frame = 0 # Selects the standalone texture frame.
		_sprite.pixel_size = FRONT_PIXEL_SIZE # Uses the front-art scale for both standalone poses.
	_sprite.flip_h = false # Keeps both front-facing poses unmirrored.
	_walk_frame_accumulator = 0.0 # Resets walk timing so a future walk begins cleanly.

func _apply_walk_state(delta: float) -> void: # Configures and advances the walking sprite sheet.
	if _sprite.texture != WALK_TEXTURE: # Detects the transition from a standalone pose into walking.
		_sprite.texture = WALK_TEXTURE # Switches the billboard to the supplied walk sprite sheet.
		_sprite.hframes = WALK_HORIZONTAL_FRAMES # Applies the horizontal frame layout.
		_sprite.vframes = WALK_VERTICAL_FRAMES # Applies the vertical frame layout.
		_sprite.frame = 0 # Starts each new walking sequence from the beginning of the sheet.
		_sprite.pixel_size = WALK_PIXEL_SIZE # Applies the dedicated walk-art scale.
		_walk_frame_accumulator = 0.0 # Clears stale frame timing when entering the walk state.
	_sprite.flip_h = _last_horizontal_facing < 0.0 # Mirrors the source sheet when horizontal movement is in the opposite direction.
	_walk_frame_accumulator += delta * WALK_FRAMES_PER_SECOND # Converts elapsed time into fractional animation frames.
	var frame_advance: int = int(_walk_frame_accumulator) # Extracts only the complete frames ready to advance this update.
	if frame_advance <= 0: # Checks whether enough time has elapsed for another walk frame.
		return # Keeps the current frame until the configured animation cadence is reached.
	_walk_frame_accumulator -= float(frame_advance) # Retains the fractional remainder for stable frame-rate-independent playback.
	_sprite.frame = (_sprite.frame + frame_advance) % WALK_FRAME_COUNT # Advances through the supplied walk frames and loops cleanly.
