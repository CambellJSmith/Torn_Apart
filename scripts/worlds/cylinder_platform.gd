extends StaticBody3D # Owns one primitive cylindrical world platform and its matching static collision.
class_name TornCylinderPlatform # Gives the reusable world platform a strongly typed project-wide class name.

const PLATFORM_BOTTOM_Y: float = -1.5 # Defines the shared lower extent used to make raised platforms visibly taller.
const GRASS_CAP_HEIGHT: float = 0.14 # Defines the thin primitive cap used to separate the walkable top from the dirt body.
const RADIAL_SEGMENTS: int = 32 # Keeps the circular silhouette smooth enough while avoiding excessive primitive geometry.
const MESH_RINGS: int = 1 # Avoids unnecessary cylinder subdivisions because the primitive meshes are not deformed.

@onready var _dirt: MeshInstance3D = $dirt # Caches the primitive dirt body mesh node.
@onready var _grass: MeshInstance3D = $grass # Caches the primitive grass cap mesh node.
@onready var _collision: CollisionShape3D = $collision # Caches the static collision node matching the complete platform volume.

var _radius: float = 1.0 # Stores the configured platform radius until the scene becomes ready.
var _top_height: float = 0.0 # Stores the configured walkable surface height until the scene becomes ready.
var _grass_material: StandardMaterial3D = null # Stores the shared simple top material supplied by the owning level.
var _dirt_material: StandardMaterial3D = null # Stores the shared simple side material supplied by the owning level.

func configure(radius: float, top_height: float, grass_material: StandardMaterial3D, dirt_material: StandardMaterial3D) -> void: # Supplies primitive dimensions and shared materials before the platform enters the live level.
	_radius = radius # Stores the authored horizontal size for visual and collision generation.
	_top_height = top_height # Stores the authored walkable surface elevation for the stepped level layout.
	_grass_material = grass_material # Stores the shared level material used by the thin top cap.
	_dirt_material = dirt_material # Stores the shared level material used by the platform body.
	if is_node_ready(): # Supports deliberate runtime reconfiguration after the composed scene has completed setup.
		_apply_configuration() # Rebuilds the primitive resources immediately when configuration changes at runtime.

func _ready() -> void: # Builds the primitive mesh and collision resources after child nodes are available.
	_apply_configuration() # Applies the configuration supplied by the level before this scene entered the tree.

func _apply_configuration() -> void: # Rebuilds visual primitives and a convex collision shape from the configured platform dimensions.
	var platform_height: float = maxf(_top_height - PLATFORM_BOTTOM_Y, GRASS_CAP_HEIGHT) # Calculates the full solid platform height while preventing invalid non-positive geometry.
	var dirt_height: float = maxf(platform_height - GRASS_CAP_HEIGHT, 0.01) # Leaves a thin visible top cap while preserving a valid dirt primitive.
	var dirt_mesh: CylinderMesh = CylinderMesh.new() # Creates the primitive cylindrical body used for the platform sides.
	dirt_mesh.top_radius = _radius # Matches the dirt top to the authored platform radius.
	dirt_mesh.bottom_radius = _radius # Keeps the body cylindrical instead of tapering toward the bottom.
	dirt_mesh.height = dirt_height # Extends the dirt body from the shared lower world depth toward the grass cap.
	dirt_mesh.radial_segments = RADIAL_SEGMENTS # Applies the shared low-cost circular segmentation.
	dirt_mesh.rings = MESH_RINGS # Removes unused vertical subdivisions from the undeformed primitive.
	dirt_mesh.material = _dirt_material # Applies the simple shared dirt material to the primitive body.
	_dirt.mesh = dirt_mesh # Assigns the configured primitive resource to the body mesh node.
	_dirt.position = Vector3(0.0, PLATFORM_BOTTOM_Y + dirt_height * 0.5, 0.0) # Centers the dirt primitive between the shared bottom and the grass cap.
	var grass_mesh: CylinderMesh = CylinderMesh.new() # Creates the thin primitive cap that reads as the walkable grassy surface.
	grass_mesh.top_radius = _radius # Matches the visible top exactly to the platform footprint.
	grass_mesh.bottom_radius = _radius # Keeps the cap sides vertical so it sits cleanly on the dirt body.
	grass_mesh.height = GRASS_CAP_HEIGHT # Gives the top surface enough thickness to remain visibly distinct.
	grass_mesh.radial_segments = RADIAL_SEGMENTS # Matches the body segmentation so the two circular silhouettes align.
	grass_mesh.rings = MESH_RINGS # Avoids unused subdivisions on the flat primitive cap.
	grass_mesh.material = _grass_material # Applies the simple shared grass material to the walkable cap.
	_grass.mesh = grass_mesh # Assigns the configured primitive resource to the cap mesh node.
	_grass.position = Vector3(0.0, _top_height - GRASS_CAP_HEIGHT * 0.5, 0.0) # Positions the cap so its upper face is the authored walkable height.
	var collision_mesh: CylinderMesh = CylinderMesh.new() # Creates an unrendered primitive used only to derive stable static collision.
	collision_mesh.top_radius = _radius # Matches the collision footprint to the visible circular platform.
	collision_mesh.bottom_radius = _radius # Keeps the collision volume cylindrical through the complete platform depth.
	collision_mesh.height = platform_height # Matches collision height to the complete visible platform volume.
	collision_mesh.radial_segments = RADIAL_SEGMENTS # Matches the visible outline closely without using the problematic cylinder collision shape.
	collision_mesh.rings = MESH_RINGS # Avoids unnecessary vertices before convex collision generation.
	_collision.shape = collision_mesh.create_convex_shape(true, false) # Generates static convex collision directly from the primitive mesh geometry.
	_collision.position = Vector3(0.0, PLATFORM_BOTTOM_Y + platform_height * 0.5, 0.0) # Centers collision on the same vertical volume as the complete platform.
