const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

//const ResourceManager = @import("res.zig");
const sdl = @import("sdl.zig");
const ttf = @import("ttf.zig");
const c = @import("c.zig");
const display = @import("display.zig");
const input = @import("input.zig");
const Vec2i = @import("vec.zig").Vec2i;
const GUI_Element = display.GUI_Element;
const GUI_Button = display.GUI_Button;
usingnamespace @import("state.zig");

const UPS: f64 = 100;

var window: sdl.Window = undefined;
var gl_context: sdl.GLContext = undefined;

var quit = false;

// ============================================================================

fn init_sdl() void {
    if (sdl.Init(sdl.INIT_VIDEO) < 0) {
        std.debug.warn("Could not initialize SDL: {}\n", sdl.GetError());
        std.os.exit(1);
    }

    _ = sdl.GL_SetAttribute(
        sdl.GL_CONTEXT_PROFILE_MASK,
        @enumToInt(sdl.GL_CONTEXT_PROFILE_CORE),
    );
    _ = sdl.GL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, 3);
    _ = sdl.GL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, 2);
    _ = sdl.GL_SetAttribute(sdl.GL_STENCIL_SIZE, 8);

    window = sdl.CreateWindow(
        c"Blink",
        sdl.WINDOWPOS_UNDEFINED,
        sdl.WINDOWPOS_UNDEFINED,
        display.window_width,
        display.window_height,
        sdl.WINDOW_OPENGL | sdl.WINDOW_RESIZABLE,
    );
    if (window == null) {
        std.debug.warn("Could not create a window: {}\n", sdl.GetError());
        std.os.exit(1);
    }

    gl_context = sdl.GL_CreateContext(window);

    std.debug.warn("SDL Initialized\n");
}

// ============================================================================

fn deinit_sdl() void {
    sdl.GL_DeleteContext(gl_context);
    sdl.DestroyWindow(window);
    sdl.Quit();

    std.debug.warn("SDL Deinitialized\n");
}

// ============================================================================

fn init_ttf() void {
    if (ttf.Init() < 0) {
        std.debug.warn("Could not initialize TTF: {}\n", ttf.GetError());
        std.os.exit(1);
    }
}

// ============================================================================

fn deinit_ttf() void {
    ttf.Quit();
}

// ============================================================================

pub fn main() !void {
    init_sdl();
    init_ttf();
    defer {
        deinit_sdl();
        deinit_ttf();
    }

    //var resource_allocator = ArenaAllocator.init(std.debug.global_allocator);
    //ResourceManager.init(&resource_allocator.allocator);
    //defer ResourceManager.deinit();

    display.init(std.heap.c_allocator);
    defer display.deinit();

    //var gui_allocator = ArenaAllocator.init(std.debug.global_allocator);
    //display.g_gui = @ptrCast(
    //    *GUI_Element,
    //    try gui_allocator.allocator.createOne(GUI_Button));
    //@ptrCast(*GUI_Button, display.g_gui).* = display.GUI_Button.new();

    const args = try std.process.argsAlloc(std.heap.c_allocator);
    defer std.process.argsFree(std.heap.c_allocator, args);

    game_state = switch (args.len) {
        1 => State.new(std.heap.c_allocator),
        2 => blk: {
            const filename = args[1];
            break :blk (try State.from_file(std.heap.c_allocator, filename)) orelse {
                std.debug.warn("Could not read the file\n");
                std.process.exit(255);
            };
        },
        else => {
            std.debug.warn("Usage: {} [save-file]\n", args[0]);
            std.process.exit(255);
        },
    };
    defer game_state.destroy();

    var updates_left: f64 = 0;

    while (!quit) {
        const start_time = sdl.GetTicks();

        var event: sdl.Event = undefined;
        while (sdl.PollEvent(&event) > 0) {
            switch (event.type) {
                sdl.MOUSEMOTION => {
                    const mouse_event = @ptrCast(*sdl.MouseMotionEvent, &event);
                    try input.on_mouse_motion(
                        &game_state,
                        mouse_event.x,
                        mouse_event.y,
                        mouse_event.xrel,
                        mouse_event.yrel,
                    );
                },
                sdl.MOUSEBUTTONUP => {
                    const mouse_event = @ptrCast(*sdl.MouseButtonEvent, &event);
                    const mouse_pos = Vec2i.new(mouse_event.x, mouse_event.y);
                    try input.on_mouse_button_up(&game_state, mouse_event.button, mouse_pos);
                },
                sdl.MOUSEBUTTONDOWN => {
                    const mouse_event = @ptrCast(*sdl.MouseButtonEvent, &event);
                    input.on_mouse_button_down(
                        &game_state,
                        mouse_event.button,
                        mouse_event.x,
                        mouse_event.y,
                    );
                },
                sdl.MOUSEWHEEL => {
                    const wheel_event = @ptrCast(*sdl.MouseWheelEvent, &event);
                    if (wheel_event.y < 0) {
                        game_state.on_wheel_down(@intCast(u32, -wheel_event.y));
                    } else {
                        game_state.on_wheel_up(@intCast(u32, wheel_event.y));
                    }
                },
                sdl.KEYUP => {
                    const keyboard_event = @ptrCast(*sdl.KeyboardEvent, &event);
                    try input.on_key_up(&game_state, keyboard_event.keysym);
                },
                sdl.WINDOWEVENT => {
                    display.on_window_event(&game_state, &event.window);
                },
                sdl.QUIT => {
                    std.debug.warn("Quit Event!\n");
                    quit = true;
                },
                else => {},
            }
        }

        {
            var mouse_pos: Vec2i = undefined;
            _ = sdl.GetMouseState(&mouse_pos.x, &mouse_pos.y);
            try input.tick_held_mouse_buttons(&game_state, mouse_pos);
        }

        try display.render(&game_state);
        sdl.GL_SwapWindow(window);

        updates_left += UPS / 60.;
        while (updates_left >= 1.) : (updates_left -= 1.) {
            try game_state.update();
        }

        const end_time = sdl.GetTicks();
        const delta = end_time - start_time;
        if (delta <= 16)
            sdl.Delay(16 - delta);
    }
}
