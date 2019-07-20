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

const display = @import("../display.zig");
const GRID_SIZE = display.GRID_SIZE;
const SCREEN_WIDTH = display.SCREEN_WIDTH;
const SCREEN_HEIGHT = display.SCREEN_HEIGHT;

const vertex_shader_src =
    c\\#version 330 core
    c\\
    c\\layout (location = 0) in vec2 position;
    c\\layout (location = 1) in vec2 texture_uv;
    c\\layout (location = 2) in float rotation;
    c\\
    c\\out PASSTHROUGH {
    c\\    vec2 uv;
    c\\    float rotation;
    c\\} passthrough;
    c\\
    c\\void main() {
    c\\    gl_Position = vec4(position.x, -position.y, 0.0, 1.0);
    c\\    passthrough.uv = texture_uv;
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
    c\\    vec2 uv;
    c\\    float rotation;
    c\\} passthrough[];
    c\\
    c\\uniform mat4 projection;
    c\\
    c\\out vec2 _texture_uv;
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
    c\\vec2 rotate(vec2 displacement) {
    c\\    float angle = passthrough[0].rotation;
    c\\    vec2 centered = displacement - vec2(0.5, -0.5);
    c\\    centered = vec2(
    c\\        centered.x * cos(angle) - centered.y * sin(angle),
    c\\        centered.x * sin(angle) + centered.y * cos(angle));
    c\\    return centered + vec2(0.5, -0.5);
    c\\}
    c\\
    c\\void add_point(vec2 displacement) {
    c\\    vec2 rotated = rotate(displacement);
    c\\    vec4 point = gl_in[0].gl_Position + 64.0 * vec4(rotated, 0.0, 0.0);
    c\\    point = projection * point;
    c\\    gl_Position = point + vec4(-1.0, 1.0, 0.0, 0.0);
    c\\    _texture_uv = passthrough[0].uv + vec2(displacement.x, -displacement.y) / 8.0;
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
    c\\in vec2 _texture_uv;
    c\\
    c\\uniform sampler2D atlas;
    c\\
    c\\out vec4 outColor;
    c\\
    c\\void main() {
    c\\    outColor = texture(atlas, _texture_uv);
    c\\}
;

var vao: c.GLuint = undefined;
var vbo: c.GLuint = undefined;

var atlas: TextureAtlas = undefined;
pub var shader: ShaderProgram = undefined;

const pVec2f = packed struct {
    x: f32,
    y: f32,
};

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
        &vertex_shader_src,
        &geometry_shader_src,
        &fragment_shader_src,
    );
    c.glBindFragDataLocation(shader.handle, 0, c"outColor");
    shader.link();
    shader.set_active();

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

    atlas = TextureAtlas.load(c"data/entity_atlas.png", 16, 16);
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
        .Splitter => |direction| return atlas.get_offset(4),
        .Switch => |*eswitch| return atlas.get_offset(5),
        .Delayer => |*delayer| {
            if (delayer.is_on) {
                return atlas.get_offset(7);
            } else {
                return atlas.get_offset(6);
            }
        },
    }
}

pub fn queue_entity(
    state: *const State,
    grid_pos: Vec2i,
    entity: *const Entity,
) !void {
    const pixel_pos = grid_pos.mul(GRID_SIZE).subi(state.viewpos);
    const texture_pos = get_entity_texture(entity);
    const angle = entity.get_direction().to_rad();

    const queued = BufferData{
        .pos = pVec2f{
            .x = @intToFloat(f32, pixel_pos.x),
            .y = @intToFloat(f32, pixel_pos.y),
        },
        .tex_coord = pVec2f{
            .x = texture_pos.x,
            .y = texture_pos.y,
        },
        .rotation = angle,
    };

    try queued_entities.append(queued);
}

pub fn render(state: *const State) !void {
    const min_pos = state.viewpos.div(GRID_SIZE);
    const view_width = @divFloor(SCREEN_WIDTH, GRID_SIZE) + 1;
    const view_height = @divFloor(SCREEN_HEIGHT, GRID_SIZE) + 1;

    var grid_y: i32 = min_pos.y;
    while (grid_y < min_pos.y + view_height) : (grid_y += 1) {
        var grid_x: i32 = min_pos.x;
        while (grid_x < min_pos.x + view_width) : (grid_x += 1) {
            const grid_pos = Vec2i.new(grid_x, grid_y);
            const entry = state.entities.get(grid_pos) orelse continue;
            try queue_entity(state, grid_pos, &entry.value);
        }
    }

    const entity_data = queued_entities.toSlice();
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(BufferData) * @intCast(c_long, entity_data.len),
        @ptrCast(?*const c_void, entity_data.ptr),
        c.GL_STREAM_DRAW,
    );

    c.glBindVertexArray(vao);
    c.glDrawArrays(c.GL_POINTS, 0, @intCast(c_int, entity_data.len));
    try queued_entities.resize(0);
}
