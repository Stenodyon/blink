const std = @import("std");
const ArrayList = std.ArrayList;

const sdl = @import("sdl.zig");
const display = @import("display.zig");
const utils = @import("utils.zig");

usingnamespace @import("vec.zig");
usingnamespace @import("save_load.zig");
usingnamespace @import("state.zig");

var last_cell: ?Vec2i = null;
var left_click_pos: Vec2i = undefined;
var drag_initial_viewpos: Vec2f = undefined;

pub const InputState = enum {
    Normal,
    Removing,
    PlaceOrPanOrMove,
    Panning,
    PlaceHold,
    Selecting,
    Moving,
};

pub fn on_mouse_motion(state: *State, x: i32, y: i32, x_rel: i32, y_rel: i32) !void {
    const mouse = Vec2i.new(x, y);

    if (last_cell) |cell| {
        if (cell.x != x or cell.y != y) {
            try on_mouse_enter_cell(state, x, y);
            last_cell = Vec2i.new(x, y);
        }
    } else {
        try on_mouse_enter_cell(state, x, y);
        last_cell = Vec2i.new(x, y);
    }

    switch (state.input_state) {
        .Normal, .Removing, .PlaceHold, .Moving => {},
        .PlaceOrPanOrMove => {
            const pixel_movement = mouse.sub(left_click_pos);
            if (pixel_movement.length_sq() > 2) {
                const grid_pos = display.screen2world(mouse.to_float(f32)).floor();
                if (state.selected_entities.contains(grid_pos)) {
                    state.copy_buffer.clear();
                    try state.copy_selection(grid_pos);
                    try state.delete_selection();

                    state.input_state = .Moving;
                } else {
                    state.input_state = .Panning;
                }
            }
        },
        .Panning => {
            const pixel_movement = mouse.sub(left_click_pos);
            const movement = display.screen2world_distance(
                pixel_movement.to_float(f32),
            );
            state.viewpos = drag_initial_viewpos.sub(movement);
        },
        .Selecting => {
            const movement = display.screen2world(mouse.to_float(f32)).subi(
                state.selection_rect.?.pos,
            );
            state.selection_rect.?.size = movement;
        },
    }
}

fn on_mouse_enter_cell(state: *State, x: i32, y: i32) !void {
    const world_mouse = display.screen2world(Vec2i.new(x, y).to_float(f32));
    const grid_pos = world_mouse.floor();

    switch (state.input_state) {
        .Removing => _ = try state.remove_entity(grid_pos),
        .PlaceHold => _ = try state.place_entity(grid_pos),
        else => {},
    }
}

pub fn on_mouse_button_up(state: *State, button: u8, mouse_pos: Vec2f) !void {
    switch (state.input_state) {
        .Normal => {},
        .Removing => {
            if (button == sdl.BUTTON_RIGHT) {
                state.input_state = .Normal;
            }
        },
        .PlaceOrPanOrMove => {
            const grid_pos = display.screen2world(mouse_pos).floor();
            if (state.copy_buffer.count() > 0) {
                var placed = false;
                if (state.selected_entities.count() > 0) {
                    placed = try state.place_copy(grid_pos);
                } else {
                    placed = try state.place_selected_copy(grid_pos);
                }

                if (placed and (sdl.GetModState() & sdl.KMOD_LSHIFT) == 0) {
                    state.copy_buffer.clear();
                }
            } else {
                _ = try state.place_entity(grid_pos);
            }

            state.input_state = .Normal;
        },
        .Panning => {
            if (button == sdl.BUTTON_LEFT) {
                state.input_state = .Normal;
            }
        },
        .PlaceHold => {
            if (button == sdl.BUTTON_LEFT) {
                const grid_pos = display.screen2world(mouse_pos).floor();
                _ = try state.place_entity(grid_pos);
                state.input_state = .Normal;
            }
        },
        .Selecting => {
            switch (button) {
                sdl.BUTTON_LEFT => {
                    try state.capture_selection_rect();
                    state.input_state = .Normal;
                },
                else => {},
            }
        },
        .Moving => {
            const grid_pos = display.screen2world(mouse_pos).floor();
            if (try state.place_selected_copy(grid_pos)) {
                state.copy_buffer.clear();
            }

            state.input_state = .Normal;
        },
    }
}

pub fn on_mouse_button_down(state: *State, button: u8, x: i32, y: i32) !void {
    const mouse = Vec2i.new(x, y);

    switch (state.input_state) {
        .Normal => {
            switch (button) {
                sdl.BUTTON_LEFT => {
                    if ((sdl.GetModState() & sdl.KMOD_LCTRL) != 0) {
                        const world_pos = display.screen2world(mouse.to_float(f32));
                        state.selection_rect = Rectf{
                            .pos = world_pos,
                            .size = Vec2f.new(0, 0),
                        };

                        state.input_state = .Selecting;
                    } else if ((sdl.GetModState() & sdl.KMOD_LSHIFT) != 0) {
                        if (state.copy_buffer.count() == 0) {
                            state.input_state = .PlaceHold;
                        } else {
                            state.input_state = .PlaceOrPanOrMove;
                        }
                    } else {
                        left_click_pos = mouse;
                        drag_initial_viewpos = state.viewpos;

                        state.input_state = .PlaceOrPanOrMove;
                    }
                },
                sdl.BUTTON_RIGHT => {
                    const grid_pos = display.screen2world(mouse.to_float(f32)).floor();
                    _ = try state.remove_entity(grid_pos);

                    state.input_state = .Removing;
                },
                else => {},
            }
        },
        .Removing => if (button == sdl.BUTTON_RIGHT) unreachable,
        .PlaceOrPanOrMove => if (button == sdl.BUTTON_LEFT) unreachable,
        .Panning => if (button == sdl.BUTTON_LEFT) unreachable,
        .PlaceHold => if (button == sdl.BUTTON_LEFT) unreachable,
        .Selecting => if (button == sdl.BUTTON_LEFT) unreachable,
        .Moving => if (button == sdl.BUTTON_LEFT) unreachable,
    }
}

pub fn tick_held_mouse_buttons(state: *State, mouse_pos: Vec2f) void {}

pub fn on_key_down(state: *State, keysym: sdl.Keysym) !void {
    const modifiers = sdl.GetModState();
    switch (keysym.sym) {
        sdl.K_0,
        sdl.K_1,
        sdl.K_2,
        sdl.K_3,
        sdl.K_4,
        sdl.K_5,
        sdl.K_6,
        sdl.K_7,
        sdl.K_8,
        sdl.K_9,
        => {
            const index = @intCast(usize, utils.slot_value(keysym.sym));
            if (index < state.entity_wheel.len) {
                state.set_selected_slot(index);
            }
        },
        sdl.K_q => {
            if (state.copy_buffer.count() > 0) {
                try state.rotate_copy_cclockwise();
            } else {
                state.set_ghost_direction(state.get_ghost_direction().cclockwise());
            }
        },
        sdl.K_e => {
            if (state.copy_buffer.count() > 0) {
                try state.rotate_copy_clockwise();
            } else {
                state.set_ghost_direction(state.get_ghost_direction().clockwise());
            }
        },
        sdl.K_DELETE, sdl.K_BACKSPACE => {
            try state.delete_selection();
        },
        sdl.K_ESCAPE => {
            if (state.copy_buffer.count() > 0) {
                state.copy_buffer.clear();
            } else {
                state.selected_entities.clear();
            }
        },
        sdl.K_F6 => {
            try save_state(&game_state, "test.sav");
            std.debug.warn("saved to test.sav\n");
        },
        sdl.K_r => {
            if (state.copy_buffer.count() > 0) {
                try state.flip_copy();
            } else {
                state.get_entity_ptr().flip();
            }
        },
        sdl.K_f => { // pick under cursor
            var mouse: Vec2i = undefined;
            _ = sdl.GetMouseState(&mouse.x, &mouse.y);
            const grid_pos = display.screen2world(mouse.to_float(f32)).floor();
            if (state.get_entity(grid_pos)) |entity| {
                state.set_selected_entity(entity.*);
            }
        },
        sdl.K_d => {
            state.copy_buffer.clear();
            if ((modifiers & sdl.KMOD_LCTRL) != 0) { // CTRL + D
                try put_selection_in_buffer(state);
            }
        },
        sdl.K_x => {
            state.copy_buffer.clear();
            if ((modifiers & sdl.KMOD_LCTRL) != 0) { // CTRL + X
                try put_selection_in_buffer(state);
                try state.delete_selection();
            }
        },
        else => {},
    }
}

pub fn on_key_up(state: *State, keysym: sdl.Keysym) void {
    const modifiers = sdl.GetModState();
    switch (keysym.sym) {
        sdl.K_LSHIFT => {
            if (state.input_state == .PlaceHold) {
                state.input_state = .Normal;
            }
        },
        else => {},
    }
}

fn put_selection_in_buffer(state: *State) !void {
    // Find the center of selected entities
    var min = Vec2i.new(std.math.maxInt(i32), std.math.maxInt(i32));
    var max = Vec2i.new(std.math.minInt(i32), std.math.minInt(i32));
    var entity_iterator = state.selected_entities.iterator();
    while (entity_iterator.next()) |entry| {
        min.x = std.math.min(min.x, entry.key.x);
        min.y = std.math.min(min.y, entry.key.y);
        max.x = std.math.max(max.x, entry.key.x);
        max.y = std.math.max(max.y, entry.key.y);
    }
    const center = min.add(max).divi(2);

    try state.copy_selection(center);
}
