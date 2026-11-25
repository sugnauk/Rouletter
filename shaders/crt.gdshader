shader_type canvas_item;
// Light CRT pass: scanlines on the 640x360 base grid, soft vignette, faint warm bleed.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float scanline_strength = 0.13;
uniform float vignette = 0.55;

void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	float line = mod(floor(FRAGCOORD.y), 2.0);
	c.rgb *= 1.0 - scanline_strength * line;
	vec2 d = SCREEN_UV - 0.5;
	c.rgb *= 1.0 - dot(d, d) * vignette;
	c.r = c.r * 1.03;
	COLOR = vec4(c.rgb, 1.0);
}
