class_name WorldColor
## The world's color comes back in layers, back to front, as the six colors are collected.
## Color number i (GameState.SpiritColor) owns layer i: it gives that layer full color, the
## next layer 20%, and the one after 10%. Amounts from different colors add up, so color
## cascades forward (docs/DESIGN.md, "Grey to color"). Hazards always keep at least 10% so
## they read in a grey world. Layers are drawn by shaders/layer_color.gdshader, which reads
## the strengths from two global shader values; every room shares them.

enum Layer { SKY, FAR_HILLS, NEAR_FOREST, TREES, DECOR, GROUND, HAZARDS }

## The layers colors cascade through, in order (hazards follow the ground layer).
const CASCADING_LAYERS := 6
## What a color gives its own layer and the layers after it.
const CASCADE: Array[float] = [1.0, 0.2, 0.1]
const HAZARD_MINIMUM := 0.1
const SHADER := preload("res://shaders/layer_color.gdshader")

static var _materials := {}


## Each layer's color strength (0 to 1, indexed by Layer) for the collected colors
## (bools indexed by GameState.SpiritColor).
static func strengths(collected: Array) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(Layer.size())
	for color in collected.size():
		if not collected[color]:
			continue
		for step in CASCADE.size():
			var layer := color + step
			if layer < CASCADING_LAYERS:
				values[layer] = minf(1.0, values[layer] + CASCADE[step])
	values[Layer.HAZARDS] = maxf(HAZARD_MINIMUM, values[Layer.GROUND])
	return values


## Full color everywhere (the test room).
static func full() -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(Layer.size())
	values.fill(1.0)
	return values


## Show these strengths everywhere.
static func apply(values: PackedFloat32Array) -> void:
	RenderingServer.global_shader_parameter_set(&"world_color_back",
			Vector4(values[Layer.SKY], values[Layer.FAR_HILLS], values[Layer.NEAR_FOREST], values[Layer.TREES]))
	RenderingServer.global_shader_parameter_set(&"world_color_front",
			Vector4(values[Layer.DECOR], values[Layer.GROUND], values[Layer.HAZARDS], 0.0))


## The shared material that draws things as part of `layer`.
static func material(layer: Layer) -> ShaderMaterial:
	if not _materials.has(layer):
		var shader_material := ShaderMaterial.new()
		shader_material.shader = SHADER
		shader_material.set_shader_parameter(&"layer", layer)
		_materials[layer] = shader_material
	return _materials[layer]


## Draw `node` and everything under it as part of `layer`, except anything in the
## "full_color" group (color orbs, glows, color traces), which always keeps its color.
static func paint(node: Node, layer: Layer) -> void:
	if node.is_in_group(&"full_color"):
		return
	if node is CanvasItem:
		(node as CanvasItem).material = material(layer)
	for child in node.get_children():
		paint(child, layer)
