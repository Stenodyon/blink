const std = @import("std");

const sdl = @import("sdl.zig");
const display = @import("display.zig");
const State = @import("state.zig").State;
usingnamespace @import("vec.zig");
const utils = @import("utils.zig");

var lmb_down = false;
var rmb_down = false;
var last_grid_action: ?Vec2i = null;
var drag_initial_mouse: ?Vec2i = null;
var drag_initial_viewpos: ?Vec2i = null;
var selecting = false;
var placing = false;

pub fn on_mouse_motion(state: *State, x: i32, y: i32, x_rel: i32, y_rel: i32) void {
    if (lmb_down) {
        const mouse = Vec2i.new(x, y);
        const initial_mouse = drag_initial_mouse orelse mouse: {
            drag_initial_mouse = mouse;
            break :mouse mouse;
        };
        if (selecting) {
            const mouse_to_world = display.screen2world(state, mouse);
            const selection_rect = state.selection_rect orelse sel: {
                state.selection_rect = Rect{
                    .pos = mouse_to_world,
                    .size = Vec2i.new(0, 0),
                };
                break :sel state.selection_rect.?;
            };
            const movement = mouse_to_world.sub(selection_rect.pos);
            state.selection_rect.?.size = movement;
        } else if ((sdl.GetModState() & sdl.KMOD_LSHIFT) == 0) {
            const initial_viewpos = drag_initial_viewpos orelse viewpos: {
                drag_initial_viewpos = state.viewpos;
                break :viewpos state.viewpos;
            };
            var movement = mouse.sub(initial_mouse);
            placing = movement.length_sq() < 2;
            _ = movement.mulfi(state.get_zoom_factor());
            state.viewpos = initial_viewpos.sub(movement);
        }
    } else {
        if (drag_initial_mouse != null or drag_initial_viewpos != null) {
            drag_initial_mouse = null;
            drag_initial_viewpos = null;
        }
    }
}

pub fn on_mouse_button_up(state: *State, button: u8, mouse_pos: Vec2i) !void {
    switch (button) {
        sdl.BUTTON_LEFT => {
            if (placing) {
                const grid_pos = display.screen2grid(state, mouse_pos);
                if (try state.place_entity(grid_pos)) {
                    std.debug.warn("Placed!\n");
                } else {
                    std.debug.warn("Blocked!\n");
                }
            }
            if (selecting) {
                const sel_rect = state.selection_rect orelse unreachable;
                const min_pos = sel_rect.pos.div(display.GRID_SIZE);
                const max_pos = sel_rect.pos.add(
                    sel_rect.size,
                ).divi(display.GRID_SIZE).addi(Vec2i.new(1, 1));
                var y: i32 = min_pos.y;
                while (y < max_pos.y) : (y += 1) {
                    var x: i32 = min_pos.x;
                    while (x < max_pos.x) : (x += 1) {
                        const pos = Vec2i.new(x, y);
                        if (!state.entities.contains(pos))
                            continue;
                        _ = try state.selected_entities.put(pos, {});
                    }
                }
                selecting = false;
                state.selection_rect = null;
            }
            lmb_down = false;
        },
        sdl.BUTTON_RIGHT => {
            rmb_down = false;
        },
        else => {},
    }
}

pub fn on_mouse_button_down(state: *State, button: u8, x: i32, y: i32) void {
    switch (button) {
        sdl.BUTTON_LEFT => {
            if ((sdl.GetModState() & sdl.KMOD_LCTRL) != 0) {
                const mouse_pos = Vec2i.new(x, y);
                state.selected_entities.clear();
                selecting = true;
                state.selection_rect = Rect{
                    .pos = display.screen2world(state, mouse_pos),
                    .size = Vec2i.new(0, 0),
                };
            } else if ((sdl.GetModState() & sdl.KMOD_LCTRL) == 0) {
                placing = true;
            }
            lmb_down = true;
        },
        sdl.BUTTON_RIGHT => {
            rmb_down = true;
        },
        else => {},
    }
}

pub fn tick_held_mouse_buttons(state: *State, mouse_pos: Vec2i) !void {
    const grid_pos = display.screen2grid(state, mouse_pos);

    if ((lmb_down or rmb_down) and (last_grid_action == null or !last_grid_action.?.equals(grid_pos))) {
        last_grid_action = grid_pos;
        if (lmb_down and !rmb_down and ((sdl.GetModState() & sdl.KMOD_LSHIFT) != 0)) {
            if (try state.place_entity(grid_pos)) {
                std.debug.warn("Placed!\n");
            } else {
                std.debug.warn("Blocked!\n");
            }
        }

        if (rmb_down and !lmb_down) {
            if (try state.remove_entity(grid_pos)) |_|
                std.debug.warn("Removed!\n");
        }
    }

    if (!lmb_down and !rmb_down)
        last_grid_action = null;
}

pub fn on_key_up(state: *State, keysym: sdl.Keysym) !void {
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
            state.entity_ghost_dir = state.entity_ghost_dir.cclockwise();
            state.get_entity_ptr().set_direction(state.entity_ghost_dir);
        },
        sdl.K_e => {
            state.entity_ghost_dir = state.entity_ghost_dir.clockwise();
            state.get_entity_ptr().set_direction(state.entity_ghost_dir);
        },
        sdl.K_f => {
            state.get_entity_ptr().flip();
        },
        sdl.K_DELETE => {
            var entity_iterator = state.selected_entities.iterator();
            while (entity_iterator.next()) |entry| {
                _ = try state.remove_entity(entry.key);
            }
            state.selected_entities.clear();
        },
        sdl.K_ESCAPE => {
            state.selected_entities.clear();
        },
        sdl.K_F6 => {
            try state.save("test.sav");
            std.debug.warn("saved to test.sav\n");
        },
        else => {},
    }
}
