shader_type spatial;
render_mode cull_disabled, unshaded;

group_uniforms grid_settings;
uniform vec2 plane_dimensions = vec2(10.0, 10.0);
uniform vec4 grid_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float cell_size : hint_range(0.1, 10.0) = 1.0;
uniform float line_width : hint_range(0.001, 0.1) = 0.02;

group_uniforms fade_settings;
uniform bool fade_edges = true;
uniform float edges_fade_smoothness : hint_range(1.0, 5.0) = 2.0;
uniform float distance_fade : hint_range(1.0, 10.0, 0.1) = 2.5;


void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	vec2 grid_uv = world_pos.xz / cell_size;
	vec2 grid = abs(fract(grid_uv - 0.5) - 0.5);
	vec2 pixel_size = fwidth(grid_uv);
	
	vec2 lines = smoothstep(line_width - pixel_size, line_width + pixel_size, grid);
	float line_alpha = 1.0 - min(lines.x, lines.y);
	
	float density = max(pixel_size.x, pixel_size.y);
	float pixel_fade = smoothstep(0.0, 0.99, 1.0 / (distance_fade * density));
	line_alpha *= pixel_fade;
	
	float fade = 1.0;
	if (fade_edges) {
		vec2 uv = UV * 2.0 - 1.0;
		if (plane_dimensions.x < plane_dimensions.y)
			uv.y *= plane_dimensions.y / plane_dimensions.x;
		else
			uv.x *= plane_dimensions.x / plane_dimensions.y;
		
		float len = length(uv);
		fade = 1.0 - len;
		fade = smoothstep(0.0, edges_fade_smoothness, fade);
	}
	
	ALBEDO = grid_color.rgb;
	ALPHA = fade * line_alpha * grid_color.a;
}