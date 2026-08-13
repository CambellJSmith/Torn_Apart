extends Node3D # Owns only the geometry composition and surface styling specific to the first isolated world.
class_name TornWorld01 # Gives the first level a strongly typed project-wide scene root.

const CYLINDER_PLATFORM_SCENE: PackedScene = preload("res://scenes/worlds/components/cylinder_platform.tscn") # Loads the reusable primitive cylinder platform scene once for every level island.
const PLATFORM_SPECS: Array[Vector4] = [Vector4(-3.5, 3.5, 5.6, 0.0), Vector4(2.0, 0.5, 5.2, 0.75), Vector4(-1.0, -5.0, 4.5, 1.5), Vector4(6.3, -4.0, 3.8, 0.75)] # Packs each platform center X/Z, radius, and walkable top height into a compact typed level definition.

@onready var _platforms: Node3D = $platforms # Caches the container that owns only this level's generated primitive platforms.
@onready var _picket_fence: TornPicketFence = $picket_fence # Caches the reusable fence component surrounding exposed platform edges.

func _ready() -> void: # Builds the small isolated level from its authored primitive platform definitions.
	var grass_material: StandardMaterial3D = _create_grass_material() # Creates one shared simple top material reused by every cylinder platform.
	var dirt_material: StandardMaterial3D = _create_dirt_material() # Creates one shared simple side material reused by every cylinder platform.
	for platform_index in range(PLATFORM_SPECS.size()): # Instantiates each authored island exactly once when the level becomes ready.
		var platform_spec: Vector4 = PLATFORM_SPECS[platform_index] # Reads the center, radius, and elevation for this island.
		var platform: TornCylinderPlatform = CYLINDER_PLATFORM_SCENE.instantiate() as TornCylinderPlatform # Creates the strongly typed reusable primitive platform instance.
		if platform == null: # Detects an invalid component scene before trying to configure or add it.
			push_error("cylinder_platform.tscn must instantiate TornCylinderPlatform") # Reports broken world composition clearly in the Godot debugger.
			continue # Keeps the remaining level platforms buildable when one component instance is invalid.
		platform.name = "platform_%02d" % (platform_index + 1) # Gives each generated island a stable readable scene-tree name.
		platform.position = Vector3(platform_spec.x, 0.0, platform_spec.y) # Places the platform center on the level's XZ layout while its component owns vertical geometry.
		platform.configure(platform_spec.z, platform_spec.w, grass_material, dirt_material) # Supplies the authored radius, surface elevation, and shared simple materials before entering the tree.
		_platforms.add_child(platform) # Adds the fully configured primitive island to this isolated level scene.
	_picket_fence.build(PLATFORM_SPECS) # Generates white fence only along exposed outer edges while leaving cylinder overlaps open for traversal.

func _create_grass_material() -> StandardMaterial3D: # Creates the simple matte surface used for all walkable cylinder tops.
	var material: StandardMaterial3D = StandardMaterial3D.new() # Allocates one lightweight standard material for the complete level.
	material.albedo_color = Color(0.43, 0.68, 0.28, 1.0) # Gives the walkable top surfaces a clear storybook grass color.
	material.roughness = 0.92 # Keeps the simple primitive surface broadly matte under the directional light.
	return material # Supplies the shared grass material to every reusable cylinder platform.

func _create_dirt_material() -> StandardMaterial3D: # Creates the simple matte surface used for the visible platform bodies.
	var material: StandardMaterial3D = StandardMaterial3D.new() # Allocates one lightweight standard material for all exposed cylinder sides.
	material.albedo_color = Color(0.53, 0.32, 0.17, 1.0) # Gives the platform bodies a warm soil color beneath the green tops.
	material.roughness = 0.96 # Keeps the primitive dirt surfaces soft and non-reflective.
	return material # Supplies the shared dirt material to every reusable cylinder platform.
