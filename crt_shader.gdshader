shader_type canvas_item;

// Shader CRT sutil retro para estética Balatro / Roguelike
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float chromatic_aberration : hint_range(0.0, 5.0) = 0.8;
uniform float curvature : hint_range(0.0, 0.1) = 0.015;

vec2 curve(vec2 uv) {
	uv = (uv - 0.5) * 2.0;
	uv *= 1.0 + pow((abs(uv.yx) / 4.0), vec2(2.0));
	uv = (uv / 2.0) + 0.5;
	return uv;
}

void fragment() {
	vec2 uv = curve(SCREEN_UV);
	
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Aberración cromática sutil
		float shift = chromatic_aberration * 0.001;
		float r = texture(SCREEN_TEXTURE, uv + vec2(shift, 0.0)).r;
		float g = texture(SCREEN_TEXTURE, uv).g;
		float b = texture(SCREEN_TEXTURE, uv - vec2(shift, 0.0)).b;
		vec3 col = vec3(r, g, b);

		// Líneas de escaneo (Scanlines)
		float scanline = sin(uv.y * 720.0 * 3.14159) * 0.5 + 0.5;
		col -= scanline * scanline_intensity;

		// Viñeta
		float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
		col *= clamp(pow(16.0 * vignette, vignette_intensity), 0.0, 1.0);

		COLOR = vec4(col, 1.0);
	}
}
