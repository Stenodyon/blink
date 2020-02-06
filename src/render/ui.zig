const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const TextureAtlas = @import("atlas.zig").TextureAtlas;
const ShaderProgram = @import("shader.zig").ShaderProgram;

const c = @import("../c.zig");
const entities = @import("../entities.zig");
const Direction = entities.Direction;
const State = @import("../state.zig").State;
usingnamespace @import("../vec.zig");
const pVec2f = @import("utils.zig").pVec2f;

const display = @import("../display.zig");
const GRID_SIZE = display.GRID_SIZE;

const vertex_shader_src =
    \\#version 330 core
    \\
    \\layout (location = 0) in vec2 position;
    \\layout (location = 1) in vec2 texture_uv;
    \\
    \\uniform mat4 projection;
    \\
    \\out vec2 uv;
    \\
    \\void main() {
    \\    gl_Position = projection * vec4(position.xy, 0.0, 1.0);
    \\    uv = texture_uv;
    \\}
;

const fragment_shader_src =
    \\#version 330 core
    \\
    \\in vec2 uv;
    \\
    \\uniform float transparency;
    \\uniform sampler2D atlas;
    \\
    \\void main() {
    \\    vec4 color = texture(atlas, uv);
    \\    color.a *= 1.0 - transparency;
    \\    gl_FragColor = color;
    \\    //gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
    \\}
;

var vao: c.GLuint = undefined;
var vbo: c.GLuint = undefined;
var projection_location: c.GLint = undefined;

var atlas: TextureAtlas = undefined;
pub var shader: ShaderProgram = undefined;

const BufferData = packed struct {
    pos: pVec2f,
    tex_coord: pVec2f,
};

var queued_elements: ArrayList(BufferData) = undefined;

pub fn init(allocator: *Allocator) void {
    queued_elements = ArrayList(BufferData).init(allocator);

    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);

    std.debug.warn("Compiling shaders for ui\n", .{});
    shader = ShaderProgram.new(
        @ptrCast([*c]const [*c]const u8, &[_][]const u8{vertex_shader_src}),
        null,
        @ptrCast([*c]const [*c]const u8, &[_][]const u8{fragment_shader_src}),
    );
    shader.link();
    shader.set_active();
    projection_location = shader.uniform_location("projection");

    const pos_attrib = 0;
    const uv_attrib = 1;
    c.glEnableVertexAttribArray(pos_attrib);
    c.glEnableVertexAttribArray(uv_attrib);
    c.glVertexAttribPointer(
        pos_attrib,
        2,
        c.GL_FLOAT,
        c.GL_FALSE,
        4 * @sizeOf(f32),
        @intToPtr(?*const c_void, 0),
    );
    c.glVertexAttribPointer(
        uv_attrib,
        2,
        c.GL_FLOAT,
        c.GL_FALSE,
        4 * @sizeOf(f32),
        @intToPtr(*const c_void, 2 * @sizeOf(f32)),
    );

    atlas = TextureAtlas.load(allocator, "data/ui_atlas.png", 16, 16);
}

pub fn deinit() void {
    atlas.deinit();
    shader.deinit();
    queued_elements.deinit();

    c.glDeleteBuffers(1, &vbo);
    c.glDeleteVertexArrays(1, &vao);
}

pub fn queue_element(
    state: *const State,
    location: Rectf,
    texture_id: usize,
) !void {
    const pos = location.pos;
    const size = location.size;
    const texture_pos = atlas.get_offset(texture_id);
    const vertices = [_]f32{
        pos.x,          pos.y,
        pos.x + size.x, pos.y,
        pos.x,          pos.y + size.y,
        pos.x,          pos.y + size.y,
        pos.x + size.x, pos.y,
        pos.x + size.x, pos.y + size.y,
    };

    const cell_width = @intToFloat(f32, atlas.cell_width) / @intToFloat(f32, atlas.width);
    const cell_height = @intToFloat(f32, atlas.cell_height) / @intToFloat(f32, atlas.height);
    const uvs = [_]f32{
        texture_pos.x,              texture_pos.y,
        texture_pos.x + cell_width, texture_pos.y,
        texture_pos.x,              texture_pos.y + cell_height,
        texture_pos.x,              texture_pos.y + cell_height,
        texture_pos.x + cell_width, texture_pos.y,
        texture_pos.x + cell_width, texture_pos.y + cell_height,
    };

    var i: usize = 0;
    while (i < 6) : (i += 1) {
        const queued = BufferData{
            .pos = pVec2f{
                .x = vertices[2 * i],
                .y = vertices[2 * i + 1],
            },
            .tex_coord = pVec2f{
                .x = uvs[2 * i],
                .y = uvs[2 * i + 1],
            },
        };
        try queued_elements.append(queued);
    }
}

pub fn draw(transparency: f32) !void {
    const element_data = queued_elements.toSlice();
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(BufferData) * @intCast(c_long, element_data.len),
        @ptrCast(?*const c_void, element_data.ptr),
        c.GL_STREAM_DRAW,
    );

    c.glBindVertexArray(vao);
    shader.set_active();
    atlas.bind();
    display.set_proj_matrix_uniform(&shader, projection_location);
    const trans_uniform_loc = shader.uniform_location("transparency");
    c.glUniform1f(trans_uniform_loc, transparency);
    c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c_int, element_data.len));
    try queued_elements.resize(0);
}
