const std   = @import("std");
const sdl   = @import("sdl.zig");

const State = @import("state.zig").State;
const vec   = @import("vec.zig");
const Vec2i = vec.Vec2i;
const Rect  = vec.Rect;

pub const SCREEN_WIDTH  = 640;
pub const SCREEN_HEIGHT = 480;

var viewpos_x = 0;
var viewpos_y = 0;

pub fn render(renderer: sdl.Renderer, state: *const State) void
{
    _ = sdl.SetRenderDrawColor(renderer, 0x7F, 0x7F, 0x7F, 0xFF);
    _ = sdl.RenderClear(renderer);

    sdl.RenderPresent(renderer);
}
