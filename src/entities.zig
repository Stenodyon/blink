const std = @import("std");

const Vec2i = @import("vec.zig").Vec2i;
const M_PI = @import("utils.zig").M_PI;

pub const Direction = enum {
    UP,
    RIGHT,
    DOWN,
    LEFT,

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

    pub fn opposite(self: Direction) Direction {
        switch (self) {
            .UP => return .DOWN,
            .DOWN => return .UP,
            .LEFT => return .RIGHT,
            .RIGHT => return .LEFT,
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

    pub fn to_rad(self: Direction) f32 {
        switch (self) {
            .UP => return 0.,
            .DOWN => return M_PI,
            .RIGHT => return M_PI / 2.,
            .LEFT => return 3. * M_PI / 2.,
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
    .RIGHT,
    .DOWN,
    .LEFT,
};

const splitter_directions = [_]Direction{
    .UP,
    .RIGHT,
    .DOWN,
    .LEFT,
    .UP,
};

pub const Delayer = struct {
    direction: Direction,
    is_on: bool,
};

pub const Switch = struct {
    direction: Direction,
    is_on: bool,
    is_flipped: bool,
};

pub const Entity = union(enum) {
    Block,
    Laser: Direction,
    Mirror: Direction,
    DoubleMirror: Direction,
    Splitter: Direction,
    Delayer: Delayer,
    Switch: Switch,
    Lamp: bool,

    // Returns the direction of propagated rays
    pub fn propagated_rays(
        self: *Entity,
        hitdir: Direction,
    ) []const Direction {
        switch (self.*) {
            .Block,
            .Laser,
            .Delayer,
            .Switch,
            .Lamp,
            => return [_]Direction{},

            .Mirror => |direction| {
                if (hitdir == direction) {
                    const index = @intCast(usize, @enumToInt(direction.clockwise()));
                    return mirror_directions[index .. index + 1];
                }
                if (hitdir == direction.cclockwise()) {
                    const index = @intCast(usize, @enumToInt(direction.opposite()));
                    return mirror_directions[index .. index + 1];
                }
                return [_]Direction{};
            },

            .DoubleMirror => |direction| {
                if (hitdir == direction or hitdir == direction.opposite()) {
                    const index = @intCast(usize, @enumToInt(hitdir.clockwise()));
                    return mirror_directions[index .. index + 1];
                }
                if (hitdir == direction.cclockwise() or hitdir == direction.clockwise()) {
                    const index = @intCast(usize, @enumToInt(hitdir.cclockwise()));
                    return mirror_directions[index .. index + 1];
                }
                return [_]Direction{};
            },

            .Splitter => |direction| {
                if (hitdir == direction or
                    hitdir == direction.opposite())
                {
                    const index = @intCast(usize, @enumToInt(hitdir));
                    return splitter_directions[index .. index + 2];
                }
                if (hitdir == direction.cclockwise() or
                    hitdir == direction.clockwise())
                {
                    const index = @intCast(usize, @enumToInt(hitdir.cclockwise()));
                    return splitter_directions[index .. index + 2];
                }
                return [_]Direction{};
            },
        }
    }

    pub fn is_input(self: *Entity, direction: Direction) bool {
        switch (self.*) {
            .Block,
            .Laser,
            .Mirror,
            .DoubleMirror,
            .Splitter,
            => return false,
            .Delayer => |*delayer| return delayer.direction == direction,
            .Switch => |*eswitch| return eswitch.direction == direction,
            .Lamp => return true,
        }
    }

    pub fn is_side_input(self: *Entity, direction: Direction) bool {
        switch (self.*) {
            .Block,
            .Laser,
            .Mirror,
            .DoubleMirror,
            .Splitter,
            .Delayer,
            .Lamp,
            => return false,
            .Switch => |*eswitch| {
                if (eswitch.is_flipped) {
                    return eswitch.direction.clockwise() == direction;
                } else {
                    return eswitch.direction.cclockwise() == direction;
                }
            },
        }
    }

    pub fn clockwise(self: *Entity) void {
        switch (self.*) {
            .Block, .Lamp => {},
            .Laser,
            .Mirror,
            .DoubleMirror,
            .Splitter,
            => |*direction| direction.* = direction.clockwise(),
            .Switch => |*eswitch| eswitch.direction = eswitch.direction.clockwise(),
            .Delayer => |*delayer| {
                delayer.direction = delayer.direction.clockwise();
            },
        }
    }

    pub fn cclockwise(self: *Entity) void {
        switch (self.*) {
            .Block, .Lamp => {},
            .Laser,
            .Mirror,
            .DoubleMirror,
            .Splitter,
            => |*direction| direction.* = direction.cclockwise(),
            .Switch => |*eswitch| eswitch.direction = eswitch.direction.cclockwise(),
            .Delayer => |*delayer| {
                delayer.direction = delayer.direction.cclockwise();
            },
        }
    }

    pub fn set_direction(self: *Entity, new_direction: Direction) void {
        switch (self.*) {
            .Block,
            .Lamp,
            => {},
            .Laser => |*direction| direction.* = new_direction,
            .Mirror => |*direction| direction.* = new_direction,
            .DoubleMirror => |*direction| direction.* = new_direction,
            .Splitter => |*direction| direction.* = new_direction,
            .Delayer => |*delayer| {
                delayer.direction = new_direction;
            },
            .Switch => |*eswitch| {
                eswitch.direction = new_direction;
            },
        }
    }

    pub fn get_direction(self: *const Entity) Direction {
        switch (self.*) {
            .Block,
            .Lamp,
            => return .UP,
            .Laser,
            .Mirror,
            .DoubleMirror,
            .Splitter,
            => |direction| return direction,
            .Delayer => |*delayer| return delayer.direction,
            .Switch => |*eswitch| return eswitch.direction,
        }
    }

    pub fn is_emitting(self: *const Entity) bool {
        switch (self.*) {
            .Block,
            .Mirror,
            .DoubleMirror,
            .Splitter,
            .Lamp,
            => return false,
            .Laser => return true,
            .Delayer => |*delayer| return delayer.is_on,
            .Switch => |*eswitch| return eswitch.is_on,
        }
    }

    pub fn flip(self: *Entity) void {
        switch (self.*) {
            .Block,
            .Laser,
            .Mirror,
            .DoubleMirror,
            .Splitter,
            .Delayer,
            .Lamp,
            => {},
            .Switch => |*eswitch| eswitch.is_flipped = !eswitch.is_flipped,
        }
    }

    pub fn flip_vertically(self: *Entity) void {
        switch (self.*) {
            .Block, .Lamp => {},
            .Laser => |*direction| switch (direction.*) {
                .UP, .DOWN => {},
                .LEFT, .RIGHT => direction.* = direction.opposite(),
            },
            .Mirror,
            .DoubleMirror,
            .Splitter,
            => |*direction| switch (direction.*) {
                .UP, .DOWN => direction.* = direction.clockwise(),
                .LEFT, .RIGHT => direction.* = direction.cclockwise(),
            },
            .Delayer => |*delayer| switch (delayer.direction) {
                .UP, .DOWN => {},
                .LEFT, .RIGHT => delayer.direction = delayer.direction.opposite(),
            },
            .Switch => |*eswitch| {
                eswitch.is_flipped = !eswitch.is_flipped;
                switch (eswitch.direction) {
                    .UP, .DOWN => {},
                    .LEFT, .RIGHT => eswitch.direction = eswitch.direction.opposite(),
                }
            },
        }
    }

    pub fn set_flipped(self: *Entity, value: bool) void {
        switch (self.*) {
            .Block,
            .Laser,
            .Mirror,
            .DoubleMirror,
            .Splitter,
            .Delayer,
            .Lamp,
            => {},
            .Switch => |*eswitch| eswitch.is_flipped = value,
        }
    }

    pub fn get_flipped(self: *const Entity) bool {
        switch (self.*) {
            .Block,
            .Laser,
            .Mirror,
            .DoubleMirror,
            .Splitter,
            .Delayer,
            .Lamp,
            => return false,
            .Switch => |*eswitch| return eswitch.is_flipped,
        }
    }

    pub fn set_properties_from(self: *Entity, other: *const Entity) void {
        self.set_direction(other.get_direction());
        self.set_flipped(other.get_flipped());
    }
};
