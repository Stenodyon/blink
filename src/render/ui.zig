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

const texture_vertex_shader = @embedFile("ui_texture_vertex.glsl");
const texture_fragment_shader = @embedFile("ui_texture_fragment.glsl");

const color_vertex_shader = @embedFile("ui_color_vertex.glsl");
const color_fragment_shader = @embedFile("ui_color_fragment.glsl");

var vao: c.GLuint = undefined;
var vbo: c.GLuint = undefined;
var image_proj_location: c.GLint = undefined;
var color_proj_location: c.GLint = undefined;
var transparency_location: c.GLint = undefined;

var atlas: TextureAtlas = undefined;
pub var image_shader: ShaderProgram = undefined;
var color_shader: ShaderProgram = undefined;

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

    const image_vertex = [_][*c]const u8{texture_vertex_shader[0..].ptr};
    const image_fragment = [_][*c]const u8{texture_fragment_shader[0..].ptr};
    image_shader = ShaderProgram.new(
        @ptrCast([*c]const [*c]const u8, &image_vertex),
        null,
        @ptrCast([*c]const [*c]const u8, &image_fragment),
    );
    image_shader.link();
    image_shader.set_active();
    image_proj_location = image_shader.uniform_location("projection");
    transparency_location = image_shader.uniform_location("transparency");

    const color_vertex = [_][*]const u8{color_vertex_shader[0..].ptr};
    const color_fragment = [_][*]const u8{color_fragment_shader[0..].ptr};
    color_shader = ShaderProgram.new(
        @ptrCast([*c]const [*c]const u8, &color_vertex),
        null,
        @ptrCast([*c]const [*c]const u8, &color_fragment),
    );
    color_shader.link();
    color_shader.set_active();
    color_proj_location = color_shader.uniform_location("projection");

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
    image_shader.deinit();
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

pub fn draw_image_world(location: Vec2f, texture: Rectf, transparency: f32) void {
    c.glBindVertexArray(vao);
    image_shader.set_active();
    atlas.bind();
    display.set_proj_matrix_uniform(&image_shader, image_proj_location);
    c.glUniform1f(transparency_location, transparency);
    c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c_int, element_data.len));
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
    image_shader.set_active();
    atlas.bind();
    c.glUniformMatrix4fv(
        image_proj_location,
        1,
        c.GL_TRUE,
        &display.world_matrix,
    );
    const trans_uniform_loc = image_shader.uniform_location("transparency");
    c.glUniform1f(trans_uniform_loc, transparency);
    c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c_int, element_data.len));
    try queued_elements.resize(0);
}
