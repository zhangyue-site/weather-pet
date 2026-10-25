extends RefCounted
const PATH = "res://companion/art/interaction-poses-v1.png"
static var image: Texture2D
const RECTS = [Rect2(0,0,384,530),Rect2(384,0,384,530),Rect2(768,0,384,530),Rect2(1152,0,384,530),Rect2(0,530,410,494),Rect2(410,530,365,494),Rect2(775,530,385,494),Rect2(1160,530,376,494)]
const FEET = [Vector2(223,515),Vector2(592,516),Vector2(946,516),Vector2(1318,514),Vector2(222,1001),Vector2(586,1008),Vector2(965,1007),Vector2(1337,1007)]
const HANDS = [Vector2(294,333),Vector2(693,300),Vector2(1077,280),Vector2(1370,250),Vector2(184,831),Vector2(472,746),Vector2(846,750),Vector2(1292,773)]
var textures: Array[AtlasTexture] = []
func _init() -> void:
	if image == null:
		var pixels := Image.new()
		if pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(PATH)) != OK: return
		image = ImageTexture.create_from_image(pixels)
	for rect in RECTS:
		var texture := AtlasTexture.new();texture.atlas=image;texture.region=rect;texture.filter_clip=true;textures.append(texture)
func texture(index: int) -> AtlasTexture: return textures[index]
func anchor(index: int) -> Vector2: return FEET[index]-RECTS[index].position
func hand(index: int) -> Vector2: return HANDS[index]-FEET[index]
