const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const TextureAtlas = @import("atlas.zig").TextureAtlas;
const ShaderProgram = @import("shader.zig").ShaderProgram;
const c = @import("../c.zig");
const Direction = @import("../entities.zig").Direction;
const State = @import("../state.zig").State;
const pVec2f = @import("utils.zig").pVec2f;
const display = @import("../display.zig");
const GRID_SIZE = display.GRID_SIZE;

usingnamespace @import("../vec.zig");

const vertex_shader_src = @embedFile("ui_vertex.glsl");
const fragment_shader_src = @embedFile("ui_fragment.glsl");

var vao: c.GLuint = undefined;
var vbo: c.GLuint = undefined;
var projection_location: c.GLint = undefined;
var transparency_location: c.GLint = undefined;

var atlas: TextureAtlas = undefined;
pub var shader: ShaderProgram = undefined;

var queued_elements: ArrayList(BufferData) = undefined;

pub fn init(allocator: *Allocator) void {
    queued_elements = ArrayList(BufferData).init(allocator);

    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);

    const vertex = [_][*c]const u8{vertex_shader_src[0..].ptr};
    const fragment = [_][*c]const u8{fragment_shader_src[0..].ptr};
    shader = ShaderProgram.new(
        @ptrCast([*c]const [*c]const u8, &vertex),
        null,
        @ptrCast([*c]const [*c]const u8, &fragment),
    );
    shader.link();
    shader.set_active();
    projection_location = shader.uniform_location("projection");
    transparency_location = shader.uniform_location("transparency");

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

const BufferData = packed struct {
    pos: pVec2f,
    tex_coord: pVec2f,
};

fn collect_data(location: Rectf, texture_id: usize, buffer: []BufferData) void {
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
        const data = BufferData{
            .pos = pVec2f{
                .x = vertices[2 * i],
                .y = vertices[2 * i + 1],
            },
            .tex_coord = pVec2f{
                .x = uvs[2 * i],
                .y = uvs[2 * i + 1],
            },
        };
        buffer[i] = data;
    }
}

pub fn queue_element(
    state: *const State,
    location: Rectf,
    texture_id: usize,
) !void {
    var buffer: [6]BufferData = undefined;
    collect_data(location, texture_id, buffer[0..]);
    for (buffer) |*data| try queued_elements.append(data.*);
}

fn draw_image(
    dest: Rectf,
    texture_id: usize,
    transparency: f32,
    projection_matrix: *[16]f32,
) void {
    var buffer: [6]BufferData = undefined;
    collect_data(dest, texture_id, buffer[0..]);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(BufferData) * 6,
        @ptrCast(?*const c_void, &buffer[0]),
        c.GL_STREAM_DRAW,
    );

    c.glBindVertexArray(vao);
    shader.set_active();
    atlas.bind();
    c.glUniformMatrix4fv(
        projection_location,
        1,
        c.GL_TRUE,
        projection_matrix,
    );
    c.glUniform1f(transparency_location, transparency);
    c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
}

pub inline fn draw_on_world(
    dest: Rectf,
    texture_id: usize,
    transparency: f32,
) void {
    draw_image(dest, texture_id, transparency, &display.world_matrix);
}

pub inline fn draw_on_screen(
    dest: Rectf,
    texture_id: usize,
    transparency: f32,
) void {
    draw_image(dest, texture_id, transparency, &display.screen_matrix);
}

pub fn draw_queued(transparency: f32) !void {
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
    c.glUniformMatrix4fv(
        projection_location,
        1,
        c.GL_TRUE,
        &display.world_matrix,
    );
    const trans_uniform_loc = shader.uniform_location("transparency");
    c.glUniform1f(trans_uniform_loc, transparency);
    c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c_int, element_data.len));
    try queued_elements.resize(0);
}
