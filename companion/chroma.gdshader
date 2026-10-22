shader_type canvas_item;
render_mode unshaded;
uniform vec4 environment_tint : source_color = vec4(1.0);
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float magenta = min(c.r, c.b) - c.g;
	float alpha = 1.0 - smoothstep(0.18, 0.60, magenta);
	// Suppress key-color spill on antialiased edge pixels.
	if (magenta > 0.12) {
		c.r = min(c.r, c.g + 0.12);
		c.b = min(c.b, c.g + 0.12);
	}
	COLOR = vec4(c.rgb * environment_tint.rgb, c.a * alpha) * vertex_tint;
}
