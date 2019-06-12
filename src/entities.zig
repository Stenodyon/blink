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
};

pub fn dir_angle(direction: Direction) f64 {
    switch (direction) {
        .UP => return 270,
        .DOWN => return 90,
        .LEFT => return 180,
        .RIGHT => return 0,
    }
}

pub const Entity = union(enum) {
    Block,
    Laser: Direction,

    pub fn clockwise(self: *Entity) void {
        switch (self) {
            Laser => |direction| {
                self.* = Entity{ .Laser = direction.clockwise() };
            },
            else => {},
        }
    }

    pub fn cclockwise(self: *Entity) void {
        switch (self.*) {
            .Laser => |direction| {
                self.* = Entity{ .Laser = direction.cclockwise() };
            },
            else => {},
        }
    }
};
