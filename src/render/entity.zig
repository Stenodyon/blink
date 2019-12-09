const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const TextureAtlas = @import("atlas.zig").TextureAtlas;
const ShaderProgram = @import("shader.zig").ShaderProgram;

const c = @import("../c.zig");
const entities = @import("../entities.zig");
const Entity = entities.Entity;
const Direction = entities.Direction;
const State = @import("../state.zig").State;
const vec = @import("../vec.zig");
const Vec2i = vec.Vec2i;
const Vec2f = vec.Vec2f;
const pVec2f = @import("utils.zig").pVec2f;

const display = @import("../display.zig");
const GRID_SIZE = display.GRID_SIZE;

const vertex_shader_src = @embedFile("entity_vertex.glsl");
const vertex_shader_src_list = [_][]const u8{&vertex_shader_src};

const geometry_shader_src = @embedFile("entity_geometry.glsl");
const geometry_shader_src_list = [_][]const u8{&geometry_shader_src};

const fragment_shader_src = @embedFile("entity_fragment.glsl");
const fragment_shader_src_list = [_][]const u8{&fragment_shader_src};

var vao: c.GLuint = undefined;
var vbo: c.GLuint = undefined;
var projection_location: c.GLint = undefined;
var transparency_location: c.GLint = undefined;

var atlas: TextureAtlas = undefined;
pub var shader: ShaderProgram = undefined;

const BufferData = packed struct {
    pos: pVec2f,
    tex_coord: pVec2f,
    rotation: f32,
};

var queued_entities: ArrayList(BufferData) = undefined;

pub fn init(allocator: *Allocator) void {
    queued_entities = ArrayList(BufferData).init(allocator);

    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);

    shader = ShaderProgram.new(
        @ptrCast([*c]const [*c]const u8, &vertex_shader_src_list),
        @ptrCast([*c]const [*c]const u8, &geometry_shader_src_list),
        @ptrCast([*c]const [*c]const u8, &fragment_shader_src_list),
    );
    c.glBindFragDataLocation(shader.handle, 0, c"outColor");
    shader.link();
    shader.set_active();
    projection_location = shader.uniform_location(c"projection");
    transparency_location = shader.uniform_location(c"transparency");

    const pos_attrib = 0;
    const uv_attrib = 1;
    const rotation = 2;
    c.glEnableVertexAttribArray(pos_attrib);
    c.glEnableVertexAttribArray(uv_attrib);
    c.glEnableVertexAttribArray(rotation);
    c.glVertexAttribPointer(
        pos_attrib,
        2,
        c.GL_FLOAT,
        c.GL_FALSE,
        5 * @sizeOf(f32),
        @intToPtr(?*const c_void, 0),
    );
    c.glVertexAttribPointer(
        uv_attrib,
        2,
        c.GL_FLOAT,
        c.GL_FALSE,
        5 * @sizeOf(f32),
        @intToPtr(*const c_void, 2 * @sizeOf(f32)),
    );
    c.glVertexAttribPointer(
        rotation,
        1,
        c.GL_FLOAT,
        c.GL_FALSE,
        5 * @sizeOf(f32),
        @intToPtr(*const c_void, 4 * @sizeOf(f32)),
    );

    atlas = TextureAtlas.load(allocator, c"data/entity_atlas.png", 16, 16);
}

pub fn deinit() void {
    atlas.deinit();
    shader.deinit();
    queued_entities.deinit();

    c.glDeleteBuffers(1, &vbo);
    c.glDeleteVertexArrays(1, &vao);
}

fn get_entity_texture(entity: *const Entity) Vec2f {
    switch (entity.*) {
        .Block => return atlas.get_offset(1),
        .Laser => |direction| return atlas.get_offset(2),
        .Mirror => |direction| return atlas.get_offset(3),
        .DoubleMirror => |direction| return atlas.get_offset(10),
        .Splitter => |direction| return atlas.get_offset(4),
        .Switch => |*eswitch| {
            return atlas.get_offset_flip(5, eswitch.is_flipped, false);
        },
        .Delayer => |*delayer| {
            if (delayer.is_on) {
                return atlas.get_offset(7);
            } else {
                return atlas.get_offset(6);
            }
        },
        .Lamp => |is_on| {
            if (is_on) {
                return atlas.get_offset(9);
            } else {
                return atlas.get_offset(8);
            }
        },
    }
}

pub inline fn queue_entity(
    state: *const State,
    grid_pos: Vec2i,
    entity: *const Entity,
) !void {
    try queue_entity_float(state, grid_pos, entity);
}

pub fn queue_entity_float(
    state: *const State,
    grid_pos: Vec2i,
    entity: *const Entity,
) !void {
    const texture_pos = get_entity_texture(entity);
    const texture_size = atlas.get_tile_size();
    const angle = entity.get_direction().to_rad();
    const pos = grid_pos.to_float(f32);

    const queued = BufferData{
        .pos = pVec2f{
            .x = pos.x,
            .y = pos.y,
        },
        .tex_coord = pVec2f{
            .x = texture_pos.x,
            .y = texture_pos.y,
        },
        .rotation = angle,
    };

    try queued_entities.append(queued);
}

pub fn collect(state: *const State) !void {
    const viewpos = state.viewpos.floor();
    const viewport = state.viewport.divf(2).ceil();

    var grid_y: i32 = viewpos.y - viewport.y;
    while (grid_y < viewpos.y + viewport.y) : (grid_y += 1) {
        var grid_x: i32 = viewpos.x - viewport.x;
        while (grid_x < viewpos.x + viewport.x) : (grid_x += 1) {
            const grid_pos = Vec2i.new(grid_x, grid_y);
            const entry = state.entities.get(grid_pos) orelse continue;
            try queue_entity(state, grid_pos, &entry.value);
        }
    }
}

pub fn draw(transparency: f32) !void {
    const entity_data = queued_entities.toSlice();
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(BufferData) * @intCast(c_long, entity_data.len),
        @ptrCast(?*const c_void, entity_data.ptr),
        c.GL_STREAM_DRAW,
    );

    c.glBindVertexArray(vao);
    shader.set_active();
    atlas.bind();
    display.set_proj_matrix_uniform(&shader, projection_location);
    c.glUniform1f(transparency_location, transparency);
    c.glDrawArrays(c.GL_POINTS, 0, @intCast(c_int, entity_data.len));
    try queued_entities.resize(0);
}
