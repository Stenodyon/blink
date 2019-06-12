const std = @import("std");
const math = std.math;
const sdl = @import("sdl.zig");
const lazy = @import("lazy/index.zig");

const ResourceManager = @import("res.zig");
const State = @import("state.zig").State;
const vec = @import("vec.zig");
const Vec2i = vec.Vec2i;
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

fn load_texture(path: []const u8) !sdl.Texture {
    const surface = try ResourceManager.Get(path);
    const texture = sdl.CreateTextureFromSurface(renderer, surface);
    if (texture == null) {
        std.debug.warn("Could not create texture: {}\n", sdl.GetError());
        std.os.exit(1);
    }
    return texture;
}

pub fn init() !void {
    block_img = try load_texture("data/entity_block.png");
    laser_img = try load_texture("data/entity_laser.png");
    std.debug.warn("Textures loaded\n");
}

pub fn render(state: *const State) void {
    _ = sdl.SetRenderDrawColor(renderer, 0x6E, 0x78, 0x89, 0xFF);
    _ = sdl.RenderClear(renderer);

    //g_gui.draw(g_gui, renderer);

    _ = sdl.SetRenderDrawColor(renderer, 0x39, 0x3B, 0x45, 0xFF);
    render_grid(state);
    render_lightrays(state);
    render_entities(state);
    render_grid_sel(state);

    sdl.RenderPresent(renderer);
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
    for (state.lightrays.toSlice()) |lightray| {
        if (!(lightray.intersects(viewarea)))
            continue;

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
}

fn render_entities(state: *const State) void {
    var entity_it = state.entities.iterator();
    while (entity_it.next()) |entry| {
        const pos = entry.key.mul(GRID_SIZE).subi(state.viewpos);
        render_entity(entry.value, pos);
    }
}

// pos in screen coordinates
fn render_entity(entity: Entity, pos: Vec2i) void {
    const zero = Vec2i.new(0, 0);
    const grid_size = Vec2i.new(GRID_SIZE, GRID_SIZE);
    const srect = Rect.new(zero, grid_size);
    const drect = Rect.new(pos, grid_size);
    switch (entity) {
        Entity.Block => {
            _ = sdl.RenderCopy(renderer, block_img, srect, drect);
        },
        Entity.Laser => |direction| {
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
    }
}

pub fn screen2grid(point: Vec2i) Vec2i {
    return point.div(GRID_SIZE);
}

pub fn grid2screen(point: Vec2i) Vec2i {
    return point.mul(GRID_SIZE);
}
