shader_type spatial;

// Parameters
uniform float progress : hint_range(0.0, 1.0) = 0.0;  // Construction progress
uniform vec4 fill_color : source_color = vec4(0.2, 0.5, 0.8, 0.3);  // Light blue, semi-transparent
uniform vec4 outline_color : source_color = vec4(0.0, 0.6, 1.0, 1.0);  // Bright blue
uniform float outline_thickness : hint_range(0.0, 0.1) = 0.02;

void vertex() {
    // No vertex modifications needed
}

void fragment() {
    // Calculate fill effect based on vertical position
    float height = (VERTEX.y + 1.0) * 0.5;  // Convert from [-1,1] to [0,1] range
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
        if (edge_distance < outline_thickness) {
            // Draw the outline at the fill level
            ALBEDO = outline_color.rgb;
            ALPHA = outline_color.a;
            EMISSION = outline_color.rgb;
        } else {
            // Make the unfilled part transparent
            ALPHA = 0.1;
            ALBEDO = fill_color.rgb;
        }
    }
    
    // Add edge highlighting
    vec3 normal = normalize(NORMAL);
    float fresnel = pow(1.0 - dot(normal, VIEW), 3.0);
    EMISSION += outline_color.rgb * fresnel * 0.5;
} 