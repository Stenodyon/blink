#version 330 core

layout (points) in;
layout (triangle_strip, max_vertices = 6) out;

in PASSTHROUGH {
    vec2 uv;
    float rotation;
} passthrough[];

uniform mat4 projection;

out vec2 _texture_uv;

vec2 vertices[6] = vec2[](
    vec2(0.0, 0.0),
    vec2(1.0, 0.0),
    vec2(0.0, 1.0),
    vec2(0.0, 1.0),
    vec2(1.0, 0.0),
    vec2(1.0, 1.0)
);

const vec2 rotation_center = vec2(0.5, 0.5);

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
    _texture_uv = passthrough[0].uv + displacement / 8.0;
    EmitVertex();
}

void main() {
    for (int i = 0; i < 3; ++i) {
        add_point(vertices[i]);
    }
    EndPrimitive();

    for (int i = 3; i < 6; ++i) {
        add_point(vertices[i]);
    }
    EndPrimitive();
}
 
