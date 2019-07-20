const std = @import("std");
const abs = std.math.absInt;

const sdl = @import("sdl.zig");
const Direction = @import("entities.zig").Direction;

fn Vec2(comptime ValType: type) type {
    return struct {
        x: ValType,
        y: ValType,

        const Self = @This();

        pub fn new(_x: ValType, _y: ValType) Self {
            return Self{
                .x = _x,
                .y = _y,
            };
        }

        pub fn add(a: Self, b: Self) Self {
            return Self.new(a.x + b.x, a.y + b.y);
        }

        pub fn addi(a: *Self, b: Self) Self {
            a.x += b.x;
            a.y += b.y;
            return a.*;
        }

        pub fn sub(a: Self, b: Self) Self {
            return Self.new(
                a.x - b.x,
                a.y - b.y,
            );
        }

        pub fn subi(a: *Self, b: Self) Self {
            a.x -= b.x;
            a.y -= b.y;
            return a.*;
        }

        pub fn neg(a: Self) Self {
            return Self.new(
                -a.x,
                -a.y,
            );
        }

        pub fn mul(self: Self, scalar: i32) Self {
            return Self.new(
                self.x * scalar,
                self.y * scalar,
            );
        }

        pub fn muli(self: *Self, scalar: i32) Self {
            self.x *= scalar;
            self.y *= scalar;
            return self.*;
        }

        pub fn mulf(self: Self, scalar: f32) Self {
            return Self.new(
                @floatToInt(i32, @intToFloat(f32, self.x) * scalar),
                @floatToInt(i32, @intToFloat(f32, self.y) * scalar),
            );
        }

        pub fn mulfi(self: *Self, scalar: f32) Self {
            self.x = @floatToInt(i32, @intToFloat(f32, self.x) * scalar);
            self.y = @floatToInt(i32, @intToFloat(f32, self.y) * scalar);
            return self.*;
        }

        pub fn div(self: Self, scalar: i32) Self {
            return Self.new(
                @divFloor(self.x, scalar),
                @divFloor(self.y, scalar),
            );
        }

        pub fn divi(self: *Self, scalar: i32) Self {
            self.x = @divFloor(self.x, scalar);
            self.y = @divFloor(self.y, scalar);
            return self.*;
        }

        pub fn divf(self: Self, scalar: f32) Self {
            return Self.new(
                @floatToInt(i32, @intToFloat(f32, self.x) / scalar),
                @floatToInt(i32, @intToFloat(f32, self.y) / scalar),
            );
        }

        pub fn divfi(self: *Self, scalar: f32) Self {
            self.x = @floatToInt(i32, @intToFloat(f32, self.x) / scalar);
            self.y = @floatToInt(i32, @intToFloat(f32, self.y) / scalar);
            return self.*;
        }

        pub fn mod(self: Self, scalar: i32) Self {
            return Self.new(
                @mod(self.x, scalar),
                @mod(self.y, scalar),
            );
        }

        pub fn modi(self: *Self, scalar: i32) Self {
            self.x = @mod(self.x, scalar);
            self.y = @mod(self.y, scalar);
            return self.*;
        }

        pub fn negi(a: Self) Self {
            a.x = -a.x;
            a.y = -a.y;
            return a;
        }

        pub fn equals(a: Self, b: Self) bool {
            return a.x == b.x and
                a.y == b.y;
        }

        pub fn hash(vec: Self) u32 {
            var seed: u32 = 2;
            seed ^= @bitCast(u32, vec.x) +%
                0x9e3779b9 +% (seed << 6) +% (seed >> 2);
            seed ^= @bitCast(u32, vec.y) +%
                0x9e3779b9 +% (seed << 6) +% (seed >> 2);
            return seed;
        }

        pub fn to_sdl(self: Self) sdl.Point {
            return sdl.Point{ .x = self.x, .y = self.y };
        }

        pub fn to_float(self: Self, comptime FT: type) Vec2(FT) {
            return Vec2(FT).new(
                @intToFloat(FT, self.x),
                @intToFloat(FT, self.y),
            );
        }

        pub fn distanceInt(self: Self, other: Vec2i) u32 {
            const distance = abs: {
                if (self.x == other.x) {
                    break :abs abs(self.y - other.y) catch unreachable;
                } else if (self.y == other.y) {
                    break :abs abs(self.x - other.x) catch unreachable;
                }
                unreachable;
            };
            return @intCast(u32, distance);
        }

        pub fn move(self: Self, distance: u32, direction: Direction) Self {
            const signed_dist = @intCast(i32, distance);
            return self.add(direction.delta().muli(signed_dist));
        }
    };
}

pub const Vec2i = Vec2(i32);
pub const Vec2f = Vec2(f32);

pub const Rect = struct {
    pos: Vec2i,
    size: Vec2i,

    pub fn new(_pos: Vec2i, _size: Vec2i) Rect {
        return Rect{
            .pos = _pos,
            .size = _size,
        };
    }

    pub fn translate(self: *Rect, vec: Vec2i) Rect {
        self.pos.addi(vec);
        return self;
    }

    pub fn translated(self: *const Rect, vec: Vec2i) Rect {
        return Rect{
            .pos = self.pos.add(vec),
            .size = self.size,
        };
    }

    pub fn contains(self: *const Rect, point: Vec2i) bool {
        return point.x >= self.pos.x and
            point.x < (self.pos.x + self.size.x) and
            point.y >= self.pos.y and
            point.y < (self.pos.y + self.size.y);
    }

    pub fn expand_to_contain(self: *Rect, point: Vec2i) void {
        if (point.x < self.pos.x) {
            self.size.x += self.pos.x - point.x;
            self.pos.x = point.x;
        } else if (point.x >= (self.pos.x + self.size.x)) {
            self.size.x = point.x - self.pos.x + 1;
        }

        if (point.y < self.pos.y) {
            self.size.y += self.pos.y - point.y;
            self.pos.y = point.y;
        } else if (point.y >= (self.pos.y + self.size.y)) {
            self.size.y = point.y - self.pos.y + 1;
        }
    }

    pub fn to_sdl(self: Rect) sdl.Rect {
        return sdl.Rect{
            .x = self.pos.x,
            .y = self.pos.y,
            .w = self.size.x,
            .h = self.size.y,
        };
    }
};
