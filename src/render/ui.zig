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

const vertex_shader_src =
    c\\#version 330 core
    c\\
    c\\layout (location = 0) in vec2 position;
    c\\layout (location = 1) in vec2 texture_uv;
    c\\
    c\\uniform mat4 projection;
    c\\
    c\\out vec2 uv;
    c\\
    c\\void main() {
    c\\    gl_Position = projection * vec4(position.xy, 0.0, 1.0);
    c\\    uv = texture_uv;
    c\\}
;

const fragment_shader_src =
    c\\#version 330 core
    c\\
    c\\in vec2 uv;
    c\\
    c\\uniform float transparency;
    c\\uniform sampler2D atlas;
    c\\
    c\\void main() {
    c\\    vec4 color = texture(atlas, uv);
    c\\    color.a *= 1.0 - transparency;
    c\\    gl_FragColor = color;
    c\\    //gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
    c\\}
;

var vao: c.GLuint = undefined;
var vbo: c.GLuint = undefined;

var atlas: TextureAtlas = undefined;
pub var shader: ShaderProgram = undefined;

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

    shader = ShaderProgram.new(
        &vertex_shader_src,
        null,
        &fragment_shader_src,
    );
    shader.link();
    shader.set_active();

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

    atlas = TextureAtlas.load(allocator, c"data/ui_atlas.png", 16, 16);
}

pub fn deinit() void {
    atlas.deinit();
    shader.deinit();
    queued_elements.deinit();

    c.glDeleteBuffers(1, &vbo);
    c.glDeleteVertexArrays(1, &vao);
}

pub fn queue_element(
    state: *const State,
    location: Rect,
    texture_id: usize,
) !void {
    const pos = location.pos.to_float(f32);
    const size = location.size.to_float(f32);
    const texture_pos = atlas.get_offset(texture_id);
    const vertices = [_]pVec2f{
        pVec2f{ .x = pos.x, .y = pos.y },
        pVec2f{ .x = pos.x + size.x, .y = pos.y },
        pVec2f{ .x = pos.x, .y = pos.y + size.y },
        pVec2f{ .x = pos.x, .y = pos.y + size.y },
        pVec2f{ .x = pos.x + size.x, .y = pos.y },
        pVec2f{ .x = pos.x + size.x, .y = pos.y + size.y },
    };
    const cell_width = @intToFloat(f32, atlas.cell_width) / @intToFloat(f32, atlas.width);
    const cell_height = @intToFloat(f32, atlas.cell_height) / @intToFloat(f32, atlas.height);
    const uvs = [_]pVec2f{
        pVec2f{ .x = texture_pos.x, .y = texture_pos.y },
        pVec2f{ .x = texture_pos.x + cell_width, .y = texture_pos.y },
        pVec2f{ .x = texture_pos.x, .y = texture_pos.y + cell_height },
        pVec2f{ .x = texture_pos.x, .y = texture_pos.y + cell_height },
        pVec2f{ .x = texture_pos.x + cell_width, .y = texture_pos.y },
        pVec2f{ .x = texture_pos.x + cell_width, .y = texture_pos.y + cell_height },
    };

    var i: usize = 0;
    while (i < 6) : (i += 1) {
        const queued = BufferData{
            .pos = vertices[i],
            .tex_coord = uvs[i],
        };
        try queued_elements.append(queued);
    }
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
    shader.set_active();
    atlas.bind();
    display.set_proj_matrix_uniform(&shader);
    const trans_uniform_loc = shader.uniform_location(c"transparency");
    c.glUniform1f(trans_uniform_loc, transparency);
    c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c_int, element_data.len));
    try queued_elements.resize(0);
}
