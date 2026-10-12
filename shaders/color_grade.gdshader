shader_type canvas_item;

// Full-screen grade over the 3D view: a soft highlight bloom, exposure,
// contrast, colour temperature (warm highlights, cooler shadows), saturation
// and a vignette. The HUD lives on a higher canvas layer, so the interface is
// never graded — only the world.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float temperature : hint_range(-1.0, 1.0) = 0.16;
uniform float saturation : hint_range(0.0, 2.0) = 1.16;
uniform float contrast : hint_range(0.5, 2.0) = 1.13;
uniform float brightness : hint_range(0.5, 1.5) = 0.95;
uniform float bloom : hint_range(0.0, 1.0) = 0.14;
uniform float vignette : hint_range(0.0, 1.0) = 0.26;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;

	// Cheap bloom: eight taps around the pixel, highlights only, so sunlit
	// walls and the sky bleed a little without washing the frame out.
	vec2 px = SCREEN_PIXEL_SIZE * 3.5;
	vec3 glow = texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0)).rgb;
	glow += texture(screen_tex, SCREEN_UV - vec2(px.x, 0.0)).rgb;
	glow += texture(screen_tex, SCREEN_UV + vec2(0.0, px.y)).rgb;
	glow += texture(screen_tex, SCREEN_UV - vec2(0.0, px.y)).rgb;
	glow += texture(screen_tex, SCREEN_UV + px * 0.72).rgb;
	glow += texture(screen_tex, SCREEN_UV - px * 0.72).rgb;
	glow += texture(screen_tex, SCREEN_UV + vec2(px.x, -px.y) * 0.72).rgb;
	glow += texture(screen_tex, SCREEN_UV + vec2(-px.x, px.y) * 0.72).rgb;
	c += max(glow * 0.125 - vec3(0.80), vec3(0.0)) * bloom;

	c *= brightness;
	// Pivot above mid-tone so mids gain depth instead of the whole frame
	// lifting: the scene is mostly bright walls and sky already.
	c = (c - 0.55) * contrast + 0.55;

	// Temperature: warm the highlights, cool the shadows a shade.
	float luma = clamp(dot(c, LUMA), 0.0, 1.0);
	float warm = temperature * (0.06 + 0.09 * luma);
	c.r += warm;
	c.g += warm * 0.25;
	c.b -= warm;

	c = mix(vec3(luma), c, saturation);

	float d = distance(SCREEN_UV, vec2(0.5));
	c *= 1.0 - vignette * smoothstep(0.42, 0.95, d);

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
