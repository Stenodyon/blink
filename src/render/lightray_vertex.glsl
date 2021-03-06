#version 330 core

layout (location = 0) in vec2 position;
layout (location = 1) in float length;
layout (location = 2) in float rotation;

out PASSTHROUGH {
    float length;
    float rotation;
} passthrough;

void main() {
    gl_Position = vec4(position.xy, 0.0, 1.0);
    passthrough.length = length;
    passthrough.rotation = rotation;
}
 
