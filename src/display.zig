const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const Buffer = std.Buffer;

const sdl = @import("sdl.zig");
const ttf = @import("ttf.zig");
const c = @import("c.zig");
const lazy = @import("lazy");

const TextureAtlas = @import("render/atlas.zig").TextureAtlas;
const ShaderProgram = @import("render/shader.zig").ShaderProgram;
const entity_renderer = @import("render/entity.zig");
const lightray_renderer = @import("render/lightray.zig");
const grid_renderer = @import("render/grid.zig");
const polygon_renderer = @import("render/polygon.zig");
const ui_renderer = @import("render/ui.zig");
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

fn otho_matrix(viewpos: Vec2i, size: Vec2i, dest: *[16]f32) void {
    for (dest[0..]) |*index| index.* = 0;
    dest[0] = 2 / @intToFloat(f32, size.x);
    dest[3] = @intToFloat(f32, -viewpos.x) * dest[0] - 1;
    dest[5] = -2. / @intToFloat(f32, size.y);
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

pub fn update_projection_matrix(viewpos: Vec2i, viewport: Vec2i) void {
    otho_matrix(
        viewpos,
        viewport,
        &projection_matrix,
    );
}

pub fn init(allocator: *Allocator) void {
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    polygon_renderer.init();
    grid_renderer.init();
    entity_renderer.init(allocator);
    lightray_renderer.init(allocator);
    ui_renderer.init(allocator);

    update_projection_matrix(Vec2i.new(0, 0), Vec2i.new(1, 1));

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
    ui_renderer.deinit();
    lightray_renderer.deinit();
    entity_renderer.deinit();
    grid_renderer.deinit();
    polygon_renderer.deinit();

    //ttf.CloseFont(font);
}

pub fn render(state: *const State) !void {
    c.glClearColor(0, 0, 0, 1);
    c.glClear(c.GL_COLOR_BUFFER_BIT);

    update_projection_matrix(state.viewpos, state.viewport);

    ////g_gui.draw(g_gui, renderer);

    grid_renderer.render(state);
    try lightray_renderer.render(state);
    try render_entities(state);
    try render_ui(state);
}

fn render_ghost(state: *const State) !void {
    var pos: Vec2i = undefined;
    _ = sdl.GetMouseState(&pos.x, &pos.y);
    const grid_pos = screen2grid(state, pos);
    try entity_renderer.queue_entity(state, grid_pos, &state.get_current_entity());
    try entity_renderer.draw(0.5);

    //const world_pos = grid_pos.mul(GRID_SIZE).to_float(f32);
    //const grid_square = [_]f32{
    //    world_pos.x,             world_pos.y,
    //    world_pos.x + GRID_SIZE, world_pos.y,
    //    world_pos.x + GRID_SIZE, world_pos.y + GRID_SIZE,
    //    world_pos.x,             world_pos.y + GRID_SIZE,
    //};
    //polygon_renderer.draw_polygon(grid_square[0..]);
}

fn render_entities(state: *const State) !void {
    try entity_renderer.collect(state);
    try entity_renderer.draw(0.0);
}

fn render_ui(state: *const State) !void {
    if (state.selection_rect) |sel_rect| {
        {
            const pos = sel_rect.pos.to_float(f32);
            const size = sel_rect.size.to_float(f32);
            const polygon = [_]f32{
                pos.x,          pos.y,
                pos.x + size.x, pos.y,
                pos.x + size.x, pos.y + size.y,
                pos.x,          pos.y + size.y,
            };
            polygon_renderer.draw_polygon(polygon[0..]);
        }

        const can_sel_rect = sel_rect.canonic();
        const min_pos = can_sel_rect.pos.div(GRID_SIZE);
        const max_pos = can_sel_rect.pos.add(
            can_sel_rect.size,
        ).divi(GRID_SIZE).addi(Vec2i.new(1, 1));
        var y: i32 = min_pos.y;
        while (y < max_pos.y) : (y += 1) {
            var x: i32 = min_pos.x;
            while (x < max_pos.x) : (x += 1) {
                const pos = Vec2i.new(x, y);
                if (!state.entities.contains(pos))
                    continue;
                try ui_renderer.queue_element(state, Rect{
                    .pos = pos.mul(GRID_SIZE),
                    .size = Vec2i.new(GRID_SIZE, GRID_SIZE),
                }, 1);
            }
        }
    }

    // Selected entities
    var entity_iterator = state.selected_entities.iterator();
    while (entity_iterator.next()) |entry| {
        const pos = entry.key.mul(GRID_SIZE);
        try ui_renderer.queue_element(state, Rect{
            .pos = pos,
            .size = Vec2i.new(64, 64),
        }, 1);
    }
    try ui_renderer.draw(0.0);

    // Copy buffer
    var copy_buffer_iter = state.copy_buffer.iterator();
    while (copy_buffer_iter.next()) |entry| {
        var mouse_pos: Vec2i = undefined;
        _ = sdl.GetMouseState(&mouse_pos.x, &mouse_pos.y);
        const pos = entry.key.add(screen2grid(state, mouse_pos)).muli(GRID_SIZE);
        try entity_renderer.queue_entity_float(state, pos, &entry.value);
    }
    try entity_renderer.draw(0.5);

    if (state.copy_buffer.count() == 0)
        try render_ghost(state);
}

pub fn on_window_event(state: *State, event: *const sdl.WindowEvent) void {
    switch (event.event) {
        //sdl.WINDOWEVENT_MAXIMIZED,
        //sdl.WINDOWEVENT_RESIZED,
        sdl.WINDOWEVENT_SIZE_CHANGED => {
            const new_size = Vec2i.new(event.data1, event.data2);
            const current_size = Vec2i.new(window_width, window_height);
            const difference = new_size.sub(current_size);
            window_width = new_size.x;
            window_height = new_size.y;

            c.glViewport(0, 0, window_width, window_height);

            _ = state.viewpos.subi(difference.div(2));
            _ = state.viewport.addi(difference);
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

pub inline fn screen2world(state: *const State, point: Vec2i) Vec2i {
    return point.mulf(state.get_zoom_factor()).addi(state.viewpos);
}

pub inline fn screen2grid(state: *const State, point: Vec2i) Vec2i {
    return screen2world(state, point).divi(GRID_SIZE);
}

pub inline fn grid2screen(state: *const State, point: Vec2i) Vec2i {
    return point.mul(GRID_SIZE).subi(state.viewpos).divfi(state.get_zoom_factor());
}
