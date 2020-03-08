const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const TextureAtlas = @import("../atlas.zig").TextureAtlas;
const ShaderProgram = @import("../shader.zig").ShaderProgram;
const c = @import("../../c.zig");
const Direction = @import("../../entities.zig").Direction;
const State = @import("../../state.zig").State;
const pVec2f = @import("../utils.zig").pVec2f;
const display = @import("../../display.zig");
const GRID_SIZE = display.GRID_SIZE;

usingnamespace @import("../../vec.zig");

const vertex_shader_src = @embedFile("ui_vertex.glsl");
const fragment_shader_src = @embedFile("ui_fragment.glsl");

var vao: c.GLuint = undefined;
var vbo: c.GLuint = undefined;
var projection_location: c.GLint = undefined;
var transparency_location: c.GLint = undefined;

var atlas: TextureAtlas = undefined;
pub var shader: ShaderProgram = undefined;

var queued_elements: ArrayList(BufferData) = undefined;

const Frame = struct {
    body: usize,
    top: usize,
    bottom: usize,
    left: usize,
    right: usize,
    topleft: usize,
    topright: usize,
    bottomleft: usize,
    bottomright: usize,
};

pub var id: struct {
    error_texture: usize,
    selection: usize,
    frame: Frame,
} = undefined;

pub fn init(allocator: *Allocator) !void {
    queued_elements = ArrayList(BufferData).init(allocator);

    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);

    const vertex = [_][*:0]const u8{vertex_shader_src};
    const fragment = [_][*:0]const u8{fragment_shader_src};
    shader = ShaderProgram.new(
        &vertex,
        null,
        &fragment,
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

    atlas = try TextureAtlas.load(allocator, "data/ui_atlas", 16, 16);

    id.error_texture = atlas.id_of("error").?;
    id.selection = atlas.id_of("selection").?;
    id.frame.body = atlas.id_of("frame_body").?;
    id.frame.top = atlas.id_of("frame_top").?;
    id.frame.bottom = atlas.id_of("frame_bottom").?;
    id.frame.left = atlas.id_of("frame_left").?;
    id.frame.right = atlas.id_of("frame_right").?;
    id.frame.topleft = atlas.id_of("frame_topleft").?;
    id.frame.topright = atlas.id_of("frame_topright").?;
    id.frame.bottomleft = atlas.id_of("frame_bottomleft").?;
    id.frame.bottomright = atlas.id_of("frame_bottomright").?;
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
    const texture = atlas.rect_of(texture_id);
    const vertices = [_]f32{
        pos.x,          pos.y,
        pos.x + size.x, pos.y,
        pos.x,          pos.y + size.y,
        pos.x,          pos.y + size.y,
        pos.x + size.x, pos.y,
        pos.x + size.x, pos.y + size.y,
    };

    const uvs = [_]f32{
        texture.pos.x,                  texture.pos.y,
        texture.pos.x + texture.size.x, texture.pos.y,
        texture.pos.x,                  texture.pos.y + texture.size.y,
        texture.pos.x,                  texture.pos.y + texture.size.y,
        texture.pos.x + texture.size.x, texture.pos.y,
        texture.pos.x + texture.size.x, texture.pos.y + texture.size.y,
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

pub fn draw_frame(dest: Rectf, border_width: f32, frame: *const Frame) void {
    var buffer: [6 * 9]BufferData = undefined;

    collect_data(
        Rectf.box(
            dest.pos.x,
            dest.pos.y,
            border_width,
            border_width,
        ),
        frame.topleft,
        buffer[0..],
    );
    collect_data(
        Rectf.box(
            dest.pos.x + border_width,
            dest.pos.y,
            dest.size.x - 2 * border_width,
            border_width,
        ),
        frame.top,
        buffer[6..],
    );
    collect_data(
        Rectf.box(
            dest.pos.x + dest.size.x - border_width,
            dest.pos.y,
            border_width,
            border_width,
        ),
        frame.topright,
        buffer[12..],
    );
    collect_data(
        Rectf.box(
            dest.pos.x,
            dest.pos.y + border_width,
            border_width,
            dest.size.y - 2 * border_width,
        ),
        frame.left,
        buffer[18..],
    );
    collect_data(
        Rectf.box(
            dest.pos.x + border_width,
            dest.pos.y + border_width,
            dest.size.x - 2 * border_width,
            dest.size.y - 2 * border_width,
        ),
        frame.body,
        buffer[24..],
    );
    collect_data(
        Rectf.box(
            dest.pos.x + dest.size.x - border_width,
            dest.pos.y + border_width,
            border_width,
            dest.size.y - 2 * border_width,
        ),
        frame.right,
        buffer[30..],
    );
    collect_data(
        Rectf.box(
            dest.pos.x,
            dest.pos.y + dest.size.y - border_width,
            border_width,
            border_width,
        ),
        frame.bottomleft,
        buffer[36..],
    );
    collect_data(
        Rectf.box(
            dest.pos.x + border_width,
            dest.pos.y + dest.size.y - border_width,
            dest.size.x - 2 * border_width,
            border_width,
        ),
        frame.bottom,
        buffer[42..],
    );
    collect_data(
        Rectf.box(
            dest.pos.x + dest.size.x - border_width,
            dest.pos.y + dest.size.y - border_width,
            border_width,
            border_width,
        ),
        frame.bottomright,
        buffer[48..],
    );

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(BufferData) * 6 * 9,
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
        &display.screen_matrix,
    );
    c.glUniform1f(transparency_location, 0.0);
    c.glDrawArrays(c.GL_TRIANGLES, 0, 6 * 9);
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
