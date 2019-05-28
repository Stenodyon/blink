const std = @import("std");
const Allocator = std.mem.Allocator;

const sdl   = @import("sdl.zig");
const img   = @import("img.zig");
const vec   = @import("vec.zig");
const Vec2i = vec.Vec2i;
const Rect  = vec.Rect;
const utils = @import("utils.zig");

const entities  = @import("entities.zig");
const Entity    = entities.Entity;
const Direction = entities.Direction;

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

const EntityMap = std.HashMap(Vec2i, Entity, Vec2i.hash, Vec2i.equals);
const SegmentList = std.ArrayList(Segment);

pub const State = struct
{
    viewpos: Vec2i,

    entities: EntityMap,
    current_entity: u32,
    entity_wheel: [2]Entity,

    lightrays: SegmentList,

    pub fn new(allocator: *Allocator) State
    {
        var new_state = State {
            .viewpos = Vec2i.new(0, 0),

            .entities = EntityMap.init(allocator),
            .current_entity = 0,
            .entity_wheel = []Entity {
                Entity.Block,
                Entity{.Laser = Direction.UP},
            },

            .lightrays = SegmentList.init(allocator),
        };
        return new_state;
    }

    pub fn destroy(self: *State) void
    {
        self.entities.deinit();
        self.lightrays.deinit();
    }

    pub fn raycast(self: *State, pos: Vec2i, direction: Direction) ?Vec2i {
        var closest: ?Vec2i = null;
        var entity_iterator = self.entities.iterator();
        while (entity_iterator.next()) |entry| {
            var position = entry.key;
            const entity_position = position;
            switch (direction) {
                .UP   => {},
                .DOWN => {
                    position.y = -position.y;
                },
                .LEFT => {
                    const temp = position.x;
                    position.x = position.y;
                    position.y = -temp;
                },
                .RIGHT => {
                    const temp = position.x;
                    position.x = -position.y;
                    position.y = -temp;
                },
            }
            if (position.x != pos.x)
                continue;
            if (position.y < pos.y)
                continue;
            if (closest) |best_candidate| {
                if (best_candidate.y > position.y)
                    closest = entity_position;
            } else {
                closest = entity_position;
            }
        }
        return closest;
    }

    pub fn create_lightrays(self: *State) !void {
        try self.lightrays.resize(0);
        var entity_iterator = self.entities.iterator();
        while (entity_iterator.next()) |entry| {
            const position = entry.key;
            const entity = entry.value;
            switch (entity) {
                .Laser => |direction| {
                    const segment_direction = direction.to_segment();
                    const segment_endpoint = self.raycast(position, direction);
                    switch (direction) {
                        .UP, .DOWN => {
                            const b = b_value: {
                                if (segment_endpoint) |endpoint| {
                                    break :b_value endpoint.y;
                                } else {
                                    break :b_value @bitCast(i32, u32(0x8FFFFFFF));
                                }
                            };
                            const new_segment = Segment.new(
                                segment_direction,
                                position.x,
                                position.y,
                                b);
                            try self.lightrays.append(new_segment);
                        },
                        .LEFT, .RIGHT => {
                            const b = b_value: {
                                if (segment_endpoint) |endpoint| {
                                    break :b_value endpoint.x;
                                } else {
                                    break :b_value @bitCast(i32, u32(0x8FFFFFFF));
                                }
                            };
                            const new_segment = Segment.new(
                                segment_direction,
                                position.y,
                                position.x,
                                b);
                            try self.lightrays.append(new_segment);
                        },
                    }
                },
                else => {},
            }
        }
    }

    pub fn get_current_entity(self: *const State) Entity
    {
        return self.entity_wheel[self.current_entity];
    }

    fn get_entity_ptr(self: *State) *Entity
    {
        return &self.entity_wheel[self.current_entity];
    }

    pub fn place_entity(self: *State, pos: Vec2i) !bool
    {
        return self.add_entity(self.get_current_entity(), pos);
    }

    pub fn add_entity(self: *State, entity: Entity, pos: Vec2i) !bool
    {
        if (self.entities.contains(pos))
            return false;

        _ = try self.entities.put(pos, entity);
        try self.create_lightrays();
        return true;
    }

    pub fn remove_entity(self: *State, pos: Vec2i) !?EntityMap.KV {
        const entity = self.entities.remove(pos);
        if (entity) |_|
            try self.create_lightrays();
        return entity;
    }

    pub fn on_wheel_down(self: *State, amount: u32) void
    {
        self.current_entity = @mod(
                self.current_entity + amount,
                @intCast(u32, self.entity_wheel.len));
    }

    pub fn on_wheel_up(self: *State, amount: u32) void
    {
        self.current_entity = @mod(
                self.current_entity -% amount,
                @intCast(u32, self.entity_wheel.len));
    }

    fn rotate_current_entity(self: *State, amount: i32) void
    {
        var entity = self.get_entity_ptr();
        var direction: *Direction = undefined;
        switch (entity.*)
        {
            Entity.Laser => {
                direction = &entity.Laser;
            },
            else => return,
        }
        const intval = entities.clockwise_index(direction.*);
        const newintval = @intCast(usize, @rem(intval + amount, 4));
        direction.* = entities.clockwise_directions[newintval];
    }

    pub fn on_key_up(self: *State, keysym: sdl.Keysym) void
    {
        switch (keysym.sym)
        {
            sdl.K_q => {
                self.rotate_current_entity(1);
            },
            else => {},
        }
    }
};
