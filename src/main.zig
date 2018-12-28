const std = @import("std");
const sdl = @import("sdl.zig");
const display = @import("display.zig");
const State = @import("state.zig").State;

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
