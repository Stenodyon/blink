const c = @cImport({
    @cInclude("SDL2/SDL_image.h");
});

const std = @import("std");

const sdl = @import("sdl.zig");

pub const INIT_PNG = c.IMG_INIT_PNG;

pub const Init = c.IMG_Init;

fn strlen(str: [*]const u8) usize
{
    var counter: usize = 0;
    while (str[counter] > 0)
    {
        counter += 1;
    }
    return counter;
}

pub fn GetError() []const u8
{
    const msg = c.IMG_GetError();
    const length = strlen(msg);
    return msg[0..length];
}

pub fn Load(path: []const u8) sdl.Surface
{
    // Need to null-terminate strings
    var buffer: [512]u8 = undefined;
    std.mem.copy(u8, buffer[0..], path);
    buffer[path.len] = 0;

    const surface = c.IMG_Load(@ptrCast(?[*]const u8, &buffer[0]));
    return @ptrCast(sdl.Surface, surface);
}
