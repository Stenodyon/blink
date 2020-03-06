const std = @import("std");

const c = @import("../c.zig");
const ShaderProgram = @import("shader.zig").ShaderProgram;
const State = @import("../state.zig").State;
const vec = @import("../vec.zig");
const Vec2i = vec.Vec2i;
const Vec2f = vec.Vec2f;
usingnamespace @import("pipeline.zig");

const display = @import("../display.zig");
const GRID_SIZE = display.GRID_SIZE;

const GridConfig = PipelineConfig{
    .vertexShader = @embedFile("grid_vertex.glsl"),
    .fragmentShader = @embedFile("grid_fragment.glsl"),

    .attributes = &[_]AttributeSpecif{
        AttributeSpecif.from("position", .Float, 2),
    },
    .uniforms = &[_]UniformSpecif{
        UniformSpecif.from("projection", .Matrix4),
    },
};

const GridPipeline = Pipeline(GridConfig);

var pipeline: GridPipeline = undefined;

pub fn init() void {
    pipeline = GridPipeline.init();
    c.glBindBuffer(c.GL_ARRAY_BUFFER, pipeline.vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(f32) * @intCast(c_long, 12),
        null,
        c.GL_STREAM_DRAW,
    );

    //c.glBindFragDataLocation(shader.handle, 0, "outColor");
}

pub fn deinit() void {
    pipeline.deinit();
}

pub fn render(state: *const State) void {
    pipeline.setActive();
    update_vertices(state);

    pipeline.setUniform("projection", &display.world_matrix);

    c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_LINE);
    c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
    c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_FILL);
}

fn update_vertices(state: *const State) void {
    c.glBindBuffer(c.GL_ARRAY_BUFFER, pipeline.vbo);
    const x = state.viewpos.x;
    const y = state.viewpos.y;
    const width = state.viewport.x / 2;
    const height = state.viewport.y / 2;
    const vertices = [_]f32{
        x - width, y - height,
        x + width, y - height,
        x - width, y + height,
        x - width, y + height,
        x + width, y - height,
        x + width, y + height,
    };

    const rawPtr = @alignCast(@alignOf(f32), c.glMapBuffer(
        c.GL_ARRAY_BUFFER,
        c.GL_WRITE_ONLY,
    ));
    defer _ = c.glUnmapBuffer(c.GL_ARRAY_BUFFER);

    const dataPtr = @ptrCast([*]f32, rawPtr);
    for (vertices) |vertex, i| dataPtr[i] = vertex;
}
