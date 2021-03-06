#version 330 core

layout (points) in;
layout (triangle_strip, max_vertices = 6) out;

in PASSTHROUGH {
    float length;
    float rotation;
} passthrough[];

uniform mat4 projection;

out vec2 texture_uv;

vec2 vertices[6] = vec2[](
        vec2(-0.03, 0.0),
        vec2(-0.03, -1.0),
        vec2(0.03, -1.0),
        vec2(-0.03, 0.0),
        vec2(0.03, -1.0),
        vec2(0.03, 0.0)
);

const vec2 rotation_center = vec2(0.0, 0.0);

vec2 rotate(vec2 displacement) {
    float angle = passthrough[0].rotation;
    vec2 centered = displacement - rotation_center;
    centered = vec2(
            centered.x * cos(angle) - centered.y * sin(angle),
            centered.x * sin(angle) + centered.y * cos(angle));
    return centered + rotation_center;
}

void add_point(vec2 displacement) {
    vec2 rotated = rotate(displacement);
    vec4 point = gl_in[0].gl_Position + vec4(rotated, 0.0, 0.0);
    gl_Position = projection * point;
    texture_uv = displacement;
    EmitVertex();
}

void main() {
    vec2 scale = vec2(2.0, passthrough[0].length);
    for (int i = 0; i < 3; ++i) {
        add_point(vertices[i] * scale);
    }
    EndPrimitive();

    for (int i = 3; i < 6; ++i) {
        add_point(vertices[i] * scale);
    }
    EndPrimitive();
}
 
