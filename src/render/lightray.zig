const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const c = @import("../c.zig");
const entities = @import("../entities.zig");
const Direction = entities.Direction;
const LightRay = @import("../lightray.zig").LightRay;
const State = @import("../state.zig").State;
const pVec2f = @import("utils.zig").pVec2f;
const display = @import("../display.zig");
usingnamespace @import("pipeline.zig");
usingnamespace @import("../vec.zig");

const LightrayConfig = PipelineConfig{
    .vertexShader = @embedFile("lightray_vertex.glsl"),
    .geometryShader = @embedFile("lightray_geometry.glsl"),
    .fragmentShader = @embedFile("lightray_fragment.glsl"),

    .attributes = &[_]AttributeSpecif{
        .{
            .name = "position",
            .kind = .Float,
            .count = 2,
        },
        .{
            .name = "length",
            .kind = .Float,
            .count = 1,
        },
        .{
            .name = "rotation",
            .kind = .Float,
            .count = 1,
        },
    },
    .uniforms = &[_]UniformSpecif{
        .{
            .name = "projection",
            .kind = .Matrix4,
        },
    },
};

const LightrayPipeline = Pipeline(LightrayConfig);

var pipeline: LightrayPipeline = undefined;

const BufferData = packed struct {
    pos: pVec2f,
    length: f32,
    rotation: f32,
};
var queued_rays: ArrayList(BufferData) = undefined;

pub fn init(allocator: *Allocator) void {
    queued_rays = ArrayList(BufferData).init(allocator);
    pipeline = LightrayPipeline.init();
}

pub fn deinit() void {
    pipeline.deinit();
    queued_rays.deinit();
}

pub fn queue_ray(
    state: *const State,
    ray: *const LightRay,
) !void {
    const world_pos = ray.origin.to_float(f32).addi(Vec2f.new(0.5, 0.5));
    const viewport_pos = world_pos.sub(state.viewpos);
    const length = blk: {
        if (ray.length) |grid_length|
            break :blk @intToFloat(f32, grid_length);
        switch (ray.direction) {
            .UP => break :blk state.viewport.y / 2 + viewport_pos.y,
            .DOWN => break :blk state.viewport.y / 2 - viewport_pos.y,
            .LEFT => break :blk state.viewport.x / 2 + viewport_pos.x,
            .RIGHT => break :blk state.viewport.x / 2 - viewport_pos.x,
        }
    };
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
        state.viewpos.sub(state.viewport.div(2)).floor(),
        state.viewport.ceil(),
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
    pipeline.setActive();

    const ray_data = queued_rays.toSlice();
    c.glBindBuffer(c.GL_ARRAY_BUFFER, pipeline.vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(BufferData) * @intCast(c_long, ray_data.len),
        @ptrCast(?*const c_void, ray_data.ptr),
        c.GL_STREAM_DRAW,
    );

    pipeline.setUniform("projection", &display.world_matrix);
    c.glDrawArrays(c.GL_POINTS, 0, @intCast(c_int, ray_data.len));
    try queued_rays.resize(0);
}
