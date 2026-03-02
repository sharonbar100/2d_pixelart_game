shader_type canvas_item;
render_mode unshaded;

// --- Inspector Sliders ---
// How far apart the Red and Blue channels separate (1.0 to 3.0 is usually best)
uniform float aberration_amount : hint_range(0.0, 10.0) = 2.0; 
// How dark the scanlines are (0.0 is invisible, 1.0 is pitch black)
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.35;
// Boosts the game's lighting to make up for the dark lines/corners
uniform float brightness_multiplier : hint_range(1.0, 3.0) = 1.2; 
// How dark the corners get
uniform float vignette_multiplier : hint_range(0.0, 5.0) = 2.0;

uniform sampler2D screen_texture: hint_screen_texture, filter_nearest;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 centered_uv = uv * 2.0 - 1.0;
    
    // 1. Chromatic Aberration (RGB Split)
    // SCREEN_PIXEL_SIZE makes sure the shift scales perfectly with your resolution
    vec2 shift = vec2(aberration_amount * SCREEN_PIXEL_SIZE.x, 0.0);
    
    // Sample the screen 3 different times, slightly offset left and right
    float r = texture(screen_texture, uv - shift).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv + shift).b;
    vec3 screen_color = vec3(r, g, b);
    
    // 2. Perfect 180p Scanlines
    // Using 3.14159 (PI) perfectly aligns the sine wave to your 180 vertical pixels
    float scanline_wave = sin(uv.y * 180.0 * 3.14159);
    // Convert the wave into a smooth darkening effect based on your opacity slider
    float scanline_blend = mix(1.0, (scanline_wave * 0.5 + 0.5), scanline_opacity);
    screen_color *= scanline_blend;
    
    // 3. Brightness Boost
    screen_color *= brightness_multiplier;
    
    // 4. Vignette
    vec3 vignette = vec3(length(pow(abs(centered_uv), vec2(4.0)) / 3.0));
    screen_color -= vignette * vignette_multiplier;
    
    COLOR = vec4(screen_color, 1.0);
}