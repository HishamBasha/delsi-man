shader_type sky;

// The bundled panoramas are violet-heavy (blue sits far above green), so the
// vault reads as purple. Pull green — and a little red — toward the blue
// channel to turn it into daylight blue while keeping the panorama's bands,
// horizon and stars exactly where they are.
uniform sampler2D panorama : source_color, filter_linear_mipmap;
uniform float shift : hint_range(0.0, 1.0) = 1.0;

void sky() {
	vec3 c = texture(panorama, SKY_COORDS).rgb;
	float violet = clamp((c.b - c.g) / max(c.b, 0.001), 0.0, 1.0) * shift;
	c.g = mix(c.g, c.b * 0.80, violet);
	c.r = mix(c.r, c.b * 0.55, violet * 0.60);
	COLOR = max(c, vec3(0.0));
}
