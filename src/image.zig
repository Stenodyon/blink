const std = @import("std");
const Allocator = std.mem.Allocator;

const PNGError = error{WrongHeader};

pub fn load_image(allocator: *Allocator, path: []const u8) ![]u8 {
    const contents = try std.io.readFileAlloc(allocator, path);
    defer allocator.free(contents);
}
