const std = @import("std");

const sdl = @import("sdl.zig");
const display = @import("display.zig");
const State = @import("state.zig").State;
const Vec2i = @import("vec.zig").Vec2i;

var lmb_down = false;
var rmb_down = false;

pub fn on_mouse_motion(state: *State, x: i32, y: i32, x_rel: i32, y_rel: i32) void {
    if (lmb_down and ((sdl.GetModState() & sdl.KMOD_LSHIFT) != 0)) {
        state.viewpos = state.viewpos.sub(Vec2i.new(x_rel, y_rel));
    }
}

pub fn on_mouse_button_up(button: u8) void {
    switch (button) {
        sdl.BUTTON_LEFT => {
            lmb_down = false;
        },
        sdl.BUTTON_RIGHT => {
            rmb_down = false;
        },
        else => {},
    }
}

pub fn on_mouse_button_down(button: u8, x: i32, y: i32) void {
    switch (button) {
        sdl.BUTTON_LEFT => {
            lmb_down = true;
        },
        sdl.BUTTON_RIGHT => {
            rmb_down = true;
        },
        else => {},
    }
}

pub fn tick_held_mouse_buttons(state: *State, mouse_pos: Vec2i) !void {
    const adjusted_mouse_pos = Vec2i.new(mouse_pos.x, mouse_pos.y).addi(state.viewpos);
    const grid_pos = display.screen2grid(adjusted_mouse_pos);

    if (lmb_down and !rmb_down and ((sdl.GetModState() & sdl.KMOD_LSHIFT) == 0)) {
        if (try state.place_entity(grid_pos)) {
            std.debug.warn("Placed!\n");
        } else {
            std.debug.warn("Blocked!\n");
        }
    }

    if (rmb_down and !lmb_down and ((sdl.GetModState() & sdl.KMOD_LSHIFT) == 0)) {
        if (try state.remove_entity(grid_pos)) |_|
            std.debug.warn("Removed!\n");
    }
}
