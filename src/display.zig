const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const Buffer = std.Buffer;

const sdl = @import("sdl.zig");
const ttf = @import("ttf.zig");
const c = @import("c.zig");
const lazy = @import("lazy/index.zig");

const TextureAtlas = @import("render/atlas.zig").TextureAtlas;
const ShaderProgram = @import("render/shader.zig").ShaderProgram;
const entity_renderer = @import("render/entity_renderer.zig");
const lightray_renderer = @import("render/lightray_renderer.zig");
const grid_renderer = @import("render/grid.zig");
const State = @import("state.zig").State;
const vec = @import("vec.zig");
const Vec2i = vec.Vec2i;
const Vec2f = vec.Vec2f;
const Rect = vec.Rect;
const utils = @import("utils.zig");
const Entity = @import("entities.zig").Entity;
const dir_angle = @import("entities.zig").dir_angle;
const LightRay = @import("lightray.zig").LightRay;

pub var renderer: sdl.Renderer = undefined;

pub const GRID_SIZE = 64;

pub const GRID_CENTER = Vec2i.new(GRID_SIZE / 2, GRID_SIZE / 2);

pub var window_width: i32 = 1280;
pub var window_height: i32 = 720;

const font_name = c"data/VT323-Regular.ttf";
var font: ttf.Font = undefined;

var projection_matrix: [16]f32 = undefined;

fn otho_matrix(viewpos: Vec2i, width: f32, height: f32, dest: *[16]f32) void {
    for (dest[0..]) |*index| index.* = 0;
    dest[0] = 2 / width;
    dest[3] = @intToFloat(f32, -viewpos.x) * dest[0] - 1;
    dest[5] = -2 / height;
    dest[7] = @intToFloat(f32, -viewpos.y) * dest[5] + 1;
    dest[15] = 1;
}

pub fn set_proj_matrix_uniform(program: *const ShaderProgram) void {
    const projection_location = program.uniform_location(c"projection");
    c.glUniformMatrix4fv(
        projection_location,
        1,
        c.GL_TRUE,
        &projection_matrix,
    );
}

pub fn update_projection_matrix(viewpos: Vec2i) void {
    otho_matrix(
        viewpos,
        @intToFloat(f32, window_width),
        @intToFloat(f32, window_height),
        &projection_matrix,
    );
}

pub fn init(allocator: *Allocator) void {
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    grid_renderer.init();
    entity_renderer.init(allocator);
    lightray_renderer.init(allocator);

    update_projection_matrix(Vec2i.new(0, 0));

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
    lightray_renderer.deinit();
    entity_renderer.deinit();
    grid_renderer.deinit();

    //ttf.CloseFont(font);
}

pub fn render(state: *const State) !void {
    c.glClearColor(0, 0, 0, 1);
    c.glClear(c.GL_COLOR_BUFFER_BIT);

    update_projection_matrix(state.viewpos);

    ////g_gui.draw(g_gui, renderer);

    grid_renderer.render(state);
    try lightray_renderer.render(state);
    try render_grid_sel(state);
    try entity_renderer.render(state);
}

fn render_grid_sel(state: *const State) !void {
    var pos: Vec2i = undefined;
    _ = sdl.GetMouseState(&pos.x, &pos.y);
    const world_pos = pos.add(state.viewpos);
    const grid_pos = world_pos.div(GRID_SIZE);
    try entity_renderer.queue_entity(state, grid_pos, &state.get_current_entity());

    //const current_cell_area = Rect{
    //    .pos = grid_pos,
    //    .size = Vec2i.new(GRID_SIZE + 1, GRID_SIZE + 1),
    //};
    //_ = sdl.SetRenderDrawColor(renderer, 0xD8, 0xD9, 0xDE, 0xFF);
    //_ = sdl.RenderDrawRect(renderer, current_cell_area);
}

pub fn on_window_event(state: *State, event: *const sdl.WindowEvent) void {
    switch (event.event) {
        //sdl.WINDOWEVENT_MAXIMIZED,
        //sdl.WINDOWEVENT_RESIZED,
        sdl.WINDOWEVENT_SIZE_CHANGED => {
            const new_width = event.data1;
            const new_height = event.data2;
            const recenter_x = @divFloor(new_width - window_width, 2);
            const recenter_y = @divFloor(new_height - window_height, 2);
            window_width = new_width;
            window_height = new_height;

            c.glViewport(0, 0, window_width, window_height);

            _ = state.viewpos.subi(Vec2i.new(recenter_x, recenter_y));
        },
        else => {},
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
