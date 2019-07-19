const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const Buffer = std.Buffer;

const sdl = @import("sdl.zig");
const ttf = @import("ttf.zig");
const c = @import("c.zig");
const lazy = @import("lazy/index.zig");

const TextureAtlas = @import("atlas.zig").TextureAtlas;
const State = @import("state.zig").State;
const vec = @import("vec.zig");
const Vec2i = vec.Vec2i;
const Vec2f = vec.Vec2f;
const Rect = vec.Rect;
const utils = @import("utils.zig");
const Entity = @import("entities.zig").Entity;
const dir_angle = @import("entities.zig").dir_angle;

pub var renderer: sdl.Renderer = undefined;

pub const SCREEN_WIDTH = 1280;
pub const SCREEN_HEIGHT = 720;

pub const GRID_SIZE = 64;

pub const GRID_CENTER = Vec2i.new(GRID_SIZE / 2, GRID_SIZE / 2);

pub const GUI_Element = struct {
    draw: fn (self: *GUI_Element, renderer: sdl.Renderer) void,
    resize: fn (self: *GUI_Element) void,
    screen_area: Rect,

    hovered: bool,

    pub fn compute_hovered(self: *GUI_Element, mouse_x: i32, mouse_y: i32) void {
        self.hovered = self.screen_area.contains(Vec2i{ .x = mouse_x, .y = mouse_y });
    }
};

pub const GUI_Button = struct {
    base: GUI_Element,

    pub fn new() GUI_Button {
        return GUI_Button{
            .base = GUI_Element{
                .draw = GUI_Button.draw,
                .resize = GUI_Button.resize,
                .screen_area = Rect{
                    .pos = Vec2i.new(10, 20),
                    .size = Vec2i.new(100, 50),
                },
                .hovered = false,
            },
        };
    }

    fn draw(base: *GUI_Element, renderer: sdl.Renderer) void {
        var self = @fieldParentPtr(GUI_Button, "base", base);

        _ = sdl.SetRenderDrawColor(renderer, 0x7F, 0x7F, 0x7F, 0xFF);
        _ = sdl.RenderFillRect(renderer, base.screen_area);
    }

    fn resize(base: *GUI_Element) void {
        var self = @fieldParentPtr(GUI_Button, "base", base);
    }
};

pub var g_gui: *GUI_Element = undefined;

pub const tmp = Rect.new(Vec2i.new(10, 20), Vec2i.new(100, 50));

var block_img: sdl.Texture = undefined;
var laser_img: sdl.Texture = undefined;
var mirror_img: sdl.Texture = undefined;
var splitter_img: sdl.Texture = undefined;
var delayer_on_img: sdl.Texture = undefined;
var delayer_off_img: sdl.Texture = undefined;
var switch_img: sdl.Texture = undefined;

const font_name = c"data/VT323-Regular.ttf";
var font: ttf.Font = undefined;

fn load_texture(path: []const u8) !sdl.Texture {
    const surface = try ResourceManager.Get(path);
    const texture = sdl.CreateTextureFromSurface(renderer, surface);
    if (texture == null) {
        std.debug.warn("Could not create texture: {}\n", sdl.GetError());
        std.os.exit(1);
    }
    return texture;
}

const vertex_shader_src =
    c\\#version 330 core
    c\\
    c\\layout (location = 0) in vec2 position;
    c\\layout (location = 1) in vec2 texture_uv;
    c\\
    c\\out UV_PASSTHROUGH {
    c\\    vec2 uv;
    c\\} uv_passthrough;
    c\\
    c\\void main() {
    c\\    gl_Position = vec4(position.x, -position.y, 0.0, 1.0);
    c\\    uv_passthrough.uv = texture_uv;
    c\\}
;

const geometry_shader_src =
    c\\#version 330 core
    c\\
    c\\layout (points) in;
    c\\layout (triangle_strip, max_vertices = 6) out;
    c\\
    c\\in UV_PASSTHROUGH {
    c\\    vec2 uv;
    c\\} uv_passthrough[];
    c\\
    c\\uniform mat4 projection;
    c\\
    c\\out vec2 _texture_uv;
    c\\
    c\\void add_point(vec2 displacement) {
    c\\    vec4 point = gl_in[0].gl_Position + 64.0 * vec4(displacement, 0.0, 0.0);
    c\\    point = projection * point;
    c\\    gl_Position = point + vec4(-1.0, 1.0, 0.0, 0.0);
    c\\    _texture_uv = uv_passthrough[0].uv + vec2(displacement.x, -displacement.y) / 8.0;
    c\\    EmitVertex();
    c\\}
    c\\
    c\\void main() {
    c\\    add_point(vec2(0.0, 0.0));
    c\\    add_point(vec2(0.0, -1.0));
    c\\    add_point(vec2(1.0, -1.0));
    c\\    EndPrimitive();
    c\\
    c\\    add_point(vec2(0.0, 0.0));
    c\\    add_point(vec2(1.0, -1.0));
    c\\    add_point(vec2(1.0, 0.0));
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
    c\\  outColor = texture(atlas, _texture_uv);
    c\\}
;

const sprite_vertices = [_]c.GLfloat{
    0,   0,
    128, 128,
    128, 0,
};

var sprite_vao: c.GLuint = undefined;
var sprite_vbo: c.GLuint = undefined;
var vertex_shader: c.GLuint = undefined;
var geometry_shader: c.GLuint = undefined;
var fragment_shader: c.GLuint = undefined;
var shader_program: c.GLuint = undefined;
var entity_atlas: TextureAtlas = undefined;

var projection_matrix: [16]f32 = undefined;

fn otho_matrix(width: f32, height: f32, dest: *[16]f32) void {
    for (dest[0..]) |*index| index.* = 0;
    dest[0] = 2 / width;
    dest[5] = 2 / height;
    dest[15] = 1;
}

const LOG_BUFFER_SIZE = 512;

fn check_shader(shader: c.GLuint) void {
    var status: c.GLuint = undefined;
    c.glGetShaderiv(
        shader,
        c.GL_COMPILE_STATUS,
        @ptrCast([*c]c_int, &status),
    );

    if (status != c.GL_TRUE) {
        var log_buffer: [LOG_BUFFER_SIZE]u8 = undefined;
        c.glGetShaderInfoLog(shader, LOG_BUFFER_SIZE, null, &log_buffer);
        _ = c.printf(
            c"%s\n",
            &log_buffer,
        );
        std.process.exit(255);
    }
}

fn check_program(program: c.GLuint) void {
    var status: c.GLuint = undefined;
    c.glGetProgramiv(
        program,
        c.GL_LINK_STATUS,
        @ptrCast([*c]c_int, &status),
    );

    if (status != c.GL_TRUE) {
        var log_buffer: [LOG_BUFFER_SIZE]u8 = undefined;
        c.glGetProgramInfoLog(program, LOG_BUFFER_SIZE, null, &log_buffer);
        _ = c.printf(
            c"%s\n",
            &log_buffer,
        );
        std.process.exit(255);
    }
}

pub fn init() void {
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    c.glGenVertexArrays(1, &sprite_vao);
    c.glBindVertexArray(sprite_vao);

    c.glGenBuffers(1, &sprite_vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, sprite_vbo);

    vertex_shader = c.glCreateShader(c.GL_VERTEX_SHADER);
    c.glShaderSource(vertex_shader, 1, &vertex_shader_src, null);
    c.glCompileShader(vertex_shader);
    check_shader(vertex_shader);

    fragment_shader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(fragment_shader, 1, &fragment_shader_src, null);
    c.glCompileShader(fragment_shader);
    check_shader(fragment_shader);

    geometry_shader = c.glCreateShader(c.GL_GEOMETRY_SHADER);
    c.glShaderSource(geometry_shader, 1, &geometry_shader_src, null);
    c.glCompileShader(geometry_shader);
    check_shader(geometry_shader);

    shader_program = c.glCreateProgram();
    c.glAttachShader(shader_program, vertex_shader);
    c.glAttachShader(shader_program, geometry_shader);
    c.glAttachShader(shader_program, fragment_shader);

    c.glBindFragDataLocation(shader_program, 0, c"outColor");

    c.glLinkProgram(shader_program);
    check_program(shader_program);

    c.glUseProgram(shader_program);

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

    otho_matrix(
        @intToFloat(f32, SCREEN_WIDTH),
        @intToFloat(f32, SCREEN_HEIGHT),
        &projection_matrix,
    );

    var projection_location = c.glGetUniformLocation(
        shader_program,
        c"projection",
    );
    c.glUniformMatrix4fv(
        projection_location,
        1,
        c.GL_FALSE,
        &projection_matrix,
    );

    entity_atlas = TextureAtlas.load(c"data/entity_atlas.png", 16, 16);

    std.debug.warn("OpenGL initialized\n");

    //font = ttf.OpenFont(font_name, 25);
    //if (font == null) {
    //    std.debug.warn(
    //        "Failed to load font \"{}\"\n",
    //        utils.c_to_slice(font_name),
    //    );
    //    std.os.exit(1);
    //}
    //std.debug.warn("Textures loaded\n");
}

pub fn deinit() void {
    entity_atlas.deinit();
    c.glDeleteProgram(shader_program);
    c.glDeleteShader(fragment_shader);
    c.glDeleteShader(vertex_shader);
    c.glDeleteBuffers(1, &sprite_vbo);
    c.glDeleteVertexArrays(1, &sprite_vao);

    //ttf.CloseFont(font);
}

pub fn render(state: *const State) void {
    c.glClearColor(0.43, 0.47, 0.53, 1);
    c.glClear(c.GL_COLOR_BUFFER_BIT);

    ////g_gui.draw(g_gui, renderer);

    //_ = sdl.SetRenderDrawColor(renderer, 0x39, 0x3B, 0x45, 0xFF);
    //render_grid(state);
    //render_lightrays(state);
    render_entities(state);
    //render_grid_sel(state);

    //sdl.RenderPresent(renderer);
}

fn render_grid_sel(state: *const State) void {
    var pos: Vec2i = undefined;
    _ = sdl.GetMouseState(&pos.x, &pos.y);
    const world_pos = pos.add(state.viewpos);
    const grid_pos = world_pos.div(GRID_SIZE).muli(GRID_SIZE).subi(state.viewpos);

    _ = sdl.SetRenderDrawColor(renderer, 0x58, 0x48, 0x48, 0x3F);
    render_entity(state.get_current_entity(), grid_pos);

    const current_cell_area = Rect{
        .pos = grid_pos,
        .size = Vec2i.new(GRID_SIZE + 1, GRID_SIZE + 1),
    };
    _ = sdl.SetRenderDrawColor(renderer, 0xD8, 0xD9, 0xDE, 0xFF);
    _ = sdl.RenderDrawRect(renderer, current_cell_area);
}

fn render_grid(state: *const State) void {
    const top_left = state.viewpos.div(GRID_SIZE);
    const cell_count = Vec2i{
        .x = @divFloor(SCREEN_WIDTH, GRID_SIZE) + 1,
        .y = @divFloor(SCREEN_HEIGHT, GRID_SIZE) + 1,
    };

    var x_it = lazy.range(i32(0), cell_count.x, 1);
    while (x_it.next()) |x| {
        const x_pos = (top_left.x + x) * GRID_SIZE - state.viewpos.x;
        _ = sdl.RenderDrawLine(renderer, x_pos, 0, x_pos, SCREEN_HEIGHT);
    }

    var y_it = lazy.range(i32(0), cell_count.y, 1);
    while (y_it.next()) |y| {
        const y_pos = (top_left.y + y) * GRID_SIZE - state.viewpos.y;
        _ = sdl.RenderDrawLine(renderer, 0, y_pos, SCREEN_WIDTH, y_pos);
    }
}

fn render_lightrays(state: *const State) void {
    _ = sdl.SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);
    const viewarea = Rect.new(
        screen2grid(state.viewpos),
        Vec2i.new(
            SCREEN_WIDTH / GRID_SIZE + 1,
            SCREEN_HEIGHT / GRID_SIZE + 1,
        ),
    );
    var tree_iterator = state.lighttrees.iterator();
    while (tree_iterator.next()) |entry| {
        const tree = &entry.value;
        const entity_entry = state.entities.get(entry.key) orelse unreachable;
        if (!entity_entry.value.is_emitting())
            continue;

        var count: usize = 0;
        for (tree.rays.toSlice()) |lightray| {
            if (!(lightray.intersects(viewarea)))
                continue;
            count += 1;

            var start = grid2screen(lightray.origin).subi(state.viewpos);
            _ = start.addi(GRID_CENTER);
            var end = end: {
                if (lightray.get_endpoint()) |endpoint| {
                    break :end grid2screen(endpoint).subi(state.viewpos).addi(GRID_CENTER);
                } else {
                    switch (lightray.direction) {
                        .UP => break :end Vec2i.new(start.x, 0),
                        .DOWN => break :end Vec2i.new(start.x, SCREEN_HEIGHT),
                        .LEFT => break :end Vec2i.new(0, start.y),
                        .RIGHT => break :end Vec2i.new(SCREEN_WIDTH, start.y),
                        else => unreachable,
                    }
                }
            };

            utils.clamp(i32, &start.x, 0, SCREEN_WIDTH);
            utils.clamp(i32, &start.y, 0, SCREEN_HEIGHT);
            utils.clamp(i32, &end.x, 0, SCREEN_WIDTH);
            utils.clamp(i32, &end.y, 0, SCREEN_HEIGHT);

            _ = sdl.RenderDrawLine(
                renderer,
                start.x,
                start.y,
                end.x,
                end.y,
            );
        }
        //        debug_write("{} rays rendered", count) catch {
        //            std.debug.warn("Failed to render debug text\n");
        //        };
    }
}

fn get_entity_texture(entity: *Entity) Vec2f {
    switch (entity.*) {
        .Block => return entity_atlas.get_offset(1, .UP),
        .Laser => |direction| return entity_atlas.get_offset(2, direction),
        .Mirror => |direction| return entity_atlas.get_offset(3, direction),
        .Splitter => |direction| return entity_atlas.get_offset(4, direction),
        .Switch => |*eswitch| return entity_atlas.get_offset(5, eswitch.direction),
        .Delayer => |*delayer| {
            if (delayer.is_on) {
                return entity_atlas.get_offset(7, delayer.direction);
            } else {
                return entity_atlas.get_offset(6, delayer.direction);
            }
        },
    }
}

fn render_entities(state: *const State) void {
    const min_pos = state.viewpos.div(GRID_SIZE);
    const view_width = @divFloor(SCREEN_WIDTH, GRID_SIZE) + 1;
    const view_height = @divFloor(SCREEN_HEIGHT, GRID_SIZE) + 1;

    var pos_buffer_counter: usize = 0;
    var pos_buffer: [view_width * view_height * 4]f32 = undefined;

    var grid_y: i32 = min_pos.y;
    while (grid_y < min_pos.y + view_height) : (grid_y += 1) {
        var grid_x: i32 = min_pos.x;
        while (grid_x < min_pos.x + view_width) : (grid_x += 1) {
            const grid_pos = Vec2i.new(grid_x, grid_y);
            const entry = state.entities.get(grid_pos) orelse continue;
            const pixel_pos = grid_pos.mul(GRID_SIZE).subi(state.viewpos);
            pos_buffer[pos_buffer_counter] = @intToFloat(f32, pixel_pos.x);
            pos_buffer[pos_buffer_counter + 1] = @intToFloat(f32, pixel_pos.y);
            const texture_pos = get_entity_texture(&entry.value);
            pos_buffer[pos_buffer_counter + 2] = texture_pos.x;
            pos_buffer[pos_buffer_counter + 3] = texture_pos.y;
            pos_buffer_counter += 4;
        }
    }

    if (pos_buffer_counter == 0)
        return;

    c.glBindBuffer(c.GL_ARRAY_BUFFER, sprite_vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(f32) * @intCast(c_long, pos_buffer_counter),
        &pos_buffer,
        c.GL_STREAM_DRAW,
    );

    c.glDrawArrays(c.GL_POINTS, 0, @intCast(c_int, pos_buffer_counter / 4));
}

// pos in screen coordinates
fn render_entity(entity: Entity, pos: Vec2i) void {
    const zero = Vec2i.new(0, 0);
    const grid_size = Vec2i.new(GRID_SIZE, GRID_SIZE);
    const srect = Rect.new(zero, grid_size);
    const drect = Rect.new(pos, grid_size);
    switch (entity) {
        .Block => {
            _ = sdl.RenderCopy(renderer, block_img, srect, drect);
        },
        .Laser => |direction| {
            _ = sdl.RenderCopyEx(
                renderer,
                laser_img,
                srect,
                drect,
                dir_angle(direction),
                &(grid_size.div(2)),
                sdl.FLIP_NONE,
            );
        },
        .Mirror => |direction| {
            _ = sdl.RenderCopyEx(
                renderer,
                mirror_img,
                srect,
                drect,
                dir_angle(direction),
                &(grid_size.div(2)),
                sdl.FLIP_NONE,
            );
        },
        .Splitter => |direction| {
            _ = sdl.RenderCopyEx(
                renderer,
                splitter_img,
                srect,
                drect,
                dir_angle(direction),
                &(grid_size.div(2)),
                sdl.FLIP_NONE,
            );
        },
        .Delayer => |*delayer| {
            _ = sdl.RenderCopyEx(
                renderer,
                switch (delayer.is_on) {
                    true => delayer_on_img,
                    false => delayer_off_img,
                },
                srect,
                drect,
                dir_angle(delayer.direction),
                &(grid_size.div(2)),
                sdl.FLIP_NONE,
            );
        },
        .Switch => |*eswitch| {
            _ = sdl.RenderCopyEx(
                renderer,
                switch_img,
                srect,
                drect,
                dir_angle(eswitch.direction),
                &(grid_size.div(2)),
                sdl.FLIP_NONE,
            );
        },
    }
}

pub fn debug_write(
    comptime fmt: []const u8,
    args: ...,
) !void {
    var buffer = try Buffer.allocPrint(std.debug.global_allocator, fmt, args);
    defer buffer.deinit();
    try buffer.appendByte(0);

    const text = buffer.toSlice();
    const color = sdl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    const surface = ttf.RenderText_Solid(
        font,
        @ptrCast([*c]const u8, &text[0]),
        color,
    );
    if (surface == null) {
        std.debug.warn("Failed to render text\n");
        return;
    }
    defer sdl.FreeSurface(surface);

    const texture = sdl.CreateTextureFromSurface(renderer, surface);
    if (texture == null) {
        std.debug.warn("Failed to create texture from surface\n");
        return;
    }
    defer sdl.DestroyTexture(texture);

    const dest_rect = Rect.new(
        Vec2i.new(0, 0),
        Vec2i.new(surface.*.w, surface.*.h),
    );
    _ = sdl.RenderCopy(renderer, texture, null, dest_rect);
}

pub fn screen2grid(point: Vec2i) Vec2i {
    return point.div(GRID_SIZE);
}

pub fn grid2screen(point: Vec2i) Vec2i {
    return point.mul(GRID_SIZE);
}
