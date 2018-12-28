const std = @import("std");
const Allocator = std.mem.Allocator;

const Vec2i = @import("vec.zig").Vec2i;

const Prism = union(enum)
{
    Block,
};

const PrismMap = std.HashMap(Vec2i, Prism, Vec2i.hash, Vec2i.equals);

pub const State = struct
{
    prisms: PrismMap,

    pub fn new(allocator: *Allocator) State
    {
        return State {
            .prisms = PrismMap.init(allocator),
        };
    }

    pub fn destroy(self: *State) void
    {
        self.prisms.deinit();
    }
};
