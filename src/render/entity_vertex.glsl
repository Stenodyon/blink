#version 330 core

layout (location = 0) in vec2 position;
layout (location = 1) in vec2 texture_uv;
layout (location = 2) in float rotation;

uniform mat4 projection;

out PASSTHROUGH {
    vec2 uv;
    float rotation;
} passthrough;

void main() {
    gl_Position = vec4(position.xy, 0.0, 1.0);
    passthrough.uv = texture_uv;
    passthrough.rotation = rotation;
}
 
