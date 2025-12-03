shader_type canvas_item;

uniform float star_density : hint_range(0.0, 1.0) = 0.05;
uniform float brightness = 1.5;
uniform float scale = 1.0;
uniform vec2 offset; // you can animate this for movement

// Simple hash-based noise (non-tiling)
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    // Scale + world offset
    vec2 uv = (UV * scale) + offset;

    // Sample 2 layers of noise at different scales
    float n1 = hash21(floor(uv * 500.0));
    float n2 = hash21(floor(uv * 850.0 + vec2(100.0, 200.0)));

    // Combine the layers so stars appear where either noise is very bright
    float star = max(n1, n2);

    // Threshold based on density
    star = step(1.0 - star_density, star);

    // Simple star brightness curve
    COLOR = vec4(vec3(star * brightness), 1.0);
}
