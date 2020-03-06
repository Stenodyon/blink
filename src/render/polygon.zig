const std = @import("std");

const c = @import("../c.zig");
const display = @import("../display.zig");
const ShaderProgram = @import("shader.zig").ShaderProgram;

const vertex_shader_src =
    \\#version 330 core
    \\
    \\layout (location = 0) in vec2 position;
    \\
    \\uniform mat4 projection;
    \\
    \\void main() {
    \\    gl_Position = projection * vec4(position.xy, 0.0, 1.0);
    \\}
;

const fragment_shader_src =
    \\#version 330 core
    \\
    \\void main() {
    \\    gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
    \\}
;

var vao: c.GLuint = undefined;
var vbo: c.GLuint = undefined;
pub var shader: ShaderProgram = undefined;
var projection_location: c.GLint = undefined;

pub fn init() void {
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);

    shader = ShaderProgram.new(
        &[_][*:0]const u8{vertex_shader_src},
        null,
        &[_][*:0]const u8{fragment_shader_src},
    );
    shader.link();
    shader.set_active();
    projection_location = shader.uniform_location("projection");

    const pos_attrib = 0;
    c.glEnableVertexAttribArray(pos_attrib);
    c.glVertexAttribPointer(
        pos_attrib,
        2,
        c.GL_FLOAT,
        c.GL_FALSE,
        2 * @sizeOf(f32),
        @intToPtr(?*const c_void, 0),
    );
}

pub fn deinit() void {
    shader.deinit();
    c.glDeleteBuffers(1, &vbo);
    c.glDeleteVertexArrays(1, &vao);
}

pub fn draw_polygon(polygon: []const f32) void {
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(f32) * @intCast(c_long, polygon.len),
        @ptrCast(?*const c_void, polygon.ptr),
        c.GL_STREAM_DRAW,
    );

    c.glBindVertexArray(vao);
    shader.set_active();
    c.glUniformMatrix4fv(
        projection_location,
        1,
        c.GL_TRUE,
        &display.world_matrix,
    );
    c.glDrawArrays(c.GL_LINE_LOOP, 0, @intCast(c_int, polygon.len / 2));
}
