const std = @import("std");
const Allocator = std.mem.Allocator;

const vec   = @import("vec.zig");
const Vec2i = vec.Vec2i;
const Rect  = vec.Rect;
const utils = @import("utils.zig");

pub const Entity = union(enum)
{
    Block,
};

const EntityMap = std.HashMap(Vec2i, Entity, Vec2i.hash, Vec2i.equals);

pub const SegmentDirection = enum
{
    VERTICAL, // fixed_coord is x
    HORIZONTAL, // fixed_coord is y
};

pub const Segment = struct
{
    direction: SegmentDirection,
    fixed_coord: i32,
    a: i32, b: i32, // invariant: a < b

    fn new(direction: SegmentDirection,
            fixed_coord: i32,
            a: i32, b: i32) Segment
    {
        var _a = a;
        var _b = b;
        utils.min_order(&_a, &_b);
        return Segment
        {
            .direction = direction,
            .fixed_coord = fixed_coord,
            .a = _a,
            .b = _b,
        };
    }

    pub fn newV(x: i32, y1: i32, y2: i32) Segment
    {
        return Segment.new(SegmentDirection.VERTICAL, x, y1, y2);
    }

    pub fn newH(y: i32, x1: i32, x2: i32) Segment
    {
        return Segment.new(SegmentDirection.HORIZONTAL, y, x1, x2);
    }

    pub fn intersects(self: *const Segment, area: Rect) bool
    {
        switch (self.direction)
        {
            SegmentDirection.VERTICAL =>
            {
                if (self.fixed_coord < area.pos.x
                    or self.fixed_coord >= (area.pos.x + area.size.x))
                    return false;
                if (self.a >= (area.pos.y + area.size.y)
                    or self.b < area.pos.y)
                    return false;

                return true;
            },
            SegmentDirection.HORIZONTAL =>
            {
                if (self.fixed_coord < area.pos.y
                    or self.fixed_coord >= (area.pos.y + area.size.y))
                    return false;
                if (self.a >= (area.pos.x + area.size.x)
                    or self.b < area.pos.x)
                    return false;

                return true;
            },
        }
    }
};

const SegmentList = std.ArrayList(Segment);

pub const State = struct
{
    viewpos: Vec2i,
    entities: EntityMap,
    lightrays: SegmentList,

    pub fn new(allocator: *Allocator) State
    {
        return State {
            .viewpos = Vec2i.new(0, 0),
            .entities = EntityMap.init(allocator),
            .lightrays = SegmentList.init(allocator),
        };
    }

    pub fn destroy(self: *State) void
    {
        self.entities.deinit();
        self.lightrays.deinit();
    }
};
