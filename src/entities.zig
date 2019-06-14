const std = @import("std");

const Vec2i = @import("vec.zig").Vec2i;

pub const Direction = enum {
    UP,
    DOWN,
    LEFT,
    RIGHT,

    pub fn clockwise(self: Direction) Direction {
        switch (self) {
            .UP => return .RIGHT,
            .DOWN => return .LEFT,
            .LEFT => return .UP,
            .RIGHT => return .DOWN,
        }
    }

    pub fn cclockwise(self: Direction) Direction {
        switch (self) {
            .UP => return .LEFT,
            .DOWN => return .RIGHT,
            .LEFT => return .DOWN,
            .RIGHT => return .UP,
        }
    }

    pub fn delta(self: Direction) Vec2i {
        switch (self) {
            .UP => return Vec2i.new(0, -1),
            .DOWN => return Vec2i.new(0, 1),
            .LEFT => return Vec2i.new(-1, 0),
            .RIGHT => return Vec2i.new(1, 0),
        }
    }

    pub fn to_string(self: Direction) []const u8 {
        switch (self) {
            .UP => return "UP",
            .DOWN => return "DOWN",
            .LEFT => return "LEFT",
            .RIGHT => return "RIGHT",
            else => unreachable,
        }
    }
};

pub fn dir_angle(direction: Direction) f64 {
    switch (direction) {
        .UP => return 0,
        .DOWN => return 180,
        .LEFT => return 270,
        .RIGHT => return 90,
    }
}

const mirror_directions = [_]Direction{
    .UP,
    .DOWN,
    .LEFT,
    .RIGHT,
};

pub const Entity = union(enum) {
    Block,
    Laser: Direction,
    Mirror: Direction,

    // Returns the direction of propagated rays
    pub fn propagated_rays(
        self: *Entity,
        hitdir: Direction,
    ) []const Direction {
        switch (self.*) {
            .Block, .Laser => return [_]Direction{},
            .Mirror => |direction| {
                if (hitdir == direction) {
                    const index = @intCast(usize, @enumToInt(direction.clockwise()));
                    return mirror_directions[index .. index + 1]; //something;
                }
                if (hitdir == direction.cclockwise()) {
                    const index = @intCast(usize, @enumToInt(direction.clockwise().clockwise()));
                    return mirror_directions[index .. index + 1]; //something;
                }
                return [_]Direction{};
            },
        }
    }

    pub fn is_input(self: *Entity, direction: Direction) bool {
        switch (self.*) {
            .Block, .Laser, .Mirror => return false,
        }
    }

    pub fn clockwise(self: *Entity) void {
        switch (self.*) {
            .Block => {},
            .Laser => |*direction| direction.* = direction.clockwise(),
            .Mirror => |*direction| direction.* = direction.clockwise(),
        }
    }

    pub fn cclockwise(self: *Entity) void {
        switch (self.*) {
            .Block => {},
            .Laser => |*direction| direction.* = direction.cclockwise(),
            .Mirror => |*direction| direction.* = direction.cclockwise(),
        }
    }
};
