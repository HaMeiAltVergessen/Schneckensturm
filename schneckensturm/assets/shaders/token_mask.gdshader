// Round medallion token from a still image (Flux / Eldmyrdur face): circular
// mask, dark backdrop behind transparent pixels. Modulate still applies, so
// tween flashes and fades work. Ring and shadow are drawn by UnitVisual.
shader_type canvas_item;

uniform vec4 backdrop : source_color = vec4(0.12, 0.11, 0.14, 1.0);

varying vec4 v_color;

void vertex() {
	v_color = COLOR;
}

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d);
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = mix(backdrop.rgb, tex.rgb, tex.a);
	// soft 1-2 px edge instead of a hard discard
	float edge = fwidth(r);
	float alpha = 1.0 - smoothstep(0.5 - edge, 0.5, r);
	COLOR = vec4(rgb, alpha) * v_color;
}
