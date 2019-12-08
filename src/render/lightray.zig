const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const ShaderProgram = @import("shader.zig").ShaderProgram;
const c = @import("../c.zig");
const entities = @import("../entities.zig");
const Direction = entities.Direction;
const LightRay = @import("../lightray.zig").LightRay;
const State = @import("../state.zig").State;
const pVec2f = @import("utils.zig").pVec2f;

usingnamespace @import("../vec.zig");

const display = @import("../display.zig");
const GRID_SIZE = display.GRID_SIZE;

const vertex_shader_src = @embedFile("lightray_vertex.glsl");
const vertex_shader_src_list = [_][]const u8{&vertex_shader_src};

const geometry_shader_src = @embedFile("lightray_geometry.glsl");
const geometry_shader_src_list = [_][]const u8{&geometry_shader_src};

const fragment_shader_src = @embedFile("lightray_fragment.glsl");
const fragment_shader_src_list = [_][]const u8{&fragment_shader_src};

const BufferData = packed struct {
    pos: pVec2f,
    length: f32,
    rotation: f32,
};

var vao: c.GLuint = undefined;
var vbo: c.GLuint = undefined;
var shader: ShaderProgram = undefined;
var queued_rays: ArrayList(BufferData) = undefined;

pub fn init(allocator: *Allocator) void {
    queued_rays = ArrayList(BufferData).init(allocator);

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

    // 2B pos | 1B length | 1B rotation
    const pos_attrib = 0;
    const length_attrib = 1;
    const rotation_attrib = 2;
    c.glEnableVertexAttribArray(pos_attrib);
    c.glEnableVertexAttribArray(length_attrib);
    c.glEnableVertexAttribArray(rotation_attrib);
    c.glVertexAttribPointer(
        pos_attrib,
        2,
        c.GL_FLOAT,
        c.GL_FALSE,
        4 * @sizeOf(f32),
        @intToPtr(?*const c_void, 0),
    );
    c.glVertexAttribPointer(
        length_attrib,
        1,
        c.GL_FLOAT,
        c.GL_FALSE,
        4 * @sizeOf(f32),
        @intToPtr(*const c_void, 2 * @sizeOf(f32)),
    );
    c.glVertexAttribPointer(
        rotation_attrib,
        1,
        c.GL_FLOAT,
        c.GL_FALSE,
        4 * @sizeOf(f32),
        @intToPtr(*const c_void, 3 * @sizeOf(f32)),
    );
}

pub fn deinit() void {
    shader.deinit();
    c.glDeleteBuffers(1, &vbo);
    c.glDeleteVertexArrays(1, &vao);
    queued_rays.deinit();
}

pub fn queue_ray(
    state: *const State,
    ray: *const LightRay,
) !void {
    const world_pos = ray.origin.to_float(f32).add(Vec2f.new(0.5, 0.5));
    const viewport_pos = world_pos.sub(state.viewpos.to_float(f32));
    const length = blk: {
        if (ray.length) |grid_length|
            break :blk @intToFloat(f32, grid_length);
        switch (ray.direction) {
            .UP => break :blk viewport_pos.y,
            .DOWN => break :blk state.viewport.y - viewport_pos.y,
            .LEFT => break :blk viewport_pos.x,
            .RIGHT => break :blk state.viewport.x - viewport_pos.x,
        }
    };
    //const length = @intToFloat(f32, base_length) * state.get_zoom_factor();
    const angle = ray.direction.to_rad();

    const queued = BufferData{
        .pos = pVec2f{
            .x = world_pos.x,
            .y = world_pos.y,
        },
        .length = length,
        .rotation = angle,
    };

    try queued_rays.append(queued);
}

pub fn render(state: *const State) !void {
    // Collect
    const viewarea = Recti.new(
        state.viewpos.to_int(i32).div(GRID_SIZE),
        state.viewport.to_int(i32).div(GRID_SIZE).addi(Vec2i.new(1, 1)),
    );

    var tree_iterator = state.lighttrees.iterator();
    while (tree_iterator.next()) |entry| {
        const tree = &entry.value;
        const entity_entry = state.entities.get(entry.key) orelse unreachable;
        if (!entity_entry.value.is_emitting())
            continue;

        for (tree.rays.toSlice()) |*lightray| {
            if (!(lightray.intersects(viewarea)))
                continue;

            try queue_ray(state, lightray);
        }
    }

    // Draw
    const ray_data = queued_rays.toSlice();
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(BufferData) * @intCast(c_long, ray_data.len),
        @ptrCast(?*const c_void, ray_data.ptr),
        c.GL_STREAM_DRAW,
    );

    c.glBindVertexArray(vao);
    shader.set_active();
    display.set_proj_matrix_uniform(&shader);
    c.glDrawArrays(c.GL_POINTS, 0, @intCast(c_int, ray_data.len));
    try queued_rays.resize(0);
}
