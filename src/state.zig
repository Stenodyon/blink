const std = @import("std");
const Allocator = std.mem.Allocator;

const Vec2i = @import("vec.zig").Vec2i;

const Entity = union(enum)
{
    Block,
};

const EntityMap = std.HashMap(Vec2i, Entity, Vec2i.hash, Vec2i.equals);

pub const State = struct
{
    viewpos: Vec2i,
    entities: EntityMap,

    pub fn new(allocator: *Allocator) State
    {
        return State {
            .viewpos = Vec2i.new(0, 0),
            .entities = EntityMap.init(allocator),
        };
    }

    pub fn destroy(self: *State) void
    {
        self.entities.deinit();
    }
};
