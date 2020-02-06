const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl = @import("sdl.zig");
const img = @import("img.zig");

const ResourceMap = std.AutoHashMap([]const u8, sdl.Surface);
var Resources: ResourceMap = undefined;

pub fn init(allocator: *Allocator) void {
    Resources = ResourceMap.init(allocator);
}

pub fn deinit() void {
    var resources_it = Resources.iterator();
    while (resources_it.next()) |entry| {
        sdl.FreeSurface(entry.value);
    }
    Resources.deinit();
}

pub fn Get(path: []const u8) !sdl.Surface {
    const result = Resources.get(path);
    if (result) |entry|
        return entry.value;

    const surface = img.Load(path);
    if (surface == null) {
        std.debug.warn("Could not load \"{}\": {}\n", .{ path, img.GetError() });
        std.os.exit(1);
    }

    _ = try Resources.put(path, surface);
    return surface;
}
