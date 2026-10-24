shader_type canvas_item;
render_mode unshaded;
uniform vec2 sky_shift = vec2(0.0);
uniform vec2 leaf_shift = vec2(0.0);
uniform float leaf_light = 0.0;
uniform vec2 reference_uv_scale = vec2(1.0);
varying vec4 vertex_color;
void vertex() { vertex_color = COLOR; }
void fragment() {
	vec2 uv = UV;
	float light = 1.0;
	// Texture dimensions are uniform within a draw. Gradients/shadows use white texture.
	if (TEXTURE_PIXEL_SIZE.x < 0.01 && TEXTURE_PIXEL_SIZE.y < 0.01) {
		vec2 p = (UV - vec2(0.5)) * reference_uv_scale + vec2(0.5);
		// Keep the house, stonework, ground and actors outside the animated region.
		if (p.x > 0.67 && p.y < 0.60) {
			float sky = smoothstep(0.67, 0.75, p.x) * (1.0 - smoothstep(0.40, 0.46, p.y));
			float leaves = smoothstep(0.70, 0.88, p.x) * smoothstep(0.39, 0.44, p.y) * (1.0 - smoothstep(0.56, 0.60, p.y));
			uv += sky_shift * sky + leaf_shift * leaves;
			light += leaf_light * leaves;
		}
	}
	// One texture sample, as in the original background; no full-screen extra pass.
	COLOR = texture(TEXTURE, uv) * vertex_color * vec4(vec3(light), 1.0);
}
