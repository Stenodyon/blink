const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const TextureAtlas = @import("atlas.zig").TextureAtlas;
const c = @import("../c.zig");
const entities = @import("../entities.zig");
const Entity = entities.Entity;
const Direction = entities.Direction;
const State = @import("../state.zig").State;
const pVec2f = @import("utils.zig").pVec2f;
const display = @import("../display.zig");
usingnamespace @import("../vec.zig");
usingnamespace @import("pipeline.zig");

const GRID_SIZE = display.GRID_SIZE;

const EntityConfig = PipelineConfig{
    .vertexShader = @embedFile("entity_vertex.glsl"),
    .geometryShader = @embedFile("entity_geometry.glsl"),
    .fragmentShader = @embedFile("entity_fragment.glsl"),

    .attributes = &[_]AttributeSpecif{
        .{
            .name = "position",
            .kind = .Float,
            .count = 2,
        },
        .{
            .name = "texture_uv",
            .kind = .Float,
            .count = 2,
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
        .{
            .name = "transparency",
            .kind = .Float,
        },
    },
};

const EntityPipeline = Pipeline(EntityConfig);

var pipeline: EntityPipeline = undefined;
var atlas: TextureAtlas = undefined;

var id: struct {
    error_texture: usize,
    block: usize,
    laser: usize,
    mirror: usize,
    double_mirror: usize,
    splitter: usize,
    switch_entity: usize,
    delayer_off: usize,
    delayer_on: usize,
    lamp_off: usize,
    lamp_on: usize,
} = undefined;

const BufferData = packed struct {
    pos: pVec2f,
    tex_coord: pVec2f,
    rotation: f32,
};

var queued_entities: ArrayList(BufferData) = undefined;

pub fn init(allocator: *Allocator) !void {
    queued_entities = ArrayList(BufferData).init(allocator);
    pipeline = EntityPipeline.init();

    atlas = try TextureAtlas.load(allocator, "data/entity_atlas", 16, 16);
    id.error_texture = atlas.id_of("error").?;
    id.block = atlas.id_of("block").?;
    id.laser = atlas.id_of("laser").?;
    id.mirror = atlas.id_of("mirror").?;
    id.double_mirror = atlas.id_of("double_mirror").?;
    id.splitter = atlas.id_of("splitter").?;
    id.switch_entity = atlas.id_of("switch").?;
    id.delayer_off = atlas.id_of("delayer_off").?;
    id.delayer_on = atlas.id_of("delayer_on").?;
    id.lamp_off = atlas.id_of("lamp_off").?;
    id.lamp_on = atlas.id_of("lamp_on").?;
}

pub fn deinit() void {
    atlas.deinit();
    queued_entities.deinit();
    pipeline.deinit();
}

/// Returns the UV coordinates for the given entity
fn get_entity_texture(entity: *const Entity) Rectf {
    const texture_id = switch (entity.*) {
        .Block => id.block,
        .Laser => id.laser,
        .Mirror => id.mirror,
        .DoubleMirror => id.double_mirror,
        .Splitter => id.splitter,
        .Switch => id.switch_entity,
        .Delayer => |*delayer| if (delayer.is_on) id.delayer_on else id.delayer_off,
        .Lamp => |is_on| if (is_on) id.lamp_on else id.lamp_off,
    };

    switch (entity.*) {
        .Block,
        .Laser,
        .Mirror,
        .DoubleMirror,
        .Splitter,
        .Delayer,
        .Lamp,
        => return atlas.rect_of(texture_id),
        .Switch => |*eswitch| return atlas.rect_of_flipped(
            texture_id,
            eswitch.is_flipped,
            false,
        ),
    }
}

pub fn queue_entity(
    state: *const State,
    grid_pos: Vec2i,
    entity: *const Entity,
) !void {
    const texture = get_entity_texture(entity);
    const angle = entity.get_direction().to_rad();
    const pos = grid_pos.to_float(f32);

    const queued = BufferData{
        .pos = pVec2f{
            .x = pos.x,
            .y = pos.y,
        },
        .tex_coord = pVec2f{
            .x = texture.pos.x,
            .y = texture.pos.y,
        },
        .rotation = angle,
    };

    try queued_entities.append(queued);
}

/// Collect all visible entities for drawing
pub fn collect(state: *const State) !void {
    const viewport_size = state.viewport.div(2).add(Vec2f.new(1, 1));
    const min_pos = state.viewpos.sub(viewport_size).floor();
    const max_pos = state.viewpos.add(viewport_size).ceil();

    var grid_y: i32 = min_pos.y;
    while (grid_y < max_pos.y) : (grid_y += 1) {
        var grid_x: i32 = min_pos.x;
        while (grid_x < max_pos.x) : (grid_x += 1) {
            const grid_pos = Vec2i.new(grid_x, grid_y);
            const entry = state.entities.get(grid_pos) orelse continue;
            try queue_entity(state, grid_pos, &entry.value);
        }
    }
}

pub fn draw(transparency: f32) !void {
    pipeline.setActive();

    const entity_data = queued_entities.toSlice();
    c.glBindBuffer(c.GL_ARRAY_BUFFER, pipeline.vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(BufferData) * @intCast(c_long, entity_data.len),
        @ptrCast(?*const c_void, entity_data.ptr),
        c.GL_STREAM_DRAW,
    );

    atlas.bind();
    pipeline.setUniform("projection", &display.world_matrix);
    pipeline.setUniform("transparency", transparency);
    c.glDrawArrays(c.GL_POINTS, 0, @intCast(c_int, entity_data.len));
    try queued_entities.resize(0);
}
