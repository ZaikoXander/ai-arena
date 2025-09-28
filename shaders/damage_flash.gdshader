shader_type canvas_item;

uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Red by default
varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec4 base_color = tex_color * modulate;
    if (damage_flash > 0.0) {
        // Blend RGB towards flash_color, but preserve original alpha for transparency
        vec3 blended_rgb = mix(base_color.rgb, flash_color.rgb, damage_flash);
        COLOR = vec4(blended_rgb, base_color.a);
    } else {
        COLOR = base_color;
    }
}