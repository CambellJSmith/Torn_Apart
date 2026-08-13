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
const JUMP_TAKEOFF_LAST_FRAME: int = 3 # Holds the airborne pose on the fourth supplied frame after takeoff finishes.
const JUMP_LANDING_FIRST_FRAME: int = 4 # Starts the second half of the supplied sheet only when landing begins.
const JUMP_PRELAND_LAST_FRAME: int = 6 # Reserves the final supplied frame for actual floor contact.
const JUMP_LANDING_LAST_FRAME: int = JUMP_FRAME_COUNT - 1 # Identifies the final supplied landing frame.
const JUMP_LANDING_FRAME_COUNT: int = JUMP_FRAME_COUNT - JUMP_LANDING_FIRST_FRAME # Derives the number of frames dedicated to landing.
const JUMP_TAKEOFF_FRAMES_PER_SECOND: float = 12.0 # Plays the first half quickly before holding the fourth frame in midair.
const JUMP_LANDING_FRAMES_PER_SECOND: float = 14.0 # Plays the remaining frames tightly around the landing moment.
const MOTION_EPSILON: float = 0.01 # Filters tiny movement values from visual animation decisions.

@onready var _sprite: Sprite3D = $sprite # Caches the single billboard sprite used for every player visual state.

var _jump_texture: Texture2D = null # Stores the decoded transparent jump sprite sheet used during airtime and landing.
var _motion_direction: Vector3 = Vector3.ZERO # Stores player movement used to select and orient visual animation.
var _walk_frame_accumulator: float = 0.0 # Accumulates fractional walk frames without allocating animation objects.
var _takeoff_frame_accumulator: float = 0.0 # Accumulates the first half of the jump sequence until the fourth frame is reached.
var _landing_frame_accumulator: float = 0.0 # Accumulates the second half of the jump sequence around floor contact.
var _last_horizontal_facing: float = 1.0 # Remembers the last meaningful horizontal direction for left-right mirroring.
var _is_interacting: bool = false # Stores whether the front-facing interaction pose should override grounded locomotion.
var _is_airborne: bool = false # Stores whether physics currently reports the character away from the floor.
var _landing_sequence_active: bool = false # Stores whether the second half of the jump sheet currently owns visual priority.

func _ready() -> void: # Initializes runtime textures and the neutral front-facing artwork.
	_jump_texture = TornJumpTextureData.get_texture() # Decodes and caches the supplied transparent jump sprite sheet once.
	_apply_single_frame_state(IDLE_TEXTURE) # Applies the idle texture before the first visual update.

func _process(delta: float) -> void: # Updates presentation independently from gameplay physics.
	_update_visual_state(delta) # Selects the correct texture, frame, scale, and horizontal orientation.

func set_motion_direction(direction: Vector3) -> void: # Accepts movement information from the composed player controller.
	_motion_direction = direction # Stores the latest ground-plane movement for animation selection.
	if absf(direction.x) > MOTION_EPSILON: # Detects meaningful horizontal movement that establishes facing.
		_last_horizontal_facing = signf(direction.x) # Remembers whether side-facing artwork should use its source orientation or be mirrored.

func set_jump_state(is_airborne: bool, landing_imminent: bool) -> void: # Accepts physical airtime and near-floor state from the player controller.
	var was_airborne: bool = _is_airborne # Remembers the previous contact state so takeoff and touchdown transitions occur only once.
	_is_airborne = is_airborne # Stores the latest post-move floor state for jump visual priority.
	if not was_airborne and _is_airborne: # Detects the start of a new jump or airborne fall.
		_takeoff_frame_accumulator = 0.0 # Restarts the first-half takeoff animation from its first supplied frame.
		_landing_frame_accumulator = 0.0 # Clears any timing left over from the previous landing sequence.
		_landing_sequence_active = false # Ensures every new airborne sequence begins with the takeoff half of the sheet.
	if _is_airborne and landing_imminent and not _landing_sequence_active: # Detects the descending near-floor window where landing frames should begin.
		_start_landing_sequence() # Starts the second half of the supplied jump sheet shortly before contact.
	if was_airborne and not _is_airborne: # Detects actual floor contact after an airborne frame.
		if not _landing_sequence_active: # Handles very short falls where the proximity probe did not have time to trigger first.
			_start_landing_sequence() # Starts the landing half at contact so the recovery frames are never skipped.
		_landing_frame_accumulator = minf(_landing_frame_accumulator, float(JUMP_PRELAND_LAST_FRAME - JUMP_LANDING_FIRST_FRAME + 1)) # Preserves one final contact frame even after a long pre-landing hold.

func set_interacting(is_interacting: bool) -> void: # Accepts the current interaction-button state from the player controller.
	_is_interacting = is_interacting # Stores the interaction override for the next grounded presentation update.

func _start_landing_sequence() -> void: # Begins the second half of the supplied jump animation exactly once per landing.
	_landing_sequence_active = true # Gives landing presentation priority over airborne hold and grounded locomotion.
	_landing_frame_accumulator = 0.0 # Starts the landing half from its first supplied frame.

func _update_visual_state(delta: float) -> void: # Resolves landing, airborne, interaction, idle, and walk priority in that order.
	if _landing_sequence_active: # Checks whether the second half of the jump sheet currently owns visual priority.
		_apply_landing_state(delta) # Advances the pre-contact and touchdown frames without looping.
		if _landing_sequence_active: # Checks whether the landing recovery still has frames left to display.
			return # Prevents any lower-priority visual state from interrupting the landing sequence.
	if _is_airborne: # Checks whether the player remains airborne before the landing window begins.
		_apply_takeoff_state(delta) # Plays frames one through four and then holds the fourth frame for the remaining airtime.
		return # Prevents grounded interaction, idle, or walk art from replacing the airborne hold pose.
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

func _configure_jump_sprite() -> void: # Applies the shared sheet layout, scale, and facing used by both jump phases.
	if _sprite.texture != _jump_texture: # Detects the transition from grounded artwork into the supplied jump sheet.
		_sprite.texture = _jump_texture # Switches the billboard to the decoded jump sprite sheet.
		_sprite.hframes = JUMP_HORIZONTAL_FRAMES # Applies the jump sheet's horizontal frame layout.
		_sprite.vframes = JUMP_VERTICAL_FRAMES # Applies the jump sheet's vertical frame layout.
		_sprite.pixel_size = SIDE_PIXEL_SIZE # Matches the jump artwork to the established side-facing walk scale.
		_walk_frame_accumulator = 0.0 # Clears stale walk timing so locomotion resumes cleanly after landing.
	_sprite.flip_h = _last_horizontal_facing < 0.0 # Mirrors the right-facing source sheet whenever the player is facing left.

func _apply_takeoff_state(delta: float) -> void: # Plays only the first half of the jump sheet and then holds its fourth frame.
	_configure_jump_sprite() # Ensures the jump texture, sheet layout, scale, and facing are ready before selecting a frame.
	_takeoff_frame_accumulator += delta * JUMP_TAKEOFF_FRAMES_PER_SECOND # Converts elapsed takeoff time into a stable fractional frame position.
	_sprite.frame = mini(int(_takeoff_frame_accumulator), JUMP_TAKEOFF_LAST_FRAME) # Advances through frames one to four and holds the fourth frame until landing begins.

func _apply_landing_state(delta: float) -> void: # Plays only frames five through eight around pre-contact and touchdown.
	_configure_jump_sprite() # Ensures the jump texture, sheet layout, scale, and facing remain active through landing.
	_landing_frame_accumulator += delta * JUMP_LANDING_FRAMES_PER_SECOND # Converts elapsed landing time into a stable fractional frame position.
	var landing_frame_offset: int = int(_landing_frame_accumulator) # Converts accumulated landing time into the current second-half frame offset.
	if _is_airborne: # Checks whether the player has not yet made physical floor contact.
		_sprite.frame = mini(JUMP_LANDING_FIRST_FRAME + landing_frame_offset, JUMP_PRELAND_LAST_FRAME) # Plays pre-contact frames five through seven while reserving frame eight for touchdown.
		return # Keeps the landing sequence active until the physics body actually reaches the floor.
	_sprite.frame = mini(JUMP_LANDING_FIRST_FRAME + landing_frame_offset, JUMP_LANDING_LAST_FRAME) # Continues the remaining landing frames after physical contact.
	if landing_frame_offset < JUMP_LANDING_FRAME_COUNT: # Checks whether the final landing frame has completed its display interval.
		return # Keeps landing visual priority until every remaining supplied frame has been shown.
	_landing_sequence_active = false # Releases visual priority once the non-looping landing recovery is complete.
	_landing_frame_accumulator = 0.0 # Clears landing timing so the next jump begins from a clean state.
