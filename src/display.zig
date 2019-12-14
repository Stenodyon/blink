const std = @import("std");
const panic = std.debug.panic;
const math = std.math;
const Allocator = std.mem.Allocator;
const Buffer = std.Buffer;

const sdl = @import("sdl.zig");
const ttf = @import("ttf.zig");
const c = @import("c.zig");

const TextureAtlas = @import("render/atlas.zig").TextureAtlas;
const ShaderProgram = @import("render/shader.zig").ShaderProgram;
const entity_renderer = @import("render/entity.zig");
const lightray_renderer = @import("render/lightray.zig");
const grid_renderer = @import("render/grid.zig");
const polygon_renderer = @import("render/polygon.zig");
const ui_renderer = @import("render/ui.zig");
const State = @import("state.zig").State;
const utils = @import("utils.zig");
const Entity = @import("entities.zig").Entity;
const dir_angle = @import("entities.zig").dir_angle;
const LightRay = @import("lightray.zig").LightRay;
const matrix = @import("matrix.zig");

usingnamespace @import("vec.zig");

pub var renderer: sdl.Renderer = undefined;

pub const GRID_SIZE = 64;

pub const GRID_CENTER = Vec2i.new(GRID_SIZE / 2, GRID_SIZE / 2);

pub var window_width: i32 = 1280;
pub var window_height: i32 = 720;

const font_name = "data/VT323-Regular.ttf";
var font: ttf.Font = undefined;

// World -> OpenGL
pub var world_matrix: [16]f32 = undefined;
pub var inv_world_matrix: [16]f32 = undefined;
// Screen -> OpenGL
pub var screen_matrix: [16]f32 = undefined;
pub var inv_screen_matrix: [16]f32 = undefined;

fn ortho_matrix(viewpos: Vec2f, viewport: Vec2f, dest: *[16]f32) void {
    matrix.identity(dest);
    matrix.translate(
        dest,
        -viewpos.x,
        -viewpos.y,
        0,
    );
    matrix.scale(
        dest,
        2 / viewport.x,
        -2 / viewport.y,
        1,
    );
}

fn update_screen_matrix(window_size: Vec2f) void {
    matrix.identity(&screen_matrix);
    matrix.scale(
        &screen_matrix,
        2 / window_size.x,
        -2 / window_size.y,
        1,
    );
    matrix.translate(
        &screen_matrix,
        -1,
        1,
        0,
    );
    if (!matrix.inverse(&inv_screen_matrix, &screen_matrix)) {
        std.debug.warn("Non-invertible screen matrix!\n", .{});
        matrix.print_matrix(&screen_matrix);
    }
}

pub fn update_projection_matrix(viewpos: Vec2f, viewport: Vec2f) void {
    ortho_matrix(
        viewpos,
        viewport,
        &world_matrix,
    );
    if (!matrix.inverse(&inv_world_matrix, &world_matrix)) {
        std.debug.warn("Non-invertible projection matrix!\n", .{});
        matrix.print_matrix(&world_matrix);
    }
}

export fn openGLCallback(
    source: c.GLenum,
    msg_type: c.GLenum,
    id: c.GLuint,
    severity: c.GLenum,
    length: c.GLsizei,
    message: [*c]const u8,
    user_param: ?*const c_void,
) callconv(.C) void {
    if (severity != c.GL_DEBUG_SEVERITY_NOTIFICATION) {
        panic("OpenGL: {s}\n", .{message});
    }
}

pub fn init(allocator: *Allocator) !void {
    c.glEnable(c.GL_DEBUG_OUTPUT);
    c.glDebugMessageCallback(openGLCallback, null);

    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    polygon_renderer.init();
    grid_renderer.init();
    try entity_renderer.init(allocator);
    lightray_renderer.init(allocator);
    try ui_renderer.init(allocator);

    update_projection_matrix(Vec2f.new(0, 0), Vec2f.new(1, 1));
    update_screen_matrix(Vec2i.new(window_width, window_height).to_float(f32));

    std.debug.warn("OpenGL initialized\n", .{});

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

    update_projection_matrix(
        state.viewpos.to_float(f32),
        state.viewport.to_float(f32),
    );

    ////g_gui.draw(g_gui, renderer);

    grid_renderer.render(state);
    try lightray_renderer.render(state);
    try render_entities(state);
    try render_ui(state);
}

fn render_ghost(state: *const State) !void {
    var pos: Vec2i = undefined;
    _ = sdl.GetMouseState(&pos.x, &pos.y);
    const grid_pos = screen2world(pos.to_float(f32)).floor();
    try entity_renderer.queue_entity(state, grid_pos, &state.get_current_entity());
    try entity_renderer.draw(0.5);
}

fn render_entities(state: *const State) !void {
    try entity_renderer.collect(state);
    try entity_renderer.draw(0.0);
}

fn render_ui(state: *const State) !void {
    if (state.selection_rect) |sel_rect| {
        {
            const pos = sel_rect.pos;
            const size = sel_rect.size;
            const polygon = [_]f32{
                pos.x,          pos.y,
                pos.x + size.x, pos.y,
                pos.x + size.x, pos.y + size.y,
                pos.x,          pos.y + size.y,
            };
            polygon_renderer.draw_polygon(polygon[0..]);
        }

        const can_sel_rect = sel_rect.canonic();
        const min_pos = can_sel_rect.pos.floor();
        const max_pos = can_sel_rect.pos.add(can_sel_rect.size).ceil();
        var y: i32 = min_pos.y;
        while (y < max_pos.y) : (y += 1) {
            var x: i32 = min_pos.x;
            while (x < max_pos.x) : (x += 1) {
                const pos = Vec2i.new(x, y);
                if (!state.entities.contains(pos))
                    continue;
                try ui_renderer.queue_element(state, Rectf{
                    .pos = pos.to_float(f32),
                    .size = Vec2f.new(1, 1),
                }, ui_renderer.id.selection);
            }
        }
    }

    // Selected entities
    var entity_iterator = state.selected_entities.iterator();
    while (entity_iterator.next()) |entry| {
        const pos = entry.key.to_float(f32);
        try ui_renderer.queue_element(state, Rectf{
            .pos = pos,
            .size = Vec2f.new(1, 1),
        }, ui_renderer.id.selection);
    }
    try ui_renderer.draw_queued(0.0);

    // Copy buffer
    var copy_buffer_iter = state.copy_buffer.iterator();
    while (copy_buffer_iter.next()) |entry| {
        var mouse_pos: Vec2i = undefined;
        _ = sdl.GetMouseState(&mouse_pos.x, &mouse_pos.y);
        const pos = entry.key.add(screen2world(
            mouse_pos.to_float(f32),
        ).floor());
        try entity_renderer.queue_entity_float(state, pos, &entry.value);
    }
    try entity_renderer.draw(0.5);

    if (state.copy_buffer.count() == 0)
        try render_ghost(state);
}

pub fn on_window_event(state: *State, event: *const sdl.WindowEvent) void {
    switch (event.event) {
        sdl.WINDOWEVENT_SIZE_CHANGED => {
            const new_size = Vec2i.new(event.data1, event.data2).to_float(f32);
            window_width = event.data1;
            window_height = event.data2;

            c.glViewport(0, 0, window_width, window_height);

            update_screen_matrix(
                Vec2i.new(window_width, window_height).to_float(f32),
            );

            state.viewport = new_size.divf(GRID_SIZE);
            update_projection_matrix(state.viewpos, state.viewport);
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
        std.debug.warn("Failed to render text\n", .{});
        return;
    }
    defer sdl.FreeSurface(surface);

    const texture = sdl.CreateTextureFromSurface(renderer, surface);
    if (texture == null) {
        std.debug.warn("Failed to create texture from surface\n", .{});
        return;
    }
    defer sdl.DestroyTexture(texture);

    const dest_rect = Rect.new(
        Vec2i.new(0, 0),
        Vec2i.new(surface.*.w, surface.*.h),
    );
    _ = sdl.RenderCopy(renderer, texture, null, dest_rect);
}

pub fn screen2world(point: Vec2f) Vec2f {
    var vec = [4]f32{
        point.x,
        point.y,
        0,
        1,
    };
    matrix.apply(&screen_matrix, &vec);
    matrix.apply(&inv_world_matrix, &vec);
    return Vec2f.new(vec[0], vec[1]);
}

pub fn screen2world_distance(point: Vec2f) Vec2f {
    var vec = [4]f32{
        point.x,
        point.y,
        0,
        0,
    };
    matrix.apply(&screen_matrix, &vec);
    matrix.apply(&inv_world_matrix, &vec);
    return Vec2f.new(vec[0], vec[1]);
}

pub fn world2screen(point: Vec2f) Vec2f {
    var vec = [4]f32{
        point.x,
        point.y,
        0,
        1,
    };
    matrix.apply(&world_matrix, &vec);
    matrix.apply(&inv_screen_matrix, &vec);
    return Vec2f.new(vec[0], vec[1]);
}
