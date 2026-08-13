extends Node3D # Controls only the presentation and animation state of the flat paper character.
class_name TornPaperVisual # Gives the visual component a strongly typed project-wide class name.

const IDLE_TEXTURE: Texture2D = preload("res://assets/player/player_idle_front.png") # Loads the normalized front-facing idle artwork once.
const INTERACT_TEXTURE: Texture2D = preload("res://assets/player/player_interact_front.png") # Loads the normalized front-facing interaction artwork once.
const WALK_TEXTURE: Texture2D = preload("res://assets/player/player_walk_right.png") # Loads the optimized side-facing walk sprite sheet once.
const FRONT_PIXEL_SIZE: float = 0.016 # Keeps front-facing artwork at the intended world-space scale.
const SIDE_PIXEL_SIZE: float = 0.026 # Keeps side-facing locomotion artwork slightly smaller than the front-facing poses.
const WALK_HORIZONTAL_FRAMES: int = 4 # Describes the horizontal frame layout of the walk sheet.
const WALK_VERTICAL_FRAMES: int = 2 # Describes the vertical frame layout of the walk sheet.
const WALK_FRAME_COUNT: int = WALK_HORIZONTAL_FRAMES * WALK_VERTICAL_FRAMES # Derives the number of walk frames from the sheet layout.
const WALK_FRAMES_PER_SECOND: float = 10.0 # Controls the playback cadence of the walk cycle.
const JUMP_HORIZONTAL_FRAMES: int = 4 # Describes the horizontal frame layout of the supplied jump sheet.
const JUMP_VERTICAL_FRAMES: int = 2 # Describes the vertical frame layout of the supplied jump sheet.
const JUMP_FRAME_COUNT: int = JUMP_HORIZONTAL_FRAMES * JUMP_VERTICAL_FRAMES # Derives the number of jump frames from the sheet layout.
const JUMP_FRAMES_PER_SECOND: float = 7.0 # Spreads the complete jump cycle across the physical airtime without looping.
const MOTION_EPSILON: float = 0.01 # Filters tiny movement values from visual animation decisions.

@onready var _sprite: Sprite3D = $sprite # Caches the single billboard sprite used for every player visual state.

var _jump_texture: Texture2D = null # Stores the decoded transparent jump sprite sheet used during airtime.
var _motion_direction: Vector3 = Vector3.ZERO # Stores player movement used to select and orient visual animation.
var _walk_frame_accumulator: float = 0.0 # Accumulates fractional walk frames without allocating animation objects.
var _jump_frame_accumulator: float = 0.0 # Accumulates fractional jump frames without allocating animation objects.
var _last_horizontal_facing: float = 1.0 # Remembers the last meaningful horizontal direction for left-right mirroring.
var _is_interacting: bool = false # Stores whether the front-facing interaction pose should override grounded locomotion.
var _is_airborne: bool = false # Stores whether physics currently reports the character away from the floor.

func _ready() -> void: # Initializes runtime textures and the neutral front-facing artwork.
	_jump_texture = TornJumpTextureData.get_texture() # Decodes and caches the supplied transparent jump sprite sheet once.
	_apply_single_frame_state(IDLE_TEXTURE) # Applies the idle texture before the first visual update.

func _process(delta: float) -> void: # Updates presentation independently from gameplay physics.
	_update_visual_state(delta) # Selects the correct texture, frame, scale, and horizontal orientation.

func set_motion_direction(direction: Vector3) -> void: # Accepts movement information from the composed player controller.
	_motion_direction = direction # Stores the latest ground-plane movement for animation selection.
	if absf(direction.x) > MOTION_EPSILON: # Detects meaningful horizontal movement that establishes facing.
		_last_horizontal_facing = signf(direction.x) # Remembers whether side-facing artwork should use its source orientation or be mirrored.

func set_airborne(is_airborne: bool) -> void: # Accepts post-move floor contact from the player controller for jump animation selection.
	if _is_airborne == is_airborne: # Avoids restarting jump timing while the physical airborne state remains unchanged.
		return # Keeps the current jump frame progression intact until the contact state changes.
	_is_airborne = is_airborne # Stores the latest physical airborne state for visual priority resolution.
	if _is_airborne: # Detects the transition from grounded movement into a jump or fall.
		_jump_frame_accumulator = 0.0 # Restarts the supplied jump cycle from its first frame on takeoff.

func set_interacting(is_interacting: bool) -> void: # Accepts the current interaction-button state from the player controller.
	_is_interacting = is_interacting # Stores the interaction override for the next grounded presentation update.

func _update_visual_state(delta: float) -> void: # Resolves the visual state with airborne presentation above grounded interaction and locomotion.
	if _is_airborne: # Checks whether physics currently requires the jump presentation.
		_apply_jump_state(delta) # Advances the supplied jump cycle while the character remains airborne.
		return # Prevents grounded interaction, idle, or walk art from replacing the jump animation.
	if _is_interacting: # Checks whether the interaction pose currently has grounded priority.
		_apply_single_frame_state(INTERACT_TEXTURE) # Shows the supplied front-facing talking or explaining pose.
		return # Prevents locomotion animation from overriding the interaction pose.
	if _motion_direction.length_squared() <= MOTION_EPSILON * MOTION_EPSILON: # Checks whether ground-plane motion is effectively stopped.
		_apply_single_frame_state(IDLE_TEXTURE) # Returns the billboard to the supplied front-facing idle pose.
		return # Prevents walk animation work while stationary.
	_apply_walk_state(delta) # Advances the supplied walk sheet whenever the grounded player is moving.

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
	if _sprite.texture != WALK_TEXTURE: # Detects the transition from another visual state into walking.
		_sprite.texture = WALK_TEXTURE # Switches the billboard to the supplied walk sprite sheet.
		_sprite.hframes = WALK_HORIZONTAL_FRAMES # Applies the horizontal frame layout.
		_sprite.vframes = WALK_VERTICAL_FRAMES # Applies the vertical frame layout.
		_sprite.frame = 0 # Starts each new walking sequence from the beginning of the sheet.
		_sprite.pixel_size = SIDE_PIXEL_SIZE # Applies the established smaller side-facing artwork scale.
		_walk_frame_accumulator = 0.0 # Clears stale frame timing when entering the walk state.
	_sprite.flip_h = _last_horizontal_facing < 0.0 # Mirrors the source sheet when horizontal movement is in the opposite direction.
	_walk_frame_accumulator += delta * WALK_FRAMES_PER_SECOND # Converts elapsed time into fractional animation frames.
	var frame_advance: int = int(_walk_frame_accumulator) # Extracts only the complete frames ready to advance this update.
	if frame_advance <= 0: # Checks whether enough time has elapsed for another walk frame.
		return # Keeps the current frame until the configured animation cadence is reached.
	_walk_frame_accumulator -= float(frame_advance) # Retains the fractional remainder for stable frame-rate-independent playback.
	_sprite.frame = (_sprite.frame + frame_advance) % WALK_FRAME_COUNT # Advances through the supplied walk frames and loops cleanly.

func _apply_jump_state(delta: float) -> void: # Configures and advances the supplied jump sprite sheet without looping it in midair.
	if _sprite.texture != _jump_texture: # Detects the transition from another visual state into the jump cycle.
		_sprite.texture = _jump_texture # Switches the billboard to the supplied jump sprite sheet.
		_sprite.hframes = JUMP_HORIZONTAL_FRAMES # Applies the jump sheet's horizontal frame layout.
		_sprite.vframes = JUMP_VERTICAL_FRAMES # Applies the jump sheet's vertical frame layout.
		_sprite.frame = 0 # Starts each new airborne sequence from the first supplied jump frame.
		_sprite.pixel_size = SIDE_PIXEL_SIZE # Matches the jump artwork to the established side-facing walk scale.
		_walk_frame_accumulator = 0.0 # Clears stale walk timing so grounded locomotion resumes cleanly after landing.
	_sprite.flip_h = _last_horizontal_facing < 0.0 # Mirrors the right-facing source sheet whenever the player is facing left.
	_jump_frame_accumulator += delta * JUMP_FRAMES_PER_SECOND # Converts elapsed airtime into a stable fractional jump frame position.
	_sprite.frame = mini(int(_jump_frame_accumulator), JUMP_FRAME_COUNT - 1) # Advances through every supplied frame once and holds the final pose until landing.
