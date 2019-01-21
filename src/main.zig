const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const sdl = @import("sdl.zig");
const display = @import("display.zig");
const GUI_Element = display.GUI_Element;
const GUI_Button = display.GUI_Button;
const State = @import("state.zig").State;
const Segment = @import("state.zig").Segment;

var window: sdl.Window = undefined;
var renderer: sdl.Renderer = undefined;

var quit = false;

// ============================================================================

fn init_sdl() void
{
    if (sdl.Init(sdl.INIT_VIDEO) < 0)
    {
        std.debug.warn("Could not initialize SDL: {}\n", sdl.GetError());
        std.os.exit(1);
    }

    window = sdl.CreateWindow(
        c"Hello SDL2 from zig",
        sdl.WINDOWPOS_UNDEFINED,
        sdl.WINDOWPOS_UNDEFINED,
        display.SCREEN_WIDTH,
        display.SCREEN_HEIGHT,
        sdl.WINDOW_SHOWN);
    if (window == null)
    {
        std.debug.warn("Could not create a window: {}\n", sdl.GetError());
        std.os.exit(1);
    }

    renderer = sdl.CreateRenderer(window, -1, sdl.RENDERER_ACCELERATED);
    if (renderer == null)
    {
        std.debug.warn("Could not create a renderer: {}\n", sdl.GetError());
        std.os.exit(1);
    }

    std.debug.warn("SDL Initialized\n");
}

// ============================================================================

fn deinit_sdl() void
{
    sdl.DestroyRenderer(renderer);
    sdl.DestroyWindow(window);
    sdl.Quit();

    std.debug.warn("SDL Deinitialized\n");
}

// ============================================================================

pub fn main() anyerror!void
{
    init_sdl();
    defer deinit_sdl();

    var gui_allocator = ArenaAllocator.init(std.debug.global_allocator);
    display.g_gui = @ptrCast(
        *GUI_Element,
        try gui_allocator.allocator.createOne(GUI_Button));
    @ptrCast(*GUI_Button, display.g_gui).* = display.GUI_Button.new();

    var state: State = State.new(std.debug.global_allocator);
    defer state.destroy();

    while (!quit)
    {
        const start_time = sdl.GetTicks();

        var event : sdl.Event = undefined;
        while (sdl.PollEvent(&event) > 0)
        {
            switch (event.type)
            {
                sdl.MOUSEMOTION =>
                {
                    const mouse_event = @ptrCast(*sdl.MouseMotionEvent, &event);
                    display.on_mouse_motion(
                            &state,
                            mouse_event.x,
                            mouse_event.y,
                            mouse_event.xrel,
                            mouse_event.yrel);
                },
                sdl.MOUSEBUTTONUP =>
                {
                    const mouse_event = @ptrCast(*sdl.MouseButtonEvent, &event);
                    display.on_mouse_button_up(
                        &state,
                        mouse_event.button,
                        mouse_event.x,
                        mouse_event.y);
                },
                sdl.MOUSEBUTTONDOWN =>
                {
                    const mouse_event = @ptrCast(*sdl.MouseButtonEvent, &event);
                    display.on_mouse_button_down(
                        mouse_event.button,
                        mouse_event.x,
                        mouse_event.y);
                },
                sdl.QUIT =>
                {
                    std.debug.warn("Quit Event!\n");
                    quit = true;
                },
                else => {},
            }
        }

        display.render(renderer, &state);

        const end_time = sdl.GetTicks();
        const delta = end_time - start_time;
        if (delta <= 16)
            sdl.Delay(16 - delta);
    }
}
