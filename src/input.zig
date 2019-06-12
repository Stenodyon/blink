const std = @import("std");

const sdl = @import("sdl.zig");
const display = @import("display.zig");
const State = @import("state.zig").State;
const Vec2i = @import("vec.zig").Vec2i;

var lmb_down = false;
var rmb_down = false;
var placing = false;

pub fn on_mouse_motion(state: *State, x: i32, y: i32, x_rel: i32, y_rel: i32) void {
    if (lmb_down and placing and (x_rel * x_rel + y_rel * y_rel >= 2))
        placing = false;

    if (lmb_down and !placing)
        state.viewpos = state.viewpos.sub(Vec2i.new(x_rel, y_rel));
}

pub fn on_mouse_button_up(state: *State, button: u8, x: i32, y: i32) !void {
    const mouse_pos = Vec2i.new(x, y).addi(state.viewpos);
    const grid_pos = display.screen2grid(mouse_pos);

    switch (button) {
        sdl.BUTTON_LEFT => {
            lmb_down = false;
            if (placing) {
                if (state.place_entity(grid_pos) catch false) {
                    std.debug.warn("Placing!\n");
                } else {
                    std.debug.warn("Blocked!\n");
                }
            }
        },
        sdl.BUTTON_RIGHT => {
            rmb_down = false;
            if (try state.remove_entity(grid_pos)) |_|
                std.debug.warn("Removed!\n");
        },
        else => {},
    }
}

pub fn on_mouse_button_down(button: u8, x: i32, y: i32) void {
    switch (button) {
        sdl.BUTTON_LEFT => {
            lmb_down = true;
            placing = true;
        },
        sdl.BUTTON_RIGHT => {
            rmb_down = true;
        },
        else => {},
    }
}
