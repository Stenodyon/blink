#version 330 core

in vec2 pixel_pos;

out vec4 outColor;

const vec4 bgColor = vec4(0.43, 0.47, 0.53, 1.0);
const vec4 fgColor = vec4(0.22, 0.23, 0.27, 1.0);

void main() {
    vec2 lines = abs(fract(pixel_pos - 0.5) - 0.5) / fwidth(pixel_pos);
    float grid = min(min(lines.x, lines.y), 1.0);
    outColor = fgColor * (1.0 - grid) + bgColor * grid;
}
 
