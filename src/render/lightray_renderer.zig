const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const ShaderProgram = @import("shader.zig").ShaderProgram;
const c = @import("../c.zig");
const entities = @import("../entities.zig");
const Direction = entities.Direction;
const LightRay = @import("../lightray.zig").LightRay;
const State = @import("../state.zig").State;
const vec = @import("../vec.zig");
const Vec2i = vec.Vec2i;
const Vec2f = vec.Vec2f;
const Rect = vec.Rect;
const pVec2f = @import("utils.zig").pVec2f;

const display = @import("../display.zig");
const GRID_SIZE = display.GRID_SIZE;

const vertex_shader_src =
    c\\#version 330 core
    c\\
    c\\layout (location = 0) in vec2 position;
    c\\layout (location = 1) in float length;
    c\\layout (location = 2) in float rotation;
    c\\
    c\\out PASSTHROUGH {
    c\\    float length;
    c\\    float rotation;
    c\\} passthrough;
    c\\
    c\\void main() {
    c\\    gl_Position = vec4(position.xy, 0.0, 1.0);
    c\\    passthrough.length = length;
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
    c\\    float length;
    c\\    float rotation;
    c\\} passthrough[];
    c\\
    c\\uniform mat4 projection;
    c\\
    c\\out vec2 texture_uv;
    c\\
    c\\vec2 vertices[6] = vec2[](
    c\\    vec2(-1.0, 0.0),
    c\\    vec2(-1.0, -1.0),
    c\\    vec2(1.0, -1.0),
    c\\    vec2(-1.0, 0.0),
    c\\    vec2(1.0, -1.0),
    c\\    vec2(1.0, 0.0)
    c\\);
    c\\
    c\\const vec2 rotation_center = vec2(0.0, 0.0);
    c\\
    c\\vec2 rotate(vec2 displacement) {
    c\\    float angle = passthrough[0].rotation;
    c\\    vec2 centered = displacement - rotation_center;
    c\\    centered = vec2(
    c\\        centered.x * cos(angle) - centered.y * sin(angle),
    c\\        centered.x * sin(angle) + centered.y * cos(angle));
    c\\    return centered + rotation_center;
    c\\}
    c\\
    c\\void add_point(vec2 displacement) {
    c\\    vec2 rotated = rotate(displacement);
    c\\    vec4 point = gl_in[0].gl_Position + vec4(rotated, 0.0, 0.0);
    c\\    gl_Position = projection * point;
    c\\    texture_uv = displacement;
    c\\    EmitVertex();
    c\\}
    c\\
    c\\void main() {
    c\\    vec2 scale = vec2(2.0, passthrough[0].length);
    c\\    for (int i = 0; i < 3; ++i) {
    c\\        add_point(vertices[i] * scale);
    c\\    }
    c\\    EndPrimitive();
    c\\
    c\\    for (int i = 3; i < 6; ++i) {
    c\\        add_point(vertices[i] * scale);
    c\\    }
    c\\    EndPrimitive();
    c\\}
;

const fragment_shader_src =
    c\\#version 330 core
    c\\
    c\\in vec2 texture_uv;
    c\\
    c\\//uniform sampler2D atlas;
    c\\
    c\\out vec4 outColor;
    c\\
    c\\void main() {
    c\\    //outColor = texture(atlas, texture_uv);
    c\\    outColor = vec4(1.0, 1.0, 1.0, 1.0);
    c\\}
;

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
        &vertex_shader_src,
        &geometry_shader_src,
        &fragment_shader_src,
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
    const pixel_pos = ray.origin.mul(GRID_SIZE).addi(Vec2i.new(
        GRID_SIZE / 2,
        GRID_SIZE / 2,
    ));
    const angle = ray.direction.to_rad();
    const length = blk: {
        if (ray.length) |grid_length|
            break :blk @intCast(i32, grid_length) * GRID_SIZE;
        switch (ray.direction) {
            .UP => break :blk pixel_pos.y + state.viewpos.y,
            .DOWN => break :blk display.window_height - pixel_pos.y + state.viewpos.y,
            .LEFT => break :blk pixel_pos.x + state.viewpos.x,
            .RIGHT => break :blk display.window_width - pixel_pos.x + state.viewpos.x,
        }
    };

    const queued = BufferData{
        .pos = pVec2f{
            .x = @intToFloat(f32, pixel_pos.x),
            .y = @intToFloat(f32, pixel_pos.y),
        },
        .length = @intToFloat(f32, length),
        .rotation = angle,
    };

    try queued_rays.append(queued);
}

pub fn render(state: *const State) !void {
    // Collect
    const viewarea = Rect.new(
        state.viewpos.div(GRID_SIZE),
        state.viewport.div(GRID_SIZE).addi(Vec2i.new(1, 1)),
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
