const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const ShaderProgram = @import("shader.zig").ShaderProgram;
const c = @import("../c.zig");
const entities = @import("../entities.zig");
const Direction = entities.Direction;
const State = @import("../state.zig").State;
const vec = @import("../vec.zig");
const Vec2i = vec.Vec2i;
const Vec2f = vec.Vec2f;

const display = @import("../display.zig");
const GRID_SIZE = display.GRID_SIZE;
const SCREEN_WIDTH = display.SCREEN_WIDTH;
const SCREEN_HEIGHT = display.SCREEN_HEIGHT;

const vertex_shader_src =
    c\\#version 330 core
    c\\
    c\\layout (location = 0) in vec2 position;
    c\\layout (location = 1) in float rotation;
    c\\
    c\\out PASSTHROUGH {
    c\\    float rotation;
    c\\} passthrough;
    c\\
    c\\void main() {
    c\\    gl_Position = vec4(position.x, -position.y, 0.0, 1.0);
    c\\    passthrough.rotation = rotation;
    c\\}
;

const geometry_shader_src =
    c\\#version 330 core
    c\\
    c\\layout (points) in;
    c\\layout (triangle_strip, max_vertices = 6) out;
    c\\
    c\\in PASSTHROUGH {
    c\\    float rotation;
    c\\} passthrough[];
    c\\
    c\\uniform mat4 projection;
    c\\
    c\\out vec2 texture_uv;
    c\\
    c\\vec2 vertices[6] = vec2[](
    c\\    vec2(0.0, 0.0),
    c\\    vec2(0.0, -1.0),
    c\\    vec2(1.0, -1.0),
    c\\    vec2(0.0, 0.0),
    c\\    vec2(1.0, -1.0),
    c\\    vec2(1.0, 0.0)
    c\\);
    c\\
    c\\const vec2 rotation_center = vec2(0.5, 0.0);
    c\\
    c\\vec2 rotate(vec2 displacement) {
    c\\    float angle = passthrough[0].rotation;
    c\\    vec2 centered = displacement - rotation_center;
    c\\    centered = vec2(
    c\\        centered.x * cos(angle) - centered.y * sin(angle),
    c\\        centered.x * sin(angle) + centered.y * cos(angle));
    c\\    return centered + rotation_center;
    c\\}
    c\\
    c\\void add_point(vec2 displacement) {
    c\\    vec2 rotated = rotate(displacement);
    c\\    vec4 point = gl_in[0].gl_Position + 64.0 * vec4(rotated, 0.0, 0.0);
    c\\    point = projection * point;
    c\\    gl_Position = point + vec4(-1.0, 1.0, 0.0, 0.0);
    c\\    texture_uv = vec2(displacement.x, -displacement.y);
    c\\    EmitVertex();
    c\\}
    c\\
    c\\void main() {
    c\\    for (int i = 0; i < 3; ++i) {
    c\\        add_point(vertices[i]);
    c\\    }
    c\\    EndPrimitive();
    c\\
    c\\    for (int i = 3; i < 6; ++i) {
    c\\        add_point(vertices[i]);
    c\\    }
    c\\    EndPrimitive();
    c\\}
;

const fragment_shader_src =
    c\\#version 330 core
    c\\
    c\\in vec2 texture_uv;
    c\\
    c\\uniform sampler2D atlas;
    c\\
    c\\out vec4 outColor;
    c\\
    c\\void main() {
    c\\    //outColor = texture(atlas, texture_uv);
    c\\    outColor = vec4(1.0, 1.0, 1.0, 1.0);
    c\\}
;

var vao: c.GLuint = undefined;
var vbo: c.GLuint = undefined;
var shader: ShaderProgram = undefined;

pub fn init() void {
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);

    shader = ShaderProgram.new(
        &vertex_shader_src,
        &geometry_shader_src,
        &fragment_shader_src,
    );
    c.glBindFragDataLocation(shader.handle, 0, c"outColor");
    shader.link();
    shader.set_active();

    // 2B pos | 1B rotation
    const pos_attrib = 0;
    const rotation_attrib = 1;
    c.glEnableVertexAttribArray(pos_attrib);
    c.glEnableVertexAttribArray(rotation_attrib);
    c.glVertexAttribPointer(
        pos_attrib,
        2,
        c.GL_FLOAT,
        c.GL_FALSE,
        3 * @sizeOf(f32),
        @intToPtr(?*const c_void, 0),
    );
    c.glVertexAttribPointer(
        rotation_attrib,
        1,
        c.GL_FLOAT,
        c.GL_FALSE,
        3 * @sizeOf(f32),
        @intToPtr(*const c_void, 2 * @sizeOf(f32)),
    );
}

pub fn deinit() void {
    shader.deinit();
    c.glDeleteBuffers(1, &vbo);
    c.glDeleteVertexArrays(1, &vao);
}
