const std = @import("std");

const c = @import("../c.zig");
const ShaderProgram = @import("shader.zig").ShaderProgram;
const State = @import("../state.zig").State;
const vec = @import("../vec.zig");
const Vec2i = vec.Vec2i;
const Vec2f = vec.Vec2f;

const display = @import("../display.zig");
const GRID_SIZE = display.GRID_SIZE;

const vertex_shader_src =
    \\#version 330 core
    \\
    \\layout (location = 0) in vec2 position;
    \\
    \\uniform mat4 projection;
    \\
    \\out vec2 pixel_pos;
    \\
    \\void main() {
    \\    pixel_pos = position.xy;
    \\    gl_Position = projection * vec4(position.xy, 0.0, 1.0);
    \\}
;

const fragment_shader_src =
    \\#version 330 core
    \\
    \\in vec2 pixel_pos;
    \\
    \\out vec4 outColor;
    \\
    \\const vec4 bgColor = vec4(0.43, 0.47, 0.53, 1.0);
    \\const vec4 fgColor = vec4(0.22, 0.23, 0.27, 1.0);
    \\
    \\void main() {
    \\    vec2 lines = abs(fract(pixel_pos - 0.5) - 0.5) / fwidth(pixel_pos);
    \\    float grid = min(min(lines.x, lines.y), 1.0);
    \\    outColor = fgColor * (1.0 - grid) + bgColor * grid;
    \\}
;

var vao: c.GLuint = undefined;
var vbo: c.GLuint = undefined;
var shader: ShaderProgram = undefined;
var projection_location: c.GLint = undefined;
var vertices: [12]f32 = undefined;

pub fn init() void {
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);

    shader = ShaderProgram.new(
        @ptrCast([*c]const [*c]const u8, &[_][]const u8{vertex_shader_src}),
        null,
        @ptrCast([*c]const [*c]const u8, &[_][]const u8{fragment_shader_src}),
    );
    c.glBindFragDataLocation(shader.handle, 0, "outColor");
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

pub fn update_vertices(state: *const State) void {
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    const x = state.viewpos.x;
    const y = state.viewpos.y;
    const width = state.viewport.x / 2;
    const height = state.viewport.y / 2;
    const new_vertices = [_]f32{
        x - width, y - height,
        x + width, y - height,
        x - width, y + height,
        x - width, y + height,
        x + width, y - height,
        x + width, y + height,
    };
    for (vertices) |*vertex, i| vertex.* = new_vertices[i];
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(f32) * @intCast(c_long, vertices.len),
        @ptrCast(?*const c_void, &vertices),
        c.GL_STREAM_DRAW,
    );
}

pub fn render(state: *const State) void {
    c.glBindVertexArray(vao);
    shader.set_active();
    update_vertices(state);

    c.glUniformMatrix4fv(
        projection_location,
        1,
        c.GL_TRUE,
        &display.world_matrix,
    );

    c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
}
