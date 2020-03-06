#version 330 core

layout (location = 0) in vec2 position;

uniform mat4 projection;

out vec2 pixel_pos;

void main() {
    pixel_pos = position.xy;
    gl_Position = projection * vec4(position.xy, 0.0, 1.0);
}
 
