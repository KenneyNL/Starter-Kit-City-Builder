shader_type spatial;

// Parameters for customization
uniform float alpha : hint_range(0.0, 1.0) = 0.3;
uniform float progress : hint_range(0.0, 1.0) = 0.0;  // Construction progress from 0 to 1
uniform vec4 fill_color : source_color = vec4(0.2, 0.5, 0.8, 0.3);  // Light blue, semi-transparent
uniform vec4 outline_color : source_color = vec4(0.0, 0.6, 1.0, 1.0);  // Bright blue
uniform float outline_width : hint_range(0.0, 0.1) = 0.02;
uniform float grid_scale : hint_range(1.0, 50.0) = 20.0;
uniform float grid_width : hint_range(0.0, 0.1) = 0.02;

varying vec3 vertex_pos;
varying vec3 normal;

void vertex() {
    vertex_pos = VERTEX;
    normal = NORMAL;
}

float grid(vec2 uv) {
    vec2 grid = fract(uv * grid_scale);
    float lines = step(grid_width, grid.x) * step(grid_width, grid.y);
    return 1.0 - lines;
}

void fragment() {
    // Calculate fill effect based on vertical position
    // Map vertex Y position to [0,1] range, ensuring we cover the full model height
    float height = (vertex_pos.y + 1.0) * 0.5;  // First map from [-1,1] to [0,1]
    height = clamp(height, 0.0, 1.0);  // Ensure we stay within [0,1]
    float fill_threshold = progress;
    
    // Create the fill effect
    if (height < fill_threshold) {
        // Below the fill line - show the fill color
        ALBEDO = fill_color.rgb;
        ALPHA = fill_color.a;
        
        // Add some emission for a glowing effect
        EMISSION = fill_color.rgb * 0.5;
    } else {
        // Above the fill line - show outline only
        float edge_distance = abs(height - fill_threshold);
        if (edge_distance < outline_width) {
            // Draw the outline at the fill level
            ALBEDO = outline_color.rgb;
            ALPHA = outline_color.a;
            EMISSION = outline_color.rgb;
        } else {
            // Make the unfilled part transparent
            ALPHA = alpha * 0.3;  // More transparent above the fill line
            ALBEDO = fill_color.rgb;
        }
    }
    
    // Add grid pattern
    vec2 uv = vec2(
        dot(normalize(vertex_pos), vec3(1.0, 0.0, 0.0)),
        dot(normalize(vertex_pos), vec3(0.0, 1.0, 0.0))
    );
    float grid_pattern = grid(uv);
    EMISSION += fill_color.rgb * grid_pattern * 0.2;
    
    // Add edge highlighting
    float fresnel = pow(1.0 - dot(normalize(normal), normalize(VIEW)), 5.0);
    float outline = step(1.0 - outline_width, fresnel);
    EMISSION += outline_color.rgb * outline * 2.0;
    
    // Metallic/Roughness settings for a holographic look
    METALLIC = 0.8;
    ROUGHNESS = 0.2;
} 