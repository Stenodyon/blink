const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const ResourceManager = @import("res.zig");
const sdl = @import("sdl.zig");
const ttf = @import("ttf.zig");
const img = @import("img.zig");
const display = @import("display.zig");
const input = @import("input.zig");
const GUI_Element = display.GUI_Element;
const GUI_Button = display.GUI_Button;
const State = @import("state.zig").State;
const Segment = @import("state.zig").Segment;

var window: sdl.Window = undefined;

var quit = false;

// ============================================================================

fn init_sdl() void {
    if (sdl.Init(sdl.INIT_VIDEO) < 0) {
        std.debug.warn("Could not initialize SDL: {}\n", sdl.GetError());
        std.os.exit(1);
    }

    window = sdl.CreateWindow(c"Hello SDL2 from zig", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, display.SCREEN_WIDTH, display.SCREEN_HEIGHT, sdl.WINDOW_SHOWN);
    if (window == null) {
        std.debug.warn("Could not create a window: {}\n", sdl.GetError());
        std.os.exit(1);
    }

    display.renderer = sdl.CreateRenderer(window, -1, sdl.RENDERER_ACCELERATED);
    if (display.renderer == null) {
        std.debug.warn("Could not create a renderer: {}\n", sdl.GetError());
        std.os.exit(1);
    }

    std.debug.warn("SDL Initialized\n");

    const img_flags = img.INIT_PNG;
    if ((img.Init(img_flags) & img_flags) == 0) {
        std.debug.warn("Could not initialize SDL_image: {}\n", img.GetError());
        deinit_sdl();
        std.os.exit(1);
    }
}

// ============================================================================

fn deinit_sdl() void {
    sdl.DestroyRenderer(display.renderer);
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

    var resource_allocator = ArenaAllocator.init(std.debug.global_allocator);
    ResourceManager.init(&resource_allocator.allocator);
    defer ResourceManager.deinit();

    try display.init();
    defer display.deinit();

    //var gui_allocator = ArenaAllocator.init(std.debug.global_allocator);
    //display.g_gui = @ptrCast(
    //    *GUI_Element,
    //    try gui_allocator.allocator.createOne(GUI_Button));
    //@ptrCast(*GUI_Button, display.g_gui).* = display.GUI_Button.new();

    var state: State = State.new(std.debug.global_allocator);
    defer state.destroy();

    while (!quit) {
        const start_time = sdl.GetTicks();

        var event: sdl.Event = undefined;
        while (sdl.PollEvent(&event) > 0) {
            switch (event.type) {
                sdl.MOUSEMOTION => {
                    const mouse_event = @ptrCast(*sdl.MouseMotionEvent, &event);
                    input.on_mouse_motion(
                        &state,
                        mouse_event.x,
                        mouse_event.y,
                        mouse_event.xrel,
                        mouse_event.yrel,
                    );
                },
                sdl.MOUSEBUTTONUP => {
                    const mouse_event = @ptrCast(*sdl.MouseButtonEvent, &event);
                    try input.on_mouse_button_up(
                        &state,
                        mouse_event.button,
                        mouse_event.x,
                        mouse_event.y,
                    );
                },
                sdl.MOUSEBUTTONDOWN => {
                    const mouse_event = @ptrCast(*sdl.MouseButtonEvent, &event);
                    input.on_mouse_button_down(
                        mouse_event.button,
                        mouse_event.x,
                        mouse_event.y,
                    );
                },
                sdl.MOUSEWHEEL => {
                    const wheel_event = @ptrCast(*sdl.MouseWheelEvent, &event);
                    if (wheel_event.y < 0) {
                        state.on_wheel_down(@intCast(u32, -wheel_event.y));
                    } else {
                        state.on_wheel_up(@intCast(u32, wheel_event.y));
                    }
                },
                sdl.KEYUP => {
                    const keyboard_event = @ptrCast(*sdl.KeyboardEvent, &event);
                    try state.on_key_up(keyboard_event.keysym);
                },
                sdl.QUIT => {
                    std.debug.warn("Quit Event!\n");
                    quit = true;
                },
                else => {},
            }
        }

        display.render(&state);

        const end_time = sdl.GetTicks();
        const delta = end_time - start_time;
        if (delta <= 16)
            sdl.Delay(16 - delta);
    }
}
